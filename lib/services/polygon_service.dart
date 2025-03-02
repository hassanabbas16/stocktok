import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_data.dart';

class PolygonService {
  static final String _apiKey = dotenv.env['POLYGON_API_KEY'] ?? '';

  /// Fetch grouped data for stocks (and ETFs) from the US market.
  static Future<Map<String, StockData>> fetchStocksData(String date) async {
    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/us/market/stocks/$date?adjusted=true&apiKey=$_apiKey',
    );
    final Map<String, StockData> data = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(resp.body);
        if (jsonMap['status'] == 'OK' && jsonMap['results'] is List) {
          for (final item in jsonMap['results']) {
            final stock = StockData.fromPolygonJson(item);
            if (stock.symbol.isNotEmpty) {
              data[stock.symbol] = stock;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching stocks data: $e');
    }
    return data;
  }

  /// Fetch grouped data for crypto from the global market.
  static Future<Map<String, StockData>> fetchCryptoData(String date) async {
    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/global/market/crypto/$date?apiKey=$_apiKey',
    );
    final Map<String, StockData> data = {};
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(resp.body);
        if (jsonMap['status'] == 'OK' && jsonMap['results'] is List) {
          for (final item in jsonMap['results']) {
            final stock = StockData.fromPolygonJson(item);
            if (stock.symbol.isNotEmpty) {
              data[stock.symbol] = stock;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching crypto data: $e');
    }
    return data;
  }
}
