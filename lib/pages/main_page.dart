import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/pip_service.dart';
import '../services/floating_window_service.dart';
import '../services/data_repository.dart';
import '../services/twelve_data_service.dart';
import '../services/polygon_service.dart';

import '../widgets/pip_ticker_view.dart';
import '../widgets/watchlist_card.dart';
import 'profile_filter_page.dart';
import 'search_page.dart';
import '../models/stock_data.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final user = FirebaseAuth.instance.currentUser;

  bool _isFloatingWindowActive = false;
  bool _isLoading = false;

  // Ticker filter prefs
  bool _tickerShowSymbol         = true;
  bool _tickerShowName           = true;
  bool _tickerShowPrice          = true;
  bool _tickerShowPercentChange  = true;
  bool _tickerShowAbsoluteChange = false;
  bool _tickerShowVolume         = false;
  bool _tickerShowOpeningPrice   = false;
  bool _tickerShowDailyHighLow   = false;
  String _separator              = ' .... ';

  List<String> _watchlistSymbols = [];
  List<StockData> _watchlistData = [];

  final TextEditingController _searchController = TextEditingController();
  String get _searchQuery => _searchController.text.trim().toLowerCase();

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // PiP
    Future.delayed(const Duration(milliseconds: 100), () {
      PiPService.setIsMainPage(true);
    });

    const channel = MethodChannel('com.stocktok/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPChanged') {
        final isInPiP = call.arguments as bool;
        if (mounted) {
          setState(() => _isFloatingWindowActive = isInPiP);
        }
      }
    });

    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);

    // 1) Combine data from Polygon (two days)
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    try {
      final day2 = _getYesterdaysDate(1);
      final day1 = _getYesterdaysDate(2);
      final combined = await PolygonService.fetchTwoDaysCombined(
        day1: day1,
        day2: day2,
      );
      dataRepo.addPolygonData(combined);
    } catch (_) {}

    // 2) Load prefs
    await _loadUserFilterPreferences();

    // 3) Load watchlist
    await _loadUserWatchlist();

    // 4) If watchlist empty => search
    if (_watchlistSymbols.isEmpty && user != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SearchPage(forceSelection: true)),
        );
      }
      return;
    }

    // 5) Refresh from 12Data right now
    await _refreshWatchlist();

    // 6) Also do it every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshWatchlist();
    });

    setState(() => _isLoading = false);
  }

  String _getYesterdaysDate(int daysAgo) {
    final now = DateTime.now().subtract(Duration(days: daysAgo));
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    PiPService.setIsMainPage(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh watchlist items from TwelveData IMMEDIATELY (for each symbol!)
  Future<void> _refreshWatchlist() async {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    List<StockData> updated = [];

    for (final symbol in _watchlistSymbols) {
      // Force immediate fetch from 12Data:
      final fetched = await TwelveDataService.fetchQuote(symbol);
      if (fetched != null) {
        dataRepo.updateSymbolData(fetched);
        updated.add(fetched);
      } else {
        // fallback to local data if fetch fails
        final local = dataRepo.getSymbolData(symbol);
        if (local != null) updated.add(local);
      }
    }

    setState(() => _watchlistData = updated);
  }

  Future<void> _loadUserFilterPreferences() async {
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
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
    } catch (_) {}
  }

  Future<void> _loadUserWatchlist() async {
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;

      final List<dynamic>? symbols = data['selectedTickerSymbols'] as List<dynamic>?;
      if (symbols != null) {
        _watchlistSymbols = symbols.map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveUserWatchlist() async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({
      'selectedTickerSymbols': _watchlistSymbols,
    }, SetOptions(merge: true));
  }

  List<StockData> get filteredWatchlist {
    if (_searchQuery.isEmpty) return _watchlistData;
    return _watchlistData.where((s) {
      return s.symbol.toLowerCase().contains(_searchQuery) ||
          s.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // If user reorders the watchlist
  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final symbol = _watchlistSymbols.removeAt(oldIndex);
    _watchlistSymbols.insert(newIndex, symbol);

    final stock = _watchlistData.removeAt(oldIndex);
    _watchlistData.insert(newIndex, stock);

    setState(() {});
    await _saveUserWatchlist();
  }

  void _toggleFloatingWindow() async {
    if (_watchlistData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some stocks first to use PiP mode')),
      );
      return;
    }
    if (!_isFloatingWindowActive) {
      await PiPService.enterPiPMode();
      setState(() => _isFloatingWindowActive = true);
    } else {
      setState(() => _isFloatingWindowActive = false);
    }
  }

  Future<void> _gotoProfileFilters() async {
    PiPService.setIsMainPage(false);
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
    PiPService.setIsMainPage(true);

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

  @override
  Widget build(BuildContext context) {
    if (_isFloatingWindowActive) {
      // Show PiP ticker
      return Scaffold(
        body: PipTickerView(
          stocks: _watchlistData,
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Filter watchlist...',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFloatingWindowActive ? Icons.close_fullscreen : Icons.open_in_full),
            onPressed: _toggleFloatingWindow,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _gotoProfileFilters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredWatchlist.isEmpty
          ? Center(
        child: ElevatedButton(
          onPressed: () async {
            // Instead of pushReplacement, we push
            final gotNewItems = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage(forceSelection: false)),
            );
            if (gotNewItems == true && mounted) {
              await _refreshWatchlist();
            }
          },
          child: const Text('Add Symbols to Watchlist'),
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshWatchlist,
        child: ReorderableListView.builder(
          itemCount: filteredWatchlist.length,
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final stock = filteredWatchlist[index];
            return Dismissible(
              key: ValueKey(stock.symbol),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (dir) {
                setState(() {
                  _watchlistSymbols.remove(stock.symbol);
                  _watchlistData.remove(stock);
                });
                _saveUserWatchlist();
              },
              child: WatchlistCard(
                key: ValueKey('watchlistCard-${stock.symbol}'),
                stock: stock,
                showSymbol: _tickerShowSymbol,
                showName: _tickerShowName,
                showPrice: _tickerShowPrice,
                showPercentChange: _tickerShowPercentChange,
                showAbsoluteChange: _tickerShowAbsoluteChange,
                showVolume: _tickerShowVolume,
                showOpeningPrice: _tickerShowOpeningPrice,
                showDailyHighLow: _tickerShowDailyHighLow,
                // NO CHECKBOX
                isChecked: false,
                onCheckboxChanged: () {},
              ),
            );
          },
        ),
      ),
    );
  }
}
