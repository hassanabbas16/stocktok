import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_fetcher_service.dart';
import '../services/pip_service.dart';
import '../services/floating_window_service.dart';
import 'package:intl/intl.dart';
import '../models/stock_data.dart';
import '../widgets/stock_card.dart';
import '../widgets/pip_ticker_view.dart';
import 'profile_filter_page.dart';
import 'search_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  late String _todayDate = '2025-02-26';
  String _yesterdayDate = '2025-02-25';

  Map<String, StockData> _symbolCache = {};
  List<StockData> _allStocks = [];
  List<StockData> _tickerStocks = [];
  bool _isLoading = false;
  bool _isFloatingWindowActive = false;
  Timer? _tickerUpdateTimer;
  final TextEditingController _searchController = TextEditingController();

  // Filter preferences
  bool _tickerShowSymbol = true;
  bool _tickerShowName = true;
  bool _tickerShowPrice = true;
  bool _tickerShowPercentChange = true;
  bool _tickerShowAbsoluteChange = false;
  bool _tickerShowVolume = false;
  bool _tickerShowOpeningPrice = false;
  bool _tickerShowDailyHighLow = false;
  String _separator = ' .... ';

  Map<String, StockData> _originalDataCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();
    _todayDate = DateFormat('yyyy-MM-dd').format(now);
    _yesterdayDate = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 1)));

    Future.delayed(Duration(milliseconds: 100), () {
      PiPService.setIsMainPage(true);
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
    _fetchInitialData();
    _tickerUpdateTimer = Timer.periodic(Duration(minutes: 1), (_) => _updateTickerData());
  }

  @override
  void dispose() {
    PiPService.setIsMainPage(false);
    WidgetsBinding.instance.removeObserver(this);
    _tickerUpdateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });
    final data = await DataFetcherService.fetchInitialData(
      today: _todayDate,
      yesterday: _yesterdayDate,
    );
    print('Fetched ${data.length} symbols');
    setState(() {
      _symbolCache = data;
      _allStocks = _symbolCache.values.toList()..sort((a, b) => a.symbol.compareTo(b.symbol));
      _originalDataCache = Map.from(_symbolCache);
      _isLoading = false;
    });
  }

  Future<void> _updateTickerData() async {
    if (_tickerStocks.isEmpty) return;
    List<String> symbols = _tickerStocks.map((s) => s.symbol).toList();
    final updatedData = await DataFetcherService.updateTickerData(symbols);
    setState(() {
      for (var symbol in updatedData.keys) {
        _symbolCache[symbol] = updatedData[symbol]!;
      }
      _rebuildAllStocksFromCache();
    });
  }

  void _rebuildAllStocksFromCache() {
    setState(() {
      _allStocks = _symbolCache.values.toList()..sort((a, b) => a.symbol.compareTo(b.symbol));
      _tickerStocks = _tickerStocks.map((ticker) {
        return _allStocks.firstWhere((s) => s.symbol == ticker.symbol, orElse: () => ticker);
      }).toList();
    });
  }

  Future<void> _gotoProfileFilters() async {
    PiPService.setIsMainPage(false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileFilterPage(
          showSymbol: _tickerShowSymbol,
          showName: _tickerShowName,
          showPrice: _tickerShowPrice,
          showPercentChange: _tickerShowPercentChange,
          showAbsoluteChange: _tickerShowAbsoluteChange,
          showVolume: _tickerShowVolume,
          showOpeningPrice: _tickerShowOpeningPrice,
          showDailyHighLow: _tickerShowDailyHighLow,
          separator: _separator,
        ),
      ),
    );
    PiPService.setIsMainPage(true);
    if (result is Map<String, dynamic>) {
      setState(() {
        _tickerShowSymbol = result['showSymbol'] ?? _tickerShowSymbol;
        _tickerShowName = result['showName'] ?? _tickerShowName;
        _tickerShowPrice = result['showPrice'] ?? _tickerShowPrice;
        _tickerShowPercentChange = result['showPercentChange'] ?? _tickerShowPercentChange;
        _tickerShowAbsoluteChange = result['showAbsoluteChange'] ?? _tickerShowAbsoluteChange;
        _tickerShowVolume = result['showVolume'] ?? _tickerShowVolume;
        _tickerShowOpeningPrice = result['showOpeningPrice'] ?? _tickerShowOpeningPrice;
        _tickerShowDailyHighLow = result['showDailyHighLow'] ?? _tickerShowDailyHighLow;
        _separator = result['separator'] ?? _separator;
      });
    }
  }

  void _toggleFloatingWindow() async {
    if (_tickerStocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please star some stocks first to use PiP mode')),
      );
      return;
    }
    if (!_isFloatingWindowActive) {
      await PiPService.enterPiPMode();
      setState(() {
        _isFloatingWindowActive = true;
      });
    } else {
      setState(() {
        _isFloatingWindowActive = false;
      });
    }
  }

  List<StockData> _filterStocks(String query) {
    if (query.isEmpty) return _allStocks;
    final lower = query.toLowerCase();
    return _allStocks.where((stock) =>
    stock.symbol.toLowerCase().contains(lower) ||
        stock.name.toLowerCase().contains(lower)
    ).toList();
  }

  void _toggleStockInTicker(StockData stock) {
    setState(() {
      if (_tickerStocks.contains(stock)) {
        _tickerStocks.remove(stock);
      } else {
        _tickerStocks.add(stock);
      }
    });
    // In production, persist ticker selection in Firestore.
  }

  @override
  Widget build(BuildContext context) {
    final List<StockData> pipStocks = _tickerStocks;
    final filtered = _filterStocks(_searchController.text);
    return Scaffold(
      appBar: _isFloatingWindowActive
          ? null
          : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search symbol...',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFloatingWindowActive ? Icons.close_fullscreen : Icons.open_in_full, color: Colors.black),
            onPressed: _toggleFloatingWindow,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: _gotoProfileFilters,
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchPage(cachedStocks: _allStocks)),
              );
            },
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
          if (_isLoading) LinearProgressIndicator(),
          Container(
            constraints: BoxConstraints(minHeight: 100, maxHeight: 300),
            child: _tickerStocks.isEmpty
                ? Center(child: Text('No stocks in ticker.'))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tickerStocks.map((stock) {
                  return StockCard(
                    stock: stock,
                    showFilters: {
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
                    onToggle: () => _toggleStockInTicker(stock),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('No stocks found.'))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final stock = filtered[index];
                return StockCard(
                  stock: stock,
                  showFilters: {
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
                  onToggle: () => _toggleStockInTicker(stock),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
