import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';

/// Replace with your real Alpha Vantage API key.
const alphaVantageApiKey = 'VuAp8k6bioJUIuflawofK1jbfA0U1V9s';

/// This page demonstrates:
///  - Searching for stocks via SYMBOL_SEARCH
///  - Displaying card-based results
///  - On tap/expand to show more details from OVERVIEW + GLOBAL_QUOTE
///  - A watchlist with a horizontally scrolling marquee that refreshes every 1 minute

class SearchStocksPage extends StatefulWidget {
  @override
  _SearchStocksPageState createState() => _SearchStocksPageState();
}

class _SearchStocksPageState extends State<SearchStocksPage> {
  // ------- UI / Searching -------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // ------- Watchlist + Ticker Data -------
  // All symbols that user wants to watch
  List<String> _watchlistSymbols = [];

  // For each symbol: store a “live” data map (from Global Quote)
  // e.g. { "price": 150.0, "change": +2.0, "percent": 1.2, "high":..., "low":... }
  Map<String, Map<String, dynamic>> _watchlistLiveData = {};

  // ------- Timer for watchlist refreshing -------
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Optionally, load existing watchlist from your local store or Firebase
    // For demonstration, we start empty:
    _watchlistSymbols = [];

    // Kick off a periodic refresh (every 1 minute)
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _refreshWatchlist();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //                           ALPHA VANTAGE CALLS
  // ---------------------------------------------------------------------------

  /// Symbol search: returns a list of matches for the given keywords.
  /// Each match typically has "1. symbol", "2. name", "3. type", "4. region", ...
  Future<List<Map<String, dynamic>>> _symbolSearch(String keywords) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=$keywords&apikey=$alphaVantageApiKey',
    );

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final matches = body['bestMatches'] as List<dynamic>?;

        if (matches == null) return [];
        // Convert each bestMatch to a simpler map
        return matches.map((m) {
          return {
            'symbol': m['1. symbol'] ?? '',
            'name': m['2. name'] ?? '',
            'type': m['3. type'] ?? '',
            'region': m['4. region'] ?? '',
          };
        }).toList();
      }
    } catch (e) {
      print('Error in symbolSearch: $e');
    }
    return [];
  }

  /// Fetch a "Global Quote" from alpha vantage for real-time price info.
  /// We'll parse a few relevant fields and return them in a map.
  Future<Map<String, dynamic>> _fetchGlobalQuote(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$alphaVantageApiKey',
    );
    Map<String, dynamic> result = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final q = data['Global Quote'] ?? {};
        if (q.isNotEmpty) {
          double price = double.tryParse(q['05. price'] ?? '') ?? 0.0;
          double change = double.tryParse(q['09. change'] ?? '') ?? 0.0;
          double changePct = 0.0;
          if ((q['10. change percent'] ?? '').contains('%')) {
            changePct = double.tryParse(
                (q['10. change percent'] ?? '').replaceAll('%', '')) ??
                0.0;
          }
          double high = double.tryParse(q['03. high'] ?? '') ?? 0.0;
          double low = double.tryParse(q['04. low'] ?? '') ?? 0.0;
          double open = double.tryParse(q['02. open'] ?? '') ?? 0.0;
          int volume = int.tryParse(q['06. volume'] ?? '') ?? 0;

          result = {
            'price': price,
            'change': change,
            'changePct': changePct,
            'high': high,
            'low': low,
            'open': open,
            'volume': volume,
          };
        }
      }
    } catch (e) {
      print('Error fetching global quote for $symbol: $e');
    }
    return result;
  }

  /// Fetch the "Overview" to get fundamental data: MarketCap, PE, 52W High, description, etc.
  Future<Map<String, dynamic>> _fetchOverview(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=OVERVIEW&symbol=$symbol&apikey=$alphaVantageApiKey',
    );
    Map<String, dynamic> result = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        // If data is empty, we might get an empty map. Otherwise we might see:
        // {
        //   "Symbol": "AAPL",
        //   "AssetType": "Common Stock",
        //   "Name": "Apple Inc",
        //   "Description": "...",
        //   "MarketCapitalization": "1234567890",
        //   "PERatio": "28.50",
        //   "52WeekHigh": "182.94",
        //   ...
        // }
        if (data.isNotEmpty && data['Symbol'] != null) {
          result = {
            'marketCap': data['MarketCapitalization'] ?? '',
            'peRatio': data['PERatio'] ?? '',
            'fiftyTwoWeekHigh': data['52WeekHigh'] ?? '',
            'description': data['Description'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error fetching overview for $symbol: $e');
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  //                            UI LOGIC
  // ---------------------------------------------------------------------------

  /// Called every 1 minute to update the watchlist's real-time data
  Future<void> _refreshWatchlist() async {
    for (final sym in _watchlistSymbols) {
      final quote = await _fetchGlobalQuote(sym);
      _watchlistLiveData[sym] = quote;
    }
    setState(() {});
  }

  /// Called when user types a search query
  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _symbolSearch(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// Adds a symbol to the watchlist
  Future<void> _addToWatchlist(String symbol) async {
    if (!_watchlistSymbols.contains(symbol)) {
      _watchlistSymbols.add(symbol);
      // Immediately fetch its real-time data
      final quote = await _fetchGlobalQuote(symbol);
      _watchlistLiveData[symbol] = quote;
      setState(() {});
    }
  }

  /// Removes a symbol from the watchlist
  void _removeFromWatchlist(String symbol) {
    if (_watchlistSymbols.contains(symbol)) {
      _watchlistSymbols.remove(symbol);
      _watchlistLiveData.remove(symbol);
      setState(() {});
    }
  }

  /// Sign out user (Firebase)
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // ---------------------------------------------------------------------------
  //                                BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top AppBar with search & settings
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: Container(
          height: 40,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search for stocks...',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              fillColor: Colors.grey[800],
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // TODO: Navigate to your filter/profile page
              // Navigator.push(context, ...);
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          // 1) Watchlist marquee on top
          if (_watchlistSymbols.isNotEmpty)
            Container(
              height: 40,
              color: Colors.black,
              child: Marquee(
                text: _buildMarqueeText(),
                velocity: 30,
                blankSpace: 50,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),

          // 2) Body split into watchlist “cards” + search results
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Watchlist section (similar to your mock UI)
                  if (_watchlistSymbols.isNotEmpty) ...[
                    Text(
                      'Watchlist',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildWatchlistRow(context),
                  ],
                  SizedBox(height: 20),
                  // Search results
                  if (_searchResults.isNotEmpty)
                    Text(
                      'Search Results',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  _isSearching
                      ? Center(child: CircularProgressIndicator())
                      : _buildSearchResults(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Creates a horizontally scrollable row of watchlist items,
  /// each with a small card that looks like your screenshot
  Widget _buildWatchlistRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _watchlistSymbols.map((sym) {
          final data = _watchlistLiveData[sym] ?? {};
          final price = data['price'] ?? 0.0;
          final changePct = data['changePct'] ?? 0.0;
          final color = changePct >= 0 ? Colors.green : Colors.red;

          return GestureDetector(
            onTap: () {
              // Optionally show expanded info in a dialog or separate page
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              width: 140,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    sym,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatPrice(price),
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${changePct.toStringAsFixed(2)}%',
                    style: TextStyle(color: color),
                  ),
                  SizedBox(height: 4),
                  // Remove button or icon
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.white54),
                    onPressed: () => _removeFromWatchlist(sym),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds a string for the marquee
  String _buildMarqueeText() {
    List<String> items = [];
    for (final sym in _watchlistSymbols) {
      final data = _watchlistLiveData[sym] ?? {};
      final price = data['price'] ?? 0.0;
      final pct = data['changePct'] ?? 0.0;
      final sign = (pct >= 0) ? '+' : '';
      items.add('$sym \$${_formatPrice(price)} (${sign}${pct.toStringAsFixed(2)}%)');
    }
    // Join with some separator
    return items.join('   |   ');
  }

  /// Builds the search results area
  /// For each result, we show a card that on tap expands or we show details inline
  Widget _buildSearchResults() {
    return Column(
      children: _searchResults.map((match) {
        final sym = match['symbol'] ?? '';
        final name = match['name'] ?? '';
        return _SymbolCard(
          symbol: sym,
          companyName: name,
          onAddToWatchlist: (checked) async {
            if (checked) {
              await _addToWatchlist(sym);
            } else {
              _removeFromWatchlist(sym);
            }
          },
        );
      }).toList(),
    );
  }

  /// Formats a numeric price nicely
  String _formatPrice(num val) {
    return val.toStringAsFixed(2);
  }
}

/// A custom widget representing one search result card.
/// When expanded, it shows more details (fetched from GlobalQuote & Overview).
/// Also has a checkbox to "Add to Watchlist."
class _SymbolCard extends StatefulWidget {
  final String symbol;
  final String companyName;
  final Function(bool checked) onAddToWatchlist;

  const _SymbolCard({
    Key? key,
    required this.symbol,
    required this.companyName,
    required this.onAddToWatchlist,
  }) : super(key: key);

  @override
  __SymbolCardState createState() => __SymbolCardState();
}

class __SymbolCardState extends State<_SymbolCard> {
  bool _isExpanded = false;
  bool _isChecked = false;

  // Data fetched from alpha vantage
  Map<String, dynamic> _quoteData = {};
  Map<String, dynamic> _overviewData = {};
  bool _isLoadingDetails = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _toggleExpand(),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Symbol & Name in row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.symbol,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        widget.companyName,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  // The "Add to watchlist" checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _isChecked,
                        onChanged: (val) {
                          setState(() => _isChecked = val ?? false);
                          widget.onAddToWatchlist(_isChecked);
                        },
                      ),
                      Text(
                        'Add to Watchlist',
                        style: TextStyle(color: Colors.white70),
                      )
                    ],
                  ),
                ],
              ),
              // If expanded, show details
              if (_isExpanded) _buildExpandedSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggles expansion
  void _toggleExpand() async {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && _quoteData.isEmpty && _overviewData.isEmpty) {
      // fetch details
      setState(() => _isLoadingDetails = true);
      final quote = await _fetchGlobalQuote(widget.symbol);
      final overview = await _fetchOverview(widget.symbol);
      setState(() {
        _quoteData = quote;
        _overviewData = overview;
        _isLoadingDetails = false;
      });
    }
  }

  /// Additional detail UI: price, daily change, market cap, 52w high, description, etc.
  Widget _buildExpandedSection() {
    if (_isLoadingDetails) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Extract data
    final price = _quoteData['price'] ?? 0.0;
    final change = _quoteData['change'] ?? 0.0;
    final pct = _quoteData['changePct'] ?? 0.0;
    final color = (pct >= 0) ? Colors.green : Colors.red;

    final marketCap = _overviewData['marketCap'] ?? '';
    final peRatio = _overviewData['peRatio'] ?? '';
    final fiftyTwoHigh = _overviewData['fiftyTwoWeekHigh'] ?? '';
    final description = _overviewData['description'] ?? '';

    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price line
          Row(
            children: [
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 10),
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
                style: TextStyle(color: color),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Basic fundamentals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Market Cap', style: TextStyle(color: Colors.white70)),
              Text(marketCap.isEmpty ? '-' : marketCap, style: TextStyle(color: Colors.white)),
              Text('P/E Ratio', style: TextStyle(color: Colors.white70)),
              Text(peRatio.isEmpty ? '-' : peRatio, style: TextStyle(color: Colors.white)),
              Text('52W High', style: TextStyle(color: Colors.white70)),
              Text(fiftyTwoHigh.isEmpty ? '-' : fiftyTwoHigh, style: TextStyle(color: Colors.white)),
            ],
          ),
          SizedBox(height: 10),
          // Description
          Text(
            description,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Local calls to alpha vantage for this widget
  Future<Map<String, dynamic>> _fetchGlobalQuote(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$alphaVantageApiKey',
    );
    Map<String, dynamic> res = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final q = data['Global Quote'] ?? {};
        if (q.isNotEmpty) {
          double price = double.tryParse(q['05. price'] ?? '') ?? 0.0;
          double change = double.tryParse(q['09. change'] ?? '') ?? 0.0;
          double pct = 0.0;
          if ((q['10. change percent'] ?? '').contains('%')) {
            pct = double.tryParse((q['10. change percent'] ?? '').replaceAll('%', '')) ?? 0.0;
          }
          res = {
            'price': price,
            'change': change,
            'changePct': pct,
          };
        }
      }
    } catch (e) {
      print('Error in _SymbolCard.fetchGlobalQuote: $e');
    }
    return res;
  }

  Future<Map<String, dynamic>> _fetchOverview(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=OVERVIEW&symbol=$symbol&apikey=$alphaVantageApiKey',
    );
    Map<String, dynamic> res = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data.isNotEmpty && data['Symbol'] != null) {
          res = {
            'marketCap': data['MarketCapitalization'] ?? '',
            'peRatio': data['PERatio'] ?? '',
            'fiftyTwoWeekHigh': data['52WeekHigh'] ?? '',
            'description': data['Description'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error in _SymbolCard.fetchOverview: $e');
    }
    return res;
  }
}
