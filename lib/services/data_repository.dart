import 'package:flutter/foundation.dart';
import '../models/stock_data.dart';

class DataRepository extends ChangeNotifier {
  /// All symbols from polygon
  final Map<String, StockData> _polygonCache = {};

  bool _darkMode = false;
  bool get darkMode => _darkMode;
  set darkMode(bool val) {
    _darkMode = val;
    notifyListeners();
  }

  Map<String, StockData> get polygonCache => _polygonCache;

  void addPolygonData(Map<String, StockData> data) {
    for (final entry in data.entries) {
      _polygonCache[entry.key] = entry.value;
    }
    notifyListeners();
  }

  void updateSymbolData(StockData newData) {
    _polygonCache[newData.symbol] = newData;
    notifyListeners();
  }

  StockData? getSymbolData(String symbol) {
    return _polygonCache[symbol];
  }

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
