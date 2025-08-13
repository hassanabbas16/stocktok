import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_data.dart';
import '../services/data_repository.dart';
import '../services/twelve_data_service.dart';
import '../services/stock_symbol_mapping.dart';
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
  Timer? _debounceTimer;
  int _searchCounter = 0; // To track search requests and cancel outdated ones

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

  /// Called on typing inside the search field with debouncing to prevent race conditions.
  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Set a new timer with 300ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// Called on typing inside the search field.
  Future<void> _performSearch(String query) async {
    final currentSearchId = ++_searchCounter;
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    // If query is empty, show the full polygon cache.
    if (query.trim().isEmpty) {
      if (currentSearchId == _searchCounter && mounted) {
        setState(() {
          _searchResults = dataRepo.polygonCache.values.toList();
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final q = query.trim().toLowerCase();
    
    // 1) Try to find exact company name mapping first
    final exactMappedSymbol = StockSymbolMapping.getSymbolFromCompanyName(q);
    
    // 2) Get partial matches for company names
    final partialMappedSymbols = StockSymbolMapping.searchSymbolsByCompanyName(q);
    
    // 3) Combine all mapped symbols
    final allMappedSymbols = <String>{};
    if (exactMappedSymbol != null) {
      allMappedSymbols.add(exactMappedSymbol);
    }
    allMappedSymbols.addAll(partialMappedSymbols);
    
    // 4) Local matches from polygonCache by symbol, name, or mapped symbols
    final localMatches = dataRepo.polygonCache.values.where((s) {
      return s.symbol.toLowerCase().contains(q) || 
             s.name.toLowerCase().contains(q) ||
             allMappedSymbols.any((mapped) => s.symbol.toLowerCase() == mapped.toLowerCase());
    }).toList();
    List<StockData> finalResults = [...localMatches];

    // Check if this search is still the latest one
    if (currentSearchId != _searchCounter) return;

    // 5) Fetch any mapped symbols that aren't in local cache
    for (final mappedSymbol in allMappedSymbols) {
      if (currentSearchId != _searchCounter) return; // Check again before each API call
      if (!finalResults.any((s) => s.symbol.toLowerCase() == mappedSymbol.toLowerCase())) {
        final fetched = await TwelveDataService.fetchQuote(mappedSymbol);
        if (fetched != null && currentSearchId == _searchCounter) {
          dataRepo.updateSymbolData(fetched);
          finalResults.add(fetched);
        }
      }
    }

    // Check again before final API call
    if (currentSearchId != _searchCounter) return;

    // 6) Also try direct symbol fetch from TwelveData
    final fetched = await TwelveDataService.fetchQuote(query.trim().toUpperCase());
    if (fetched != null && currentSearchId == _searchCounter) {
      dataRepo.updateSymbolData(fetched);
      if (!finalResults.any((s) => s.symbol == fetched.symbol)) {
        finalResults.add(fetched);
      }
    }

    // Final check and update UI only if this is still the latest search
    if (currentSearchId == _searchCounter && mounted) {
      setState(() {
        _searchResults = finalResults;
        _isLoading = false;
      });
    }
  }

  /// Called when user toggles a watchlist checkbox.
  void _onCheckboxChanged(StockData stock) {
    setState(() {
      if (_tempWatchlist.contains(stock.symbol)) {
        _tempWatchlist.remove(stock.symbol);
      } else {
        _tempWatchlist.add(stock.symbol);
        // Auto-clear search box after adding a stock
        _searchController.clear();
        _performSearch('');
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
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = constraints.maxWidth;
        final minHorizontalPadding = 8.0;
        final maxHorizontalPadding = 32.0;
        final horizontalPadding = (width * 0.03).clamp(minHorizontalPadding, maxHorizontalPadding);
        
        // Search bar styling
        final searchBarHeight = 40.0;
        final minFontSize = 12.0;
        final maxFontSize = 18.0;
        // Make font size proportional to search bar height for better scaling
        final searchFontSize = (searchBarHeight * 0.35).clamp(minFontSize, maxFontSize);
        final searchIconSize = (searchBarHeight * 0.5).clamp(16.0, 24.0);
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Container(
              height: searchBarHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: searchFontSize,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search, 
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    size: searchIconSize,
                  ),
                  hintText: 'Search symbol or company name...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: searchFontSize,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: (searchBarHeight - searchFontSize) / 2 - 8,
                    horizontal: 12,
                  ),
                ),
                textInputAction: TextInputAction.search,
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
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                              tight: true,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              height: 1,
                              color: isDark ? Colors.grey[600] : Colors.grey[300],
                            ),
                          ],
                        );
                      },
                    ),
        );
      },
    );
  }
}
