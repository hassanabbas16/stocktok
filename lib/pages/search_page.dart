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
  List<StockData> _searchResults = [];

  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;

  bool _watchlistModified = false;

  @override
  void initState() {
    super.initState();
    _loadUserWatchlist();

    // By default, show all polygon symbols
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    _searchResults = dataRepo.polygonCache.values.toList();
  }

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

  Future<void> _performSearch(String query) async {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = dataRepo.polygonCache.values.toList();
      });
      return;
    }

    setState(() => _isLoading = true);

    // local matches
    final localMatches = dataRepo.searchSymbols(query.trim());
    List<StockData> finalResults = [...localMatches];

    // also fetch from 12Data
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

  void _onCheckboxChanged(StockData stock) {
    setState(() {
      _watchlistModified = true; // user changed the watchlist
      if (_tempWatchlist.contains(stock.symbol)) {
        _tempWatchlist.remove(stock.symbol);
      } else {
        _tempWatchlist.add(stock.symbol);
      }
    });
  }

  Future<void> _onDone() async {
    if (widget.forceSelection && _tempWatchlist.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 symbols')),
      );
      return;
    }
    await _saveWatchlist();
    Navigator.pop(context, _watchlistModified);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _performSearch,
          decoration: const InputDecoration(
            hintText: 'Search symbol...',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
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
          return SearchResultCard(
            stock: stock,
            isChecked: isChecked,
            onCheckboxChanged: () => _onCheckboxChanged(stock),
          );
        },
      ),
    );
  }
}
