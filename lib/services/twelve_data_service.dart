import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_data.dart';

class TwelveDataService {
  static final String _apiKey = dotenv.env['TWELVE_DATA_API_KEY'] ?? '';

  /// Fetch updated data for a given symbol from Twelve Data.
  static Future<StockData?> fetchSymbolData(String symbol) async {
    final url = Uri.parse(
      'https://api.twelvedata.com/time_series?symbol=$symbol&interval=1min&outputsize=1&apikey=$_apiKey',
    );
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(resp.body);
        if (jsonMap.containsKey('values')) {
          final List values = jsonMap['values'];
          if (values.isNotEmpty) {
            final dataPoint = values.first;
            return StockData.fromTwelveDataJson({
              'symbol': symbol,
              'price': dataPoint['close'],
              'open': dataPoint['open'],
              'high': dataPoint['high'],
              'low': dataPoint['low'],
              'volume': dataPoint['volume'],
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching data for $symbol: $e');
    }
    return null;
  }

  /// Search for symbols using Twelve Data’s symbol search endpoint.
  static Future<List<StockData>> searchSymbol(String query) async {
    final url = Uri.parse(
      'https://api.twelvedata.com/symbol_search?symbol=$query&apikey=$_apiKey',
    );
    List<StockData> results = [];
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(resp.body);
        if (jsonMap.containsKey('data') && jsonMap['data'] is List) {
          for (var item in jsonMap['data']) {
            final symbol = item['symbol'] ?? '';
            final name = item['name'] ?? symbol;
            // Create a StockData instance with dummy values (to be updated later).
            results.add(StockData(
              symbol: symbol,
              name: name,
              currentPrice: 0,
              openPrice: 0,
              highPrice: 0,
              lowPrice: 0,
              volume: 0,
              absoluteChange: 0,
              percentChange: 0,
            ));
          }
        }
      }
    } catch (e) {
      print('Error searching symbol: $e');
    }
    return results;
  }
}
