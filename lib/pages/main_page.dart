import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_filter_page.dart';

/// Represents data for one day's bar for a ticker,
/// combining "today" and "yesterday" to compute changes.
class StockData {
  final String symbol;
  final String name;

  /// For the current day (the "today" date):
  double currentPrice;   // from "c" (close) field
  double openPrice;      // from "o"
  double highPrice;      // from "h"
  double lowPrice;       // from "l"
  int volume;            // from "v"

  /// Changes vs. the previous day:
  double absoluteChange; // (todayClose - yesterdayClose)
  double percentChange;  // (absChange / yesterdayClose) * 100

  StockData({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.absoluteChange,
    required this.percentChange,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockData &&
              runtimeType == other.runtimeType &&
              symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
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

  @override
  void initState() {
    super.initState();

    // 1) Fetch the stock data from Polygon.
    // 2) Then load the user's saved ticker selection from Firestore.
    // 3) Once loaded, combine them so the user sees up-to-date data plus
    //    whichever stocks they previously selected.
    _fetchTwoDaysData().then((_) async {
      await _loadUserTickerSymbols();
      await _loadUserFilterPreferences();
    });
  }

  /// We won't do auto-refresh for grouped data, but you could if desired
  @override
  void dispose() {
    super.dispose();
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
      _allStocks = _symbolCache.values.toList()
        ..sort((a, b) => a.symbol.compareTo(b.symbol));
      // Also refresh any references in ticker if needed.
      // This ensures if data was updated, the ticker sees the new data.
      _tickerStocks = _tickerStocks
          .map((t) => _symbolCache[t.symbol] ?? t)
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
    final filtered = _filterStocks(_searchController.text);

    return Scaffold(
      // -- NO TITLE, replaced with a row that has search bar + settings icon
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // We'll use a Row in place of the usual title
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            // Removing "Find" button; auto-filter as user types
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search symbol...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[200], // Use a light grey background
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey[400]!, width: 1), // Light border
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey[400]!, width: 1), // Light border
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: Colors.blue, width: 1.5), // Thicker border
              ),
            ),
          ),
        ),
        actions: [
          // SETTINGS ICON
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _gotoProfileFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          //===== Progress indicator if loading =====
          if (_isLoading) const LinearProgressIndicator(),

          //===== HORIZONTAL TICKER =====
          // Single-line scroll of "cards"
          SizedBox(
            height: 165,
            child: _tickerStocks.isEmpty
                ? const Center(child: Text('No stocks in ticker.'))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tickerStocks.map((stock) {
                  return _buildTickerStockCard(stock);
                }).toList(),
              ),
            ),
          ),

          //===== MAIN LIST =====
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
    );
  }

  //============================================================================
  //                           WIDGET BUILDERS
  //============================================================================

  /// Builds each ticker item as a horizontally scrollable "card":
  /// Transparent background, gray border, name+symbol+price on left,
  /// plus optional fields on the right, as toggles allow.
  Widget _buildTickerStockCard(StockData stock) {
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;
    final graphImage = (stock.absoluteChange >= 0)
        ? 'assets/images/greengraph.png'
        : 'assets/images/redgraph.png';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade100,
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      width: 300,
      child: Stack(
        children: [
          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stock name, symbol, and price
              if (_tickerShowName)
                Text(
                  stock.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              if (_tickerShowSymbol)
                Text(
                  stock.symbol,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              if (_tickerShowPrice)
                Text(
                  '\$${stock.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              // Gain/loss information
              Row(
                children: [
                  if (_tickerShowAbsoluteChange)
                    Text(
                      '${stock.absoluteChange >= 0 ? '+' : ''}'
                          '${stock.absoluteChange.toStringAsFixed(2)}  ',
                      style: TextStyle(color: color, fontSize: 20),
                    ),
                  if (_tickerShowPercentChange)
                    Text(
                      '${stock.percentChange >= 0 ? '+' : ''}'
                          '${stock.percentChange.toStringAsFixed(2)}%',
                      style: TextStyle(color: color, fontSize: 20),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),

          // Bottom-right details
          Positioned(
            bottom: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_tickerShowVolume)
                  Text(
                    'Vol: ${stock.volume}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                if (_tickerShowOpeningPrice)
                  Text(
                    'Open: \$${stock.openPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                if (_tickerShowDailyHighLow)
                  Text(
                    'H: \$${stock.highPrice.toStringAsFixed(2)}  '
                        'L: \$${stock.lowPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),

          // Top-right gain/loss icon
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              height: 48, // size of the square box
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade400.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  graphImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}
