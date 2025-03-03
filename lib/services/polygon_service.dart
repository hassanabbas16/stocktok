import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock_data.dart';

class PolygonService {
  static final String _polygonApiKey = dotenv.env['POLYGON_API_KEY'] ?? '';

  /// Example usage:
  ///   final combined = await PolygonService.fetchTwoDaysCombined(
  ///       day1: "2025-03-01",
  ///       day2: "2025-03-02");
  static Future<Map<String, StockData>> fetchTwoDaysCombined({
    required String day1,
    required String day2,
  }) async {
    final Map<String, StockData> combined = {};

    // Stocks day1/day2
    final day1stocks = await _fetchGroupedData(dateStr: day1, isCrypto: false);
    final day2stocks = await _fetchGroupedData(dateStr: day2, isCrypto: false);

    for (final sym in day2stocks.keys) {
      final d2 = day2stocks[sym]!;
      final d1 = day1stocks[sym];
      final prevClose = d1?.currentPrice ?? 0;
      final close = d2.currentPrice;
      final absChange = close - prevClose;
      double pct = 0;
      if (prevClose != 0) pct = (absChange / prevClose) * 100;

      combined[sym] = StockData(
        symbol: d2.symbol,
        name: d2.name,
        currentPrice: close,
        openPrice: d2.openPrice,
        highPrice: d2.highPrice,
        lowPrice: d2.lowPrice,
        volume: d2.volume,
        absoluteChange: absChange,
        percentChange: pct,
      );
    }

    // Crypto day1/day2
    final day1crypto = await _fetchGroupedData(dateStr: day1, isCrypto: true);
    final day2crypto = await _fetchGroupedData(dateStr: day2, isCrypto: true);

    for (final sym in day2crypto.keys) {
      final d2 = day2crypto[sym]!;
      final d1 = day1crypto[sym];
      final prevClose = d1?.currentPrice ?? 0;
      final close = d2.currentPrice;
      final absChange = close - prevClose;
      double pct = 0;
      if (prevClose != 0) pct = (absChange / prevClose) * 100;

      // Rename from "X:BTCUSD" to "BTC/USD"
      final renamed = _mapPolygonCryptoSymbol(sym);

      combined[renamed] = StockData(
        symbol: renamed,
        name: renamed,
        currentPrice: close,
        openPrice: d2.openPrice,
        highPrice: d2.highPrice,
        lowPrice: d2.lowPrice,
        volume: d2.volume,
        absoluteChange: absChange,
        percentChange: pct,
      );
    }

    return combined;
  }

  static Future<Map<String, StockData>> _fetchGroupedData({
    required String dateStr,
    required bool isCrypto,
  }) async {
    final market = isCrypto ? 'crypto' : 'stocks';
    final locale = isCrypto ? 'global' : 'us';
    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/$locale/market/$market/$dateStr'
          '?adjusted=true&apiKey=$_polygonApiKey',
    );

    final results = <String, StockData>{};

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is Map &&
            decoded['status'] == 'OK' &&
            decoded['results'] is List) {
          for (final item in decoded['results']) {
            final symbol = (item['T'] ?? '').toString();
            if (symbol.isEmpty) continue;
            final open  = (item['o'] ?? 0).toDouble();
            final close = (item['c'] ?? 0).toDouble();
            final high  = (item['h'] ?? 0).toDouble();
            final low   = (item['l'] ?? 0).toDouble();
            final vol   = (item['v'] ?? 0).toDouble();

            results[symbol] = StockData(
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
          }
        }
      }
    } catch (_) {
      // handle error
    }

    return results;
  }

  /// Convert "X:BTCUSD" -> "BTC/USD"
  static String _mapPolygonCryptoSymbol(String polySym) {
    if (!polySym.startsWith('X:')) {
      return polySym; // not a polygon crypto
    }
    // e.g. "X:BTCUSD"
    final raw = polySym.substring(2); // "BTCUSD"
    // We'll do a naive approach: if length >= 4, assume last 3 or 4 are fiat
    // Typically "BTCUSD", "ETHUSD", "BTCAUD", etc.
    if (raw.contains('/')) {
      // if user typed "BTC/AUD" or something
      return raw;
    }
    final len = raw.length;
    if (len <= 3) {
      return raw; // fallback
    }
    // e.g. "BTCUSD"
    final base = raw.substring(0, len - 3);
    final quote = raw.substring(len - 3);
    return '$base/$quote';
  }
}
