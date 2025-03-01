import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'profile_filter_page.dart';
import '../services/floating_window_service.dart';
import '../models/stock_data.dart';
import '../services/pip_service.dart';
import '../widgets/pip_ticker_view.dart';

/// Represents data for one day's bar for a ticker,
/// combining "today" and "yesterday" to compute changes.

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  // We'll do 2 calls: one for "today" and one for "yesterday"
  // (Use actual dynamic date logic in production, if desired)
  final String _dateToFetch = '2025-01-24';      // "today"
  final String _prevDateToFetch = '2025-01-23'; // "yesterday"

  // TODO: For production, do NOT hardcode the Polygon API key directly here.
  //       Use secure storage or env variables instead.
  final String _polygonApiKey = 'VuAp8k6bioJUIuflawofK1jbfA0U1V9s';

  // If you have thousands of tickers, storing them all can be big
  // We'll store the final combined data in _symbolCache
  final Map<String, StockData> _symbolCache = {};
  List<StockData> _allStocks = [];

  // The user's chosen "ticker" stocks (displayed in the horizontal scroller).
  // We'll keep these persisted in Firestore under each user's UID.
  List<StockData> _tickerStocks = [];

  // Ticker-only filter preferences
  bool _tickerShowSymbol         = true;
  bool _tickerShowName           = true;
  bool _tickerShowPrice          = true;
  bool _tickerShowPercentChange  = true;
  bool _tickerShowAbsoluteChange = false;
  bool _tickerShowVolume         = false;
  bool _tickerShowOpeningPrice   = false;
  bool _tickerShowDailyHighLow   = false;
  String _separator              = ' .... ';

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // Add these at the top with other variables
  bool _isFloatingWindowActive = false;
  final FloatingWindowService _floatingWindowService = FloatingWindowService();

  // Add a backup cache for comparison data
  Map<String, StockData> _originalDataCache = {};

  bool _needsDataRefresh = false;
  bool _isNotificationShadeOpen = false;
  DateTime? _lastFocusLossTime;
  bool _wasResumed = true;  // Set to true initially

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Add a small delay to ensure channel is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      PiPService.setIsMainPage(true);
      debugPrint('Main Page: Setting isMainPage to true');
    });
    
    const channel = MethodChannel('com.stocktok/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPChanged') {
        final isInPiP = call.arguments as bool;
        if (mounted) {
          setState(() {
            _isFloatingWindowActive = isInPiP;
            if (!isInPiP) {
              _rebuildAllStocksFromCache();
            }
          });
        }
      }
    });

    // 1) Fetch the stock data from Polygon.
    // 2) Then load the user's saved ticker selection from Firestore.
    // 3) Once loaded, combine them so the user sees up-to-date data plus
    //    whichever stocks they previously selected.
    _fetchTwoDaysData().then((_) async {
      await _loadUserTickerSymbols();
      await _loadUserFilterPreferences();
      // Store original data when first fetched
      _originalDataCache = Map.from(_symbolCache);
    });
  }

  @override
  void dispose() {
    PiPService.setIsMainPage(false);
    debugPrint('Main Page: Setting isMainPage to false');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsDataRefresh && mounted) {
      setState(() {
        _rebuildAllStocksFromCache();
      });
      _needsDataRefresh = false;
    }
  }

  @override
  Future<bool> onWillPop() async {
    if (_tickerStocks.isNotEmpty) {
      await PiPService.enterPiPMode();
      setState(() {
        _isFloatingWindowActive = true;
      });
      return false;
    }
    return true;
  }

  //============================================================================
  //                           FETCHING LOGIC
  //============================================================================

  Future<void> _loadUserFilterPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!docSnap.exists) return;

      final data = docSnap.data();
      if (data == null) return;

      // Check if the doc contains filterPreferences
      final prefs = data['filterPreferences'];
      if (prefs is Map<String, dynamic>) {
        setState(() {
          _tickerShowSymbol         = prefs['showSymbol']        ?? _tickerShowSymbol;
          _tickerShowName           = prefs['showName']          ?? _tickerShowName;
          _tickerShowPrice          = prefs['showPrice']         ?? _tickerShowPrice;
          _tickerShowPercentChange  = prefs['showPercentChange'] ?? _tickerShowPercentChange;
          _tickerShowAbsoluteChange = prefs['showAbsoluteChange']?? _tickerShowAbsoluteChange;
          _tickerShowVolume         = prefs['showVolume']        ?? _tickerShowVolume;
          _tickerShowOpeningPrice   = prefs['showOpeningPrice']  ?? _tickerShowOpeningPrice;
          _tickerShowDailyHighLow   = prefs['showDailyHighLow']  ?? _tickerShowDailyHighLow;
          _separator                = prefs['separator']         ?? _separator;
        });
      }
    } catch (e) {
      debugPrint('Error loading filter preferences: $e');
    }
  }

  /// Fetch data for "today" and "yesterday" from Polygon, then combine
  Future<void> _fetchTwoDaysData() async {
    setState(() => _isLoading = true);

    final Map<String, StockData> todayMap = await _fetchGroupedForDate(_dateToFetch);
    final Map<String, StockData> prevMap  = await _fetchGroupedForDate(_prevDateToFetch);

    // Combine
    for (final symbol in todayMap.keys) {
      final todayData     = todayMap[symbol]!;
      final yesterdayData = prevMap[symbol];

      final yesterdayClose = yesterdayData?.currentPrice ?? 0;
      final absChange      = todayData.currentPrice - yesterdayClose;

      double pctChange = 0.0;
      if (yesterdayClose != 0) {
        pctChange = (absChange / yesterdayClose) * 100;
      }

      final combinedStock = StockData(
        symbol:         todayData.symbol,
        name:           todayData.name,
        currentPrice:   todayData.currentPrice,
        openPrice:      todayData.openPrice,
        highPrice:      todayData.highPrice,
        lowPrice:       todayData.lowPrice,
        volume:         todayData.volume,
        absoluteChange: absChange,
        percentChange:  pctChange,
      );

      _symbolCache[symbol] = combinedStock;
    }

    _rebuildAllStocksFromCache();
    setState(() => _isLoading = false);
  }

  /// Fetch all symbols from Polygon's "grouped daily" endpoint for [dateStr].
  /// Return a Map of symbol -> StockData for that day only
  /// (with 0 for absChange/pctChange).
  Future<Map<String, StockData>> _fetchGroupedForDate(String dateStr) async {
    final Map<String, StockData> map = {};

    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/us/market/stocks/$dateStr'
          '?adjusted=true&apiKey=$_polygonApiKey',
    );

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(resp.body);
        if (jsonMap['status'] == 'OK' && jsonMap['results'] is List) {
          final List results = jsonMap['results'];
          for (final item in results) {
            final symbol = (item['T'] ?? '').toString();
            if (symbol.isEmpty) continue;

            final open  = (item['o'] ?? 0).toDouble();
            final close = (item['c'] ?? 0).toDouble();
            final high  = (item['h'] ?? 0).toDouble();
            final low   = (item['l'] ?? 0).toDouble();
            final vol   = (item['v'] ?? 0).toDouble();

            final stock = StockData(
              symbol: symbol,
              // For now, just store the symbol in 'name' as well;
              // in a real production scenario, you might have a separate
              // lookup table or external API for the real company name.
              name:   symbol,
              currentPrice:   close,
              openPrice:      open,
              highPrice:      high,
              lowPrice:       low,
              volume:         vol.toInt(),
              absoluteChange: 0,
              percentChange:  0,
            );
            map[symbol] = stock;
          }
        } else {
          debugPrint('Polygon response not OK or no results for $dateStr');
        }
      } else {
        debugPrint('HTTP Error for $dateStr: ${resp.statusCode} -> ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error fetching grouped daily for $dateStr: $e');
    }

    return map;
  }

  /// Rebuilds the master list from _symbolCache
  void _rebuildAllStocksFromCache() {
    setState(() {
      // Use original cache for comparisons
      _allStocks = _symbolCache.values.map((stock) {
        final originalStock = _originalDataCache[stock.symbol];
        if (originalStock != null) {
          return StockData(
            symbol: stock.symbol,
            name: stock.name,
            currentPrice: stock.currentPrice,
            openPrice: stock.openPrice,
            highPrice: stock.highPrice,
            lowPrice: stock.lowPrice,
            volume: stock.volume,
            absoluteChange: originalStock.absoluteChange,
            percentChange: originalStock.percentChange,
          );
        }
        return stock;
      }).toList()..sort((a, b) => a.symbol.compareTo(b.symbol));

      _tickerStocks = _tickerStocks
          .map((t) => _allStocks.firstWhere((s) => s.symbol == t.symbol, orElse: () => t))
          .toList();
    });
  }

  //============================================================================
  //                          FIRESTORE PERSISTENCE
  //============================================================================

  /// Load the user's previously selected ticker symbols from Firestore,
  /// and rebuild our in-memory [_tickerStocks].
  Future<void> _loadUserTickerSymbols() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in; do nothing.
      return;
    }

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!docSnap.exists) return;

      final data = docSnap.data();
      if (data == null) return;

      final List<dynamic>? symbolList = data['selectedTickerSymbols'] as List<dynamic>?;
      if (symbolList == null) return;

      final List<StockData> newTicker = [];
      for (final symbol in symbolList) {
        if (_symbolCache.containsKey(symbol)) {
          newTicker.add(_symbolCache[symbol]!);
        }
      }

      setState(() {
        _tickerStocks = newTicker;
      });
    } catch (e) {
      debugPrint('Error loading user ticker symbols: $e');
    }
  }

  /// Save the user's currently selected ticker symbols to Firestore.
  /// This will store them under "users/{user.uid}" with a field: selectedTickerSymbols.
  Future<void> _saveUserTickerSymbols() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in; do nothing.
      return;
    }

    final symbolsToSave = _tickerStocks.map((s) => s.symbol).toList();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'selectedTickerSymbols': symbolsToSave,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user ticker symbols: $e');
    }
  }

  //============================================================================
  //                          UI / FILTERING
  //============================================================================

  /// Filter the main list by search text
  List<StockData> _filterStocks(String query) {
    if (query.isEmpty) return _allStocks;
    final lower = query.toLowerCase();
    return _allStocks.where((stock) {
      return stock.symbol.toLowerCase().contains(lower)
          || stock.name.toLowerCase().contains(lower);
    }).toList();
  }

  /// Toggle star icon -> add/remove from ticker
  void _toggleStockInTicker(StockData stock) {
    setState(() {
      if (_tickerStocks.contains(stock)) {
        _tickerStocks.remove(stock);
      } else {
        _tickerStocks.add(stock);
      }
    });
    // Persist the new selection in Firestore.
    _saveUserTickerSymbols();
  }

  /// Navigate to profile & filter page
  Future<void> _gotoProfileFilters() async {
    PiPService.setIsMainPage(false);  // Set false before navigation
    debugPrint('Main Page: Setting isMainPage to false before navigation');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileFilterPage(
          showSymbol:         _tickerShowSymbol,
          showName:           _tickerShowName,
          showPrice:          _tickerShowPrice,
          showPercentChange:  _tickerShowPercentChange,
          showAbsoluteChange: _tickerShowAbsoluteChange,
          showVolume:         _tickerShowVolume,
          showOpeningPrice:   _tickerShowOpeningPrice,
          showDailyHighLow:   _tickerShowDailyHighLow,
          separator:          _separator,
        ),
      ),
    );

    PiPService.setIsMainPage(true);  // Set true after returning
    debugPrint('Main Page: Setting isMainPage to true after navigation');
    
    if (result is Map<String, dynamic>) {
      setState(() {
        _tickerShowSymbol         = result['showSymbol']        ?? _tickerShowSymbol;
        _tickerShowName           = result['showName']          ?? _tickerShowName;
        _tickerShowPrice          = result['showPrice']         ?? _tickerShowPrice;
        _tickerShowPercentChange  = result['showPercentChange'] ?? _tickerShowPercentChange;
        _tickerShowAbsoluteChange = result['showAbsoluteChange']?? _tickerShowAbsoluteChange;
        _tickerShowVolume         = result['showVolume']        ?? _tickerShowVolume;
        _tickerShowOpeningPrice   = result['showOpeningPrice']  ?? _tickerShowOpeningPrice;
        _tickerShowDailyHighLow   = result['showDailyHighLow']  ?? _tickerShowDailyHighLow;
        _separator                = result['separator']         ?? _separator;
      });
    }
  }

  //============================================================================
  //                          BUILD METHOD
  //============================================================================

  @override
  Widget build(BuildContext context) {
    // Get stocks directly from _tickerStocks since these are already the selected ones
    final List<StockData> pipStocks = _tickerStocks;

    final filtered = _filterStocks(_searchController.text);

    return PopScope(
      canPop: _tickerStocks.isEmpty,
      onPopInvoked: (didPop) async {
        debugPrint('PopScope: didPop=$didPop, tickerStocks=${_tickerStocks.isNotEmpty}');
        if (!didPop && _tickerStocks.isNotEmpty) {
          await PiPService.enterPiPMode();
          setState(() {
            _isFloatingWindowActive = true;
          });
        }
      },
      child: Scaffold(
        appBar: _isFloatingWindowActive ? null : AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search symbol...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFloatingWindowActive ? Icons.close_fullscreen : Icons.open_in_full,
                color: Colors.black,
              ),
              onPressed: _toggleFloatingWindow,
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: _gotoProfileFilters,
            ),
          ],
        ),
        body: _isFloatingWindowActive
            ? PipTickerView(
                stocks: pipStocks,
                displayPrefs: {
                  'showSymbol': _tickerShowSymbol,
                  'showName': _tickerShowName,
                  'showPrice': _tickerShowPrice,
                  'showPercentChange': _tickerShowPercentChange,
                  'showAbsoluteChange': _tickerShowAbsoluteChange,
                  'showVolume': _tickerShowVolume,
                  'showOpeningPrice': _tickerShowOpeningPrice,
                  'showDailyHighLow': _tickerShowDailyHighLow,
                },
                separator: _separator,
              )
            : Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(),

            Container(
              constraints: BoxConstraints(
                minHeight: 100,  // Reduced minimum height
                maxHeight: 300,
              ),
              child: _tickerStocks.isEmpty
                  ? const Center(child: Text('No stocks in ticker.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tickerStocks.map((stock) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(16),
                                width: 300,
                                constraints: const BoxConstraints(
                                  minHeight: 80,  // Minimum card height
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade100,
                                      stock.absoluteChange >= 0 ? Colors.green : Colors.red,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade300,
                                      blurRadius: 6,
                                      offset: const Offset(2, 4),
                                    ),
                                  ],
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_tickerShowName)
                                              Text(
                                                stock.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            if (_tickerShowSymbol)
                                              Text(
                                                stock.symbol,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            if (_tickerShowPrice)
                                              Text(
                                                '\$${stock.currentPrice.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: stock.absoluteChange >= 0 
                                                      ? Colors.green 
                                                      : Colors.red,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            if (_tickerShowAbsoluteChange || _tickerShowPercentChange)
                                              Row(
                                                children: [
                                                  if (_tickerShowAbsoluteChange)
                                                    Text(
                                                      '${stock.absoluteChange >= 0 ? '+' : ''}'
                                                          '${stock.absoluteChange.toStringAsFixed(2)}  ',
                                                      style: TextStyle(
                                                        color: stock.absoluteChange >= 0 
                                                            ? Colors.green 
                                                            : Colors.red,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  if (_tickerShowPercentChange)
                                                    Text(
                                                      '${stock.percentChange >= 0 ? '+' : ''}'
                                                          '${stock.percentChange.toStringAsFixed(2)}%',
                                                      style: TextStyle(
                                                        color: stock.absoluteChange >= 0 
                                                            ? Colors.green 
                                                            : Colors.red,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            if (_tickerShowVolume)
                                              Text(
                                                'Vol: ${stock.volume}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            if (_tickerShowOpeningPrice)
                                              Text(
                                                'Open: \$${stock.openPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            if (_tickerShowDailyHighLow)
                                              Text(
                                                'H: \$${stock.highPrice.toStringAsFixed(2)}  '
                                                    'L: \$${stock.lowPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 48,
                                        width: 48,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.shade400.withOpacity(0.5),
                                              blurRadius: 6,
                                              offset: const Offset(2, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.asset(
                                            stock.absoluteChange >= 0
                                                ? 'assets/images/greengraph.png'
                                                : 'assets/images/redgraph.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
            ),

            const Divider(height: 1),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No stocks found.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final stock = filtered[i];
                        return _buildStockCard(stock);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  //============================================================================
  //                           WIDGET BUILDERS
  //============================================================================

  Widget _buildStockCard(StockData stock) {
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded; // Toggle expanded state
            });
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main collapsed view
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Symbol & Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            stock.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      // Price & changes
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${stock.currentPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${stock.absoluteChange >= 0 ? '+' : ''}'
                                    '${stock.absoluteChange.toStringAsFixed(2)} ',
                                style: TextStyle(color: color, fontSize: 14),
                              ),
                              Text(
                                '(${stock.percentChange >= 0 ? '+' : ''}'
                                    '${stock.percentChange.toStringAsFixed(2)}%)',
                                style: TextStyle(color: color, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Expanded view
                if (isExpanded)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column with text
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volume: ${stock.volume}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Open: \$${stock.openPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'High: \$${stock.highPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Low: \$${stock.lowPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        // Right column with star icon
                        Align(
                          alignment: Alignment.bottomRight,
                          child: IconButton(
                            icon: Icon(
                              _tickerStocks.contains(stock)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: _tickerStocks.contains(stock)
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            onPressed: () => _toggleStockInTicker(stock),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add this method
  void _toggleFloatingWindow() async {
    if (_tickerStocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please star some stocks first to use PiP mode'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_isFloatingWindowActive) {
      // Entering PiP mode
      await PiPService.enterPiPMode();
      if (mounted) {
        setState(() {
          _isFloatingWindowActive = true;
        });
      }
    } else {
      // Exiting PiP mode - just update the state without refetching
      if (mounted) {
        setState(() {
          _isFloatingWindowActive = false;
        });
      }
    }
  }
}
