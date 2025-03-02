import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock_data.dart';

class PolygonService {
  static final String _polygonApiKey = dotenv.env['POLYGON_API_KEY'] ?? '';

  /// Fetch grouped daily aggregates for stocks/ETFs/indices (locale=us, market=stocks)
  /// or crypto (locale=global, market=crypto) for the specified date (YYYY-MM-DD).
  /// Returns a map from symbol -> StockData (with no change calculation).
  static Future<Map<String, StockData>> fetchGroupedData({
    required String dateStr,
    required bool isCrypto,
  }) async {
    final String market = isCrypto ? 'crypto' : 'stocks';
    final String locale = isCrypto ? 'global' : 'us';

    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/$locale/market/$market/$dateStr'
          '?adjusted=true&apiKey=$_polygonApiKey',
    );

    final Map<String, StockData> resultsMap = {};

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded['status'] == 'OK' && decoded['results'] is List) {
          for (final item in decoded['results']) {
            final symbol = (item['T'] ?? '').toString();
            if (symbol.isEmpty) continue;

            final open  = (item['o'] ?? 0).toDouble();
            final close = (item['c'] ?? 0).toDouble();
            final high  = (item['h'] ?? 0).toDouble();
            final low   = (item['l'] ?? 0).toDouble();
            final vol   = (item['v'] ?? 0).toDouble();

            // For a first pass, just store symbol as name
            final stock = StockData(
              symbol: symbol,
              name: symbol,
              currentPrice: close,
              openPrice: open,
              highPrice: high,
              lowPrice: low,
              volume: vol.toInt(),
              absoluteChange: 0,
              percentChange: 0,
            );
            resultsMap[symbol] = stock;
          }
        }
      }
    } catch (e) {
      // Handle error
    }
    return resultsMap;
  }
}
