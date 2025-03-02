import 'package:flutter/material.dart';
import '../models/stock_data.dart';
import '../services/twelve_data_service.dart';
import '../widgets/stock_card.dart';

class SearchPage extends StatefulWidget {
  final List<StockData> cachedStocks;
  const SearchPage({Key? key, required this.cachedStocks}) : super(key: key);
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<StockData> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    // Get cached results that match the query.
    List<StockData> cached = widget.cachedStocks.where((stock) {
      return stock.symbol.toLowerCase().contains(query.toLowerCase()) ||
          stock.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    // Search Twelve Data API for additional results.
    List<StockData> apiResults = await TwelveDataService.searchSymbol(query);
    setState(() {
      _searchResults = [...cached, ...apiResults];
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Stocks'),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search symbol...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          _isSearching ? LinearProgressIndicator() : Container(),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(child: Text('No results found.'))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final stock = _searchResults[index];
                return StockCard(
                  stock: stock,
                  showFilters: {
                    'showSymbol': true,
                    'showName': true,
                    'showPrice': true,
                    'showPercentChange': true,
                    'showAbsoluteChange': false,
                    'showVolume': false,
                    'showOpeningPrice': false,
                    'showDailyHighLow': false,
                  },
                  separator: ' | ',
                  onToggle: () {
                    // Handle adding to watchlist.
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
