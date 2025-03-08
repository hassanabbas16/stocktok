import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock_data.dart';

/// A custom exception to signal 403 errors so we can handle them gracefully.
class PolygonForbiddenException implements Exception {
  final String message;
  PolygonForbiddenException(this.message);

  @override
  String toString() => 'PolygonForbiddenException: $message';
}

class PolygonService {
  static final String _polygonApiKey = dotenv.env['POLYGON_API_KEY'] ?? '';

  /// This fetches data for day1 & day2 (both stocks + crypto), calculates
  /// absolute & percent changes, merges them, and returns a map of symbols->StockData.
  ///
  /// If a 403 is encountered, day1/day2 are each pushed back 1 day, and we retry
  /// recursively until we succeed or exceed [maxRetries].
  static Future<Map<String, StockData>> fetchTwoDaysCombined({
    required String day1,
    required String day2,
    int attempts = 0,        // how many times we've retried so far
    int maxRetries = 5,      // maximum attempts to avoid infinite loops
  }) async {
    // If we've exceeded maxRetries, just return empty or throw.
    if (attempts >= maxRetries) {
      print('--- fetchTwoDaysCombined: exceeded max retries; returning empty.');
      return {};
    }

    print('--- fetchTwoDaysCombined($day1, $day2), attempt $attempts ...');

    try {
      final Map<String, StockData> combined = {};

      // 1) Stocks day1/day2
      final day1stocks = await _fetchGroupedData(dateStr: day1, isCrypto: false);
      final day2stocks = await _fetchGroupedData(dateStr: day2, isCrypto: false);

      for (final sym in day2stocks.keys) {
        final d2 = day2stocks[sym]!;
        final d1 = day1stocks[sym];
        final prevClose = d1?.currentPrice ?? 0;
        final close = d2.currentPrice;
        final absChange = close - prevClose;
        double pct = 0;
        if (prevClose != 0) {
          pct = (absChange / prevClose) * 100;
        }

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

      // 2) Crypto day1/day2
      final day1crypto = await _fetchGroupedData(dateStr: day1, isCrypto: true);
      final day2crypto = await _fetchGroupedData(dateStr: day2, isCrypto: true);

      for (final sym in day2crypto.keys) {
        final d2 = day2crypto[sym]!;
        final d1 = day1crypto[sym];
        final prevClose = d1?.currentPrice ?? 0;
        final close = d2.currentPrice;
        final absChange = close - prevClose;
        double pct = 0;
        if (prevClose != 0) {
          pct = (absChange / prevClose) * 100;
        }

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

      print('--- fetchTwoDaysCombined($day1, $day2) => total ${combined.length} symbols.\n');
      return combined;

    } catch (e) {
      // If we caught a 403 from ANY of the four fetches above, we do a rollback
      if (e is PolygonForbiddenException) {
        print('--- [403] encountered, rolling back day1/day2 by 1 day and retrying...');
        final newDay1 = _decrementDateString(day1);
        final newDay2 = _decrementDateString(day2);
        return fetchTwoDaysCombined(
          day1: newDay1,
          day2: newDay2,
          attempts: attempts + 1,
          maxRetries: maxRetries,
        );
      }
      // Otherwise rethrow
      rethrow;
    }
  }

  /// Private helper that fetches grouped data for a single day (stocks or crypto).
  /// Throws PolygonForbiddenException if statusCode==403, so we can handle it.
  static Future<Map<String, StockData>> _fetchGroupedData({
    required String dateStr,
    required bool isCrypto,
  }) async {
    final market = isCrypto ? 'crypto' : 'stocks';
    final locale = isCrypto ? 'global' : 'us';

    // Just to confirm the key is correct:
    print('*** Using Polygon key = $_polygonApiKey ***');

    final url = Uri.parse(
      'https://api.polygon.io/v2/aggs/grouped/locale/$locale/market/$market/$dateStr'
          '?adjusted=true&apiKey=$_polygonApiKey',
    );
    print('--- _fetchGroupedData => GET $url');

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
          print('--- _fetchGroupedData($dateStr, isCrypto=$isCrypto): got ${results.length} symbols.');
        } else {
          print('--- _fetchGroupedData($dateStr, isCrypto=$isCrypto): no valid "results" in JSON, raw response: ${resp.body}');
        }
      } else {
        // If 403 => we throw so that fetchTwoDaysCombined can handle it
        if (resp.statusCode == 403) {
          throw PolygonForbiddenException('HTTP 403 from $url \n Body: ${resp.body}');
        }
        print('--- _fetchGroupedData($dateStr, isCrypto=$isCrypto): HTTP ${resp.statusCode}, body:\n${resp.body}\n');
      }
    } catch (e) {
      print('--- _fetchGroupedData($dateStr, isCrypto=$isCrypto): error $e');
      rethrow; // rethrow so the caller can handle it
    }

    return results;
  }

  /// Convert "X:BTCUSD" -> "BTC/USD"
  static String _mapPolygonCryptoSymbol(String polySym) {
    if (!polySym.startsWith('X:')) {
      return polySym; // not polygon crypto
    }
    final raw = polySym.substring(2); // e.g. "BTCUSD"
    if (raw.length <= 3) {
      return raw;
    }
    // e.g. "BTCUSD" => "BTC/USD"
    final base = raw.substring(0, raw.length - 3);
    final quote = raw.substring(raw.length - 3);
    return '$base/$quote';
  }

  /// Decrement a date string like '2025-03-07' by 1 day => '2025-03-06'
  static String _decrementDateString(String dateStr) {
    final parts = dateStr.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final original = DateTime(y, m, d);
    final rolledBack = original.subtract(const Duration(days: 1));
    final ny = rolledBack.year;
    final nm = rolledBack.month.toString().padLeft(2, '0');
    final nd = rolledBack.day.toString().padLeft(2, '0');
    return '$ny-$nm-$nd';
  }
}
