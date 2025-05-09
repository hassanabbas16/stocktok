import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_data.dart';
import '../services/data_repository.dart';
import '../services/twelve_data_service.dart';
import '../widgets/search_result_card.dart';

class SearchPage extends StatefulWidget {
  final bool forceSelection;

  const SearchPage({Key? key, required this.forceSelection}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<String> _tempWatchlist = [];
  // This list will show all stocks/crypto fetched from Polygon.
  List<StockData> _searchResults = [];

  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;
  bool _watchlistModified = false;

  @override
  void initState() {
    super.initState();
    _loadUserWatchlist();

    // Show all stocks/crypto from the complete polygon cache.
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    _searchResults = dataRepo.polygonCache.values.toList();
  }

  /// Load existing watchlist from Firestore so we know which symbols are checked.
  Future<void> _loadUserWatchlist() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;

      final List<dynamic>? symbols = data['selectedTickerSymbols'] as List<dynamic>?;
      if (symbols != null) {
        setState(() => _tempWatchlist = symbols.map((e) => e.toString()).toList());
      }
    } catch (_) {}
  }

  /// Save updated watchlist back to Firestore.
  Future<void> _saveWatchlist() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'selectedTickerSymbols': _tempWatchlist,
    }, SetOptions(merge: true));
  }

  /// Called on typing inside the search field.
  Future<void> _performSearch(String query) async {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    // If query is empty, show the full polygon cache.
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = dataRepo.polygonCache.values.toList();
      });
      return;
    }

    setState(() => _isLoading = true);

    // 1) Local matches from polygonCache.
    final localMatches = dataRepo.searchSymbols(query.trim());
    List<StockData> finalResults = [...localMatches];

    // 2) Also fetch from TwelveData to see if a single ticker quote can be found.
    final fetched = await TwelveDataService.fetchQuote(query.trim().toUpperCase());
    if (fetched != null) {
      dataRepo.updateSymbolData(fetched);
      if (!finalResults.any((s) => s.symbol == fetched.symbol)) {
        finalResults.add(fetched);
      }
    }

    setState(() {
      _searchResults = finalResults;
      _isLoading = false;
    });
  }

  /// Called when user toggles a watchlist checkbox.
  void _onCheckboxChanged(StockData stock) {
    setState(() {
      _watchlistModified = true;
      if (_tempWatchlist.contains(stock.symbol)) {
        _tempWatchlist.remove(stock.symbol);
      } else {
        _tempWatchlist.add(stock.symbol);
      }
    });
  }

  /// Called when user taps the AppBar check icon.
  Future<void> _onDone() async {
    if (widget.forceSelection && _tempWatchlist.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 symbols')),
      );
      return;
    }
    await _saveWatchlist();
    // Return the updated watchlist to be merged on the main page.
    Navigator.pop(context, _tempWatchlist);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          alignment: Alignment.center,
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
            onChanged: _performSearch,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: width * 0.04,
            ),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search symbol...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _onDone,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
          ? const Center(child: Text('No results found.'))
          : ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) {
          final stock = _searchResults[i];
          final isChecked = _tempWatchlist.contains(stock.symbol);
          return Column(
            children: [
              SearchResultCard(
                stock: stock,
                isChecked: isChecked,
                onCheckboxChanged: () => _onCheckboxChanged(stock),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                color: isDark ? Colors.grey[600] : Colors.grey[300],
              ),
            ],
          );
        },
      ),
    );
  }
}
