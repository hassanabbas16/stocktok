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
  StreamSubscription<DocumentSnapshot>? _watchlistSubscription;

  bool _isFloatingWindowActive = false;
  bool _isLoading = false;

  // Ticker filter preferences.
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

    // Mark that we're on the main page (for PiP-service usage).
    Future.delayed(const Duration(milliseconds: 100), () {
      PiPService.setIsMainPage(true);
    });

    // Listen for PiP changes from the platform channel.
    const channel = MethodChannel('com.stocktok/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPChanged') {
        final isInPiP = call.arguments as bool;
        if (mounted) setState(() => _isFloatingWindowActive = isInPiP);
      }
    });

    _initialLoad();

    // Listen for real-time changes in Firestore for the user's watchlist.
    if (user != null) {
      _watchlistSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots()
          .listen((docSnap) async {
        if (docSnap.exists) {
          final data = docSnap.data();
          if (data != null) {
            final List<dynamic>? symbols = data['selectedTickerSymbols'] as List<dynamic>?;
            if (symbols != null) {
              setState(() {
                _watchlistSymbols = symbols.map((e) => e.toString()).toList();
              });
              await _refreshWatchlist();
            }
          }
        }
      });
    }
  }

  /// When the app resumes, update watchlist data.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateFromFirestore();
    }
  }

  Future<void> _updateFromFirestore() async {
    setState(() => _isLoading = true);
    await _loadUserWatchlist();
    await _refreshWatchlist();
    setState(() => _isLoading = false);
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);

    // (1) Fetch data from Polygon for the last two trading weekdays.
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    try {
      final twoDays = _getLastTwoTradingDays();
      final day1 = _formatDate(twoDays.item1);
      final day2 = _formatDate(twoDays.item2);

      final combined = await PolygonService.fetchTwoDaysCombined(day1: day1, day2: day2);
      dataRepo.addPolygonData(combined);
      print('--- MAIN PAGE: after Polygon fetch, dataRepo has ${dataRepo.polygonCache.length} symbols.');
    } catch (e) {
      print('--- Error in _initialLoad fetching from Polygon: $e');
    }

    // (2) Load user filter preferences.
    await _loadUserFilterPreferences();

    // (3) Load watchlist from Firestore.
    await _loadUserWatchlist();

    // (4) If watchlist is empty, force user to pick stocks.
    if (_watchlistSymbols.isEmpty && user != null) {
      if (mounted) {
        await _openSearchPage(forceSelection: true);
      }
      return;
    }

    // (5) Refresh data from TwelveData.
    await _refreshWatchlist();

    // (6) Also refresh every minute.
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshWatchlist());

    setState(() => _isLoading = false);
  }

  /// When returning from the search page, reload watchlist from Firestore.
  Future<void> _openSearchPage({bool forceSelection = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchPage(forceSelection: forceSelection)),
    );
    await _updateFromFirestore();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _watchlistSubscription?.cancel();
    PiPService.setIsMainPage(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Tuple2<DateTime, DateTime> _getLastTwoTradingDays() {
    DateTime now = DateTime.now();
    DateTime day2candidate = now.subtract(const Duration(days: 1));
    while (_isWeekend(day2candidate)) {
      day2candidate = day2candidate.subtract(const Duration(days: 1));
    }
    final day2 = day2candidate;

    DateTime day1candidate = day2.subtract(const Duration(days: 1));
    while (_isWeekend(day1candidate)) {
      day1candidate = day1candidate.subtract(const Duration(days: 1));
    }
    final day1 = day1candidate;

    return Tuple2<DateTime, DateTime>(day1, day2);
  }

  bool _isWeekend(DateTime dt) {
    return dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Refresh watchlist items from TwelveData.
  Future<void> _refreshWatchlist() async {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    List<StockData> updated = [];
    for (final symbol in _watchlistSymbols) {
      final fetched = await TwelveDataService.fetchQuote(symbol);
      if (fetched != null) {
        dataRepo.updateSymbolData(fetched);
        updated.add(fetched);
      } else {
        final local = dataRepo.getSymbolData(symbol);
        if (local != null) updated.add(local);
      }
    }
    setState(() => _watchlistData = updated);
  }

  /// Load user filter preferences from Firestore.
  Future<void> _loadUserFilterPreferences() async {
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;
      final prefs = data['filterPreferences'];
      if (prefs is Map<String, dynamic>) {
        setState(() {
          _tickerShowSymbol         = prefs['showSymbol'] ?? _tickerShowSymbol;
          _tickerShowName           = prefs['showName'] ?? _tickerShowName;
          _tickerShowPrice          = prefs['showPrice'] ?? _tickerShowPrice;
          _tickerShowPercentChange  = prefs['showPercentChange'] ?? _tickerShowPercentChange;
          _tickerShowAbsoluteChange = prefs['showAbsoluteChange'] ?? _tickerShowAbsoluteChange;
          _tickerShowVolume         = prefs['showVolume'] ?? _tickerShowVolume;
          _tickerShowOpeningPrice   = prefs['showOpeningPrice'] ?? _tickerShowOpeningPrice;
          _tickerShowDailyHighLow   = prefs['showDailyHighLow'] ?? _tickerShowDailyHighLow;
          _separator                = prefs['separator'] ?? _separator;
        });
      }
    } catch (_) {}
  }

  /// Load watchlist symbols from Firestore.
  Future<void> _loadUserWatchlist() async {
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;
      final List<dynamic>? symbols = data['selectedTickerSymbols'] as List<dynamic>?;
      if (symbols != null) {
        _watchlistSymbols = symbols.map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }

  /// Save the user's watchlist to Firestore.
  Future<void> _saveUserWatchlist() async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
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

  /// Reorder watchlist items.
  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final symbol = _watchlistSymbols.removeAt(oldIndex);
    _watchlistSymbols.insert(newIndex, symbol);

    final stock = _watchlistData.removeAt(oldIndex);
    _watchlistData.insert(newIndex, stock);

    setState(() {});
    await _saveUserWatchlist();
    await _refreshWatchlist();
  }

  /// Toggle Picture-in-Picture.
  void _toggleFloatingWindow() async {
    if (_watchlistData.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please add some stocks first to use PiP mode')));
      return;
    }
    if (!_isFloatingWindowActive) {
      await PiPService.enterPiPMode();
      setState(() => _isFloatingWindowActive = true);
    } else {
      setState(() => _isFloatingWindowActive = false);
    }
  }

  /// Navigate to profile/filter settings.
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
        _tickerShowSymbol         = result['showSymbol'] ?? _tickerShowSymbol;
        _tickerShowName           = result['showName'] ?? _tickerShowName;
        _tickerShowPrice          = result['showPrice'] ?? _tickerShowPrice;
        _tickerShowPercentChange  = result['showPercentChange'] ?? _tickerShowPercentChange;
        _tickerShowAbsoluteChange = result['showAbsoluteChange'] ?? _tickerShowAbsoluteChange;
        _tickerShowVolume         = result['showVolume'] ?? _tickerShowVolume;
        _tickerShowOpeningPrice   = result['showOpeningPrice'] ?? _tickerShowOpeningPrice;
        _tickerShowDailyHighLow   = result['showDailyHighLow'] ?? _tickerShowDailyHighLow;
        _separator                = result['separator'] ?? _separator;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFloatingWindowActive) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/iconf.png', height: 28, color: isDark ? Colors.white : null),
            const SizedBox(width: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Stock',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const TextSpan(
                    text: 'Tok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE5F64A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredWatchlist.isEmpty
          ? Center(
        child: ElevatedButton(
          onPressed: () => _openSearchPage(forceSelection: false),
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
            return Column(
              key: ValueKey('reorder_${stock.symbol}'),
              children: [
                Dismissible(
                  key: ValueKey('dismiss_${stock.symbol}'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) async {
                    setState(() {
                      _watchlistSymbols.remove(stock.symbol);
                      _watchlistData.remove(stock);
                    });
                    await _saveUserWatchlist();
                    await _refreshWatchlist();
                    print('Dismissed item: ${stock.symbol}');
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
                    isChecked: false,
                    onCheckboxChanged: () {},
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: Container(
          height: 60,
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFloatingWindowActive ? Icons.close_fullscreen : Icons.open_in_full,
                  color: Colors.grey[600],
                ),
                onPressed: _toggleFloatingWindow,
              ),
              IconButton(
                iconSize: 24,
                icon: Icon(Icons.person, color: Colors.grey[600]),
                onPressed: _gotoProfileFilters,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple data holder for a pair of dates.
class Tuple2<A, B> {
  final A item1;
  final B item2;
  Tuple2(this.item1, this.item2);
}
