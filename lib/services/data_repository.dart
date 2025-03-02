import 'package:flutter/foundation.dart';
import '../models/stock_data.dart';

class DataRepository extends ChangeNotifier {
  /// All symbols from the initial Polygon calls (both stocks/ETFs/indices and crypto).
  /// Key: symbol, Value: StockData
  final Map<String, StockData> _polygonCache = {};

  /// Accessor for read-only
  Map<String, StockData> get polygonCache => _polygonCache;

  /// Update data from polygon (day0 + day1).
  void addPolygonData(Map<String, StockData> data) {
    for (final entry in data.entries) {
      _polygonCache[entry.key] = entry.value;
    }
    notifyListeners();
  }

  /// Update from TwelveData, merges new data with existing or adds new if not present.
  void updateSymbolData(StockData newData) {
    _polygonCache[newData.symbol] = newData;
    notifyListeners();
  }

  /// Syntactic sugar to retrieve a single symbol
  StockData? getSymbolData(String symbol) {
    return _polygonCache[symbol];
  }

  /// Return all symbols that partially match a query
  List<StockData> searchSymbols(String query) {
    if (query.isEmpty) {
      return _polygonCache.values.toList();
    }
    final lower = query.toLowerCase();
    return _polygonCache.values.where((stock) {
      return stock.symbol.toLowerCase().contains(lower)
          || stock.name.toLowerCase().contains(lower);
    }).toList();
  }
}
