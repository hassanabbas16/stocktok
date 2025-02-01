import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'profile_filter_page.dart';

class StockData {
  final String symbol;
  final String name;

  double currentPrice;
  double openPrice;
  double highPrice;
  double lowPrice;
  int volume;

  double absoluteChange;
  double percentChange;

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
          other is StockData && runtimeType == other.runtimeType && symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

class MainPage extends StatefulWidget {
  /// Callback to send overlay data from this screen
  final Future<void> Function(String jsonData)? onSendOverlayData;

  const MainPage({Key? key, this.onSendOverlayData}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late String _dateToFetch;
  late String _prevDateToFetch;

  final String _polygonApiKey = dotenv.env['POLYGON_API_KEY'] ?? '';

  final Map<String, StockData> _symbolCache = {};
  List<StockData> _allStocks = [];
  List<StockData> _tickerStocks = [];

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
    final DateTime today = DateTime.now();
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    DateTime prevDate = today.subtract(const Duration(days: 1));

    DateTime prevPrevDate = prevDate.subtract(const Duration(days: 1));

    _dateToFetch = _formatDate(prevDate);
    _prevDateToFetch = _formatDate(prevPrevDate);


    _fetchTwoDaysData().then((_) async {
      await _loadUserTickerSymbols();
      await _loadUserFilterPreferences();
      // After loading everything, let's push current ticker data to overlay
      _sendTickerToOverlay();
    });
  }

  //============================== FETCH LOGIC ===============================
  String _formatDate(DateTime date) {
    return "${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _fetchTwoDaysData() async {
    if (!mounted) return;
    setState(() => _isLoading = false);

    final todayMap = await _fetchGroupedForDate(_dateToFetch);
    final prevMap  = await _fetchGroupedForDate(_prevDateToFetch);

    for (final symbol in todayMap.keys) {
      final todayData     = todayMap[symbol]!;
      final yesterdayData = prevMap[symbol];
      final yesterdayClose = yesterdayData?.currentPrice ?? 0;
      final absChange     = todayData.currentPrice - yesterdayClose;

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

  Future<Map<String, StockData>> _fetchGroupedForDate(String dateStr) async {
    final Map<String, StockData> map = {};
    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/us/market/stocks/$dateStr'
          '?adjusted=true&apiKey=$_polygonApiKey',
    );

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final jsonMap = json.decode(resp.body);
        if (jsonMap['status'] == 'OK' && jsonMap['results'] is List) {
          for (final item in jsonMap['results']) {
            final symbol = (item['T'] ?? '').toString();
            if (symbol.isEmpty) continue;

            final open  = (item['o'] ?? 0).toDouble();
            final close = (item['c'] ?? 0).toDouble();
            final high  = (item['h'] ?? 0).toDouble();
            final low   = (item['l'] ?? 0).toDouble();
            final vol   = (item['v'] ?? 0).toDouble();

            final stock = StockData(
              symbol: symbol,
              name:   symbol, // or do real lookup
              currentPrice: close,
              openPrice:    open,
              highPrice:    high,
              lowPrice:     low,
              volume:       vol.toInt(),
              absoluteChange: 0,
              percentChange:  0,
            );
            map[symbol] = stock;
          }
        } else {
          debugPrint('Polygon response not OK for $dateStr');
        }
      } else {
        debugPrint('HTTP Error for $dateStr: ${resp.statusCode} -> ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error fetching daily for $dateStr: $e');
    }

    return map;
  }

  void _rebuildAllStocksFromCache() {
    if (!mounted) return;
    setState(() {
      _allStocks = _symbolCache.values.toList()
        ..sort((a, b) => a.symbol.compareTo(b.symbol));
      // Also refresh any references in ticker
      _tickerStocks = _tickerStocks
          .map((t) => _symbolCache[t.symbol] ?? t)
          .toList();
    });
  }

  //========================== FIRESTORE PERSISTENCE ==========================
  Future<void> _loadUserTickerSymbols() async {
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

      final List<dynamic>? symbolList = data['selectedTickerSymbols'] as List<dynamic>?;
      if (symbolList == null) return;

      final newTicker = <StockData>[];
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

  Future<void> _saveUserTickerSymbols() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

  //============================= OVERLAY LOGIC ==============================
  /// Whenever the ticker list changes, call this to send updated data to the overlay
  void _sendTickerToOverlay() {
    if (widget.onSendOverlayData == null) return;

    final tickerList = _tickerStocks.map((s) => {
      'symbol': s.symbol,
      'name': s.name,
      'currentPrice': s.currentPrice,
      'absoluteChange': s.absoluteChange,
      'percentChange': s.percentChange,
    }).toList();

    final jsonString = jsonEncode(tickerList);
    widget.onSendOverlayData!(jsonString);
  }

  //=============================== UI METHODS ===============================
  void _toggleStockInTicker(StockData stock) {
    setState(() {
      if (_tickerStocks.contains(stock)) {
        _tickerStocks.remove(stock);
      } else {
        _tickerStocks.add(stock);
      }
    });
    _saveUserTickerSymbols();
    _sendTickerToOverlay(); // refresh overlay
  }

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
      // Refresh overlay if filters changed
      _sendTickerToOverlay();
    }
  }

  //========================= ADDING THE _filterStocks METHOD =========================
  /// Filter the main list by search text
  List<StockData> _filterStocks(String query) {
    if (query.isEmpty) return _allStocks;

    final lowerQuery = query.toLowerCase();
    return _allStocks.where((stock) {
      final symbolMatch = stock.symbol.toLowerCase().contains(lowerQuery);
      final nameMatch   = stock.name.toLowerCase().contains(lowerQuery);
      return symbolMatch || nameMatch;
    }).toList();
  }

  //============================== BUILD ===============================
  @override
  Widget build(BuildContext context) {
    final filtered = _filterStocks(_searchController.text);

    return Scaffold(
      appBar: AppBar(
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _gotoProfileFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
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

  //=========================== WIDGET BUILDERS ===========================
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
          colors: [Colors.grey.shade100, color],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              height: 48,
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
              isExpanded = !isExpanded;
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
                // Collapsed row
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                // Expanded details
                if (isExpanded)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
