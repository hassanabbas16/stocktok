import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_data.dart';
import '../services/data_repository.dart';
import '../services/twelve_data_service.dart';
import '../widgets/search_result_card.dart';
import 'main_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserWatchlist();
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
      if (symbols == null) return;

      setState(() {
        _tempWatchlist = symbols.map((e) => e.toString()).toList();
      });
    } catch (e) {
      // handle error
    }
  }

  /// Save watchlist to Firestore
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

  /// Perform search:
  /// 1. Attempt local DataRepository search
  /// 2. If not found or user wants direct symbol, fetch from TwelveData
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }
    setState(() => _isLoading = true);

    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    final localMatches = dataRepo.searchSymbols(query.trim());
    List<StockData> finalResults = [...localMatches];

    // If local matches are empty or user typed an exact symbol not in local
    // we can fetch from 12data
    // For demonstration, let's always try 12data for exact symbol if local is missing
    if (localMatches.isEmpty) {
      final fetched = await TwelveDataService.fetchQuote(query.trim().toUpperCase());
      if (fetched != null) {
        // Also update the repository
        dataRepo.updateSymbolData(fetched);
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
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          onChanged: (val) => _performSearch(val),
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
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: _onDone,
            icon: const Icon(Icons.check, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
          ? const Center(child: Text('No results yet. Type to search.'))
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
