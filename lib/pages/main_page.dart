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
import '../widgets/pip_ticker_view.dart';
import '../widgets/watchlist_card.dart';
import '../pages/profile_filter_page.dart';
import '../pages/search_page.dart';
import '../models/stock_data.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final user = FirebaseAuth.instance.currentUser;
  bool _isFloatingWindowActive = false;

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

  List<String> _watchlistSymbols = [];
  List<StockData> _watchlistData = [];
  bool _isLoading = false;

  final FloatingWindowService _floatingWindowService = FloatingWindowService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Indicate this page is the main page for PiP logic
    Future.delayed(const Duration(milliseconds: 100), () {
      PiPService.setIsMainPage(true);
    });

    // Listen for PiP changes
    var channel = MethodChannel('com.stocktok/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPChanged') {
        final isInPiP = call.arguments as bool;
        if (mounted) {
          setState(() {
            _isFloatingWindowActive = isInPiP;
          });
        }
      }
    });

    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);

    // Load filter prefs from Firestore
    await _loadUserFilterPreferences();

    // Load user watchlist symbols
    await _loadUserWatchlist();

    // If watchlist is empty, navigate immediately to search page
    // but only if they are logged in
    if (_watchlistSymbols.isEmpty && user != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SearchPage(forceSelection: true)),
        );
      }
      return;
    }

    // Start a timer to update watchlist data every minute from 12Data
    Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshWatchlist();
    });

    await _refreshWatchlist(); // initial fetch from 12Data for watchlist

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    PiPService.setIsMainPage(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// If app is in PiP and we resume, we might want to exit PiP or refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // do any needed refresh if returning from background, etc.
    }
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
    } catch (e) {
      // Handle error
    }
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
      if (symbols == null) return;

      _watchlistSymbols = symbols.map((e) => e.toString()).toList();
    } catch (e) {
      // handle error
    }
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

  /// Refresh watchlist data from the DataRepository + TwelveData
  Future<void> _refreshWatchlist() async {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    // Build list of StockData for watchlist from our DataRepository cache if present
    // Then queue or fetch from 12Data to get updated pricing
    List<StockData> updated = [];

    for (final symbol in _watchlistSymbols) {
      // Add symbol to the fetch queue
      TwelveDataService.enqueueSymbol(symbol);

      // See if we have it in dataRepo's polygonCache
      final cached = dataRepo.getSymbolData(symbol);
      if (cached != null) {
        updated.add(cached);
      } else {
        // if not found in polygon data, we do a direct fetch from 12data
        final fetched = await TwelveDataService.fetchQuote(symbol);
        if (fetched != null) {
          dataRepo.updateSymbolData(fetched);
          updated.add(fetched);
        } else {
          // fallback empty
        }
      }
    }

    setState(() {
      _watchlistData = updated;
    });
  }

  /// Toggles the PiP floating window
  void _toggleFloatingWindow() async {
    if (_watchlistData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some stocks first to use PiP mode'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_isFloatingWindowActive) {
      // Enter PiP
      await PiPService.enterPiPMode();
      setState(() => _isFloatingWindowActive = true);
    } else {
      // Exit PiP
      setState(() => _isFloatingWindowActive = false);
    }
  }

  /// Toggle a symbol's watchlist membership
  void _onWatchlistCheckboxTap(StockData stock) async {
    setState(() {
      if (_watchlistSymbols.contains(stock.symbol)) {
        _watchlistSymbols.remove(stock.symbol);
      } else {
        _watchlistSymbols.add(stock.symbol);
      }
    });
    await _saveUserWatchlist();
    await _refreshWatchlist();
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
    final watchlistStocks = _watchlistData;

    if (_isFloatingWindowActive) {
      // Show the PiP Ticker View
      return Scaffold(
        body: PipTickerView(
          stocks: watchlistStocks,
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'StockTok Home',
          style: TextStyle(color: Colors.black),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (watchlistStocks.isEmpty)
          ? Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchPage(forceSelection: false),
              ),
            );
          },
          child: const Text('Add Symbols to Watchlist'),
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshWatchlist,
        child: ListView.builder(
          itemCount: watchlistStocks.length,
          itemBuilder: (context, index) {
            final stock = watchlistStocks[index];
            final isChecked = _watchlistSymbols.contains(stock.symbol);

            return WatchlistCard(
              stock: stock,
              showSymbol: _tickerShowSymbol,
              showName: _tickerShowName,
              showPrice: _tickerShowPrice,
              showPercentChange: _tickerShowPercentChange,
              showAbsoluteChange: _tickerShowAbsoluteChange,
              showVolume: _tickerShowVolume,
              showOpeningPrice: _tickerShowOpeningPrice,
              showDailyHighLow: _tickerShowDailyHighLow,
              isChecked: isChecked,
              onCheckboxChanged: () => _onWatchlistCheckboxTap(stock),
            );
          },
        ),
      ),
    );
  }
}
