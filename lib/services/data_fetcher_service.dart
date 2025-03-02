import 'dart:async';
import '../models/stock_data.dart';
import 'polygon_service.dart';
import 'twelve_data_service.dart';

class DataFetcherService {
  // Limit to 500 symbols per minute.
  static const int rateLimit = 500;

  /// Fetch initial data from Polygon (stocks/ETFs/crypto for today and yesterday),
  /// then update using Twelve Data API.
  static Future<Map<String, StockData>> fetchInitialData({
    required String today,
    required String yesterday,
  }) async {
    Map<String, StockData> combinedData = {};

    // Fetch polygon data concurrently.
    final results = await Future.wait([
      PolygonService.fetchStocksData(today),
      PolygonService.fetchStocksData(yesterday),
      PolygonService.fetchCryptoData(today),
      PolygonService.fetchCryptoData(yesterday),
    ]);

    for (var data in results) {
      combinedData.addAll(data);
    }

    // Update each symbol’s data using Twelve Data API (throttled).
    List<String> symbols = combinedData.keys.toList();
    for (int i = 0; i < symbols.length; i += rateLimit) {
      final batch = symbols.sublist(
        i,
        (i + rateLimit) > symbols.length ? symbols.length : i + rateLimit,
      );
      await Future.wait(batch.map((symbol) async {
        final updatedData = await TwelveDataService.fetchSymbolData(symbol);
        if (updatedData != null) {
          combinedData[symbol] = updatedData;
        }
      }));
      // Wait one minute if there are more symbols.
      if (i + rateLimit < symbols.length) {
        await Future.delayed(Duration(minutes: 1));
      }
    }
    return combinedData;
  }

  /// Update ticker (watchlist) data every minute using Twelve Data API.
  static Future<Map<String, StockData>> updateTickerData(List<String> symbols) async {
    Map<String, StockData> updatedData = {};
    await Future.wait(symbols.map((symbol) async {
      final data = await TwelveDataService.fetchSymbolData(symbol);
      if (data != null) {
        updatedData[symbol] = data;
      }
    }));
    return updatedData;
  }
}
