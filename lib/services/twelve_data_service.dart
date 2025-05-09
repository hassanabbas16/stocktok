import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock_data.dart';

class TwelveDataService {
  static final String _twelveDataKey = dotenv.env['TWELVE_DATA_API_KEY'] ?? '';
  static const int _maxSymbolsPerMinute = 500;

  /// A simple queue of symbols to fetch from TwelveData
  static final Queue<String> _fetchQueue = Queue();

  /// Timer to process the queue
  static Timer? _timer;

  static final Map<String, StockData> _latestQuotes = {};

  static void initQueueProcessor() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _processQueueBatch();
    });
  }

  static void enqueueSymbol(String symbol) {
    if (!_fetchQueue.contains(symbol)) {
      _fetchQueue.add(symbol);
    }
  }

  static Future<void> _processQueueBatch() async {
    int batchCount = 0;
    while (_fetchQueue.isNotEmpty && batchCount < _maxSymbolsPerMinute) {
      final symbol = _fetchQueue.removeFirst();
      await _fetchAndStore(symbol);
      batchCount++;
    }
  }

  static Future<StockData?> fetchQuote(String symbol) async {
    final stock = await _fetchAndStore(symbol);
    return stock;
  }

  /// We figure out if it's a stock or a crypto pair, then call either
  /// the quote or time series endpoint accordingly.
  static Future<StockData?> _fetchAndStore(String symbol) async {
    try {
      // Simple approach: if symbol starts with X: => crypto
      // Also if it contains "/" => crypto pair
      // Otherwise stock
      final isCrypto = symbol.contains('/') || symbol.startsWith('X:');

      StockData? stock;
      if (isCrypto) {
        // Convert polygon-style "X:BTCUSD" -> "BTC/USD" or detect user typed "BTC/AUD"
        final mapped = _mapPolygonCryptoSymbolTo12Data(symbol);
        stock = await _fetchCryptoTimeSeries(mapped);
      } else {
        // It's presumably a stock / ETF
        stock = await _fetchStockQuote(symbol);
      }
      if (stock != null) {
        _latestQuotes[symbol] = stock;
        return stock;
      }
    } catch (e) {
      // handle error
    }
    return null;
  }

  /// Stock/ETF via quote endpoint
  static Future<StockData?> _fetchStockQuote(String symbol) async {
    final url = Uri.parse(
      'https://api.twelvedata.com/quote?symbol=$symbol&apikey=$_twelveDataKey',
    );
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('symbol')) {
        return _parseTwelveDataQuote(decoded);
      }
    }
    return null;
  }

  /// Crypto (or other pairs) via the time series endpoint
  /// We'll just fetch the last 2 data points and compute difference
  static Future<StockData?> _fetchCryptoTimeSeries(String pair) async {
    final url = Uri.parse(
      'https://api.twelvedata.com/time_series?symbol=$pair&interval=1day&outputsize=2&apikey=$_twelveDataKey',
    );
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);
      if (decoded is Map && decoded.containsKey('values') && decoded['values'] is List) {
        final List vals = decoded['values'];
        if (vals.isEmpty) return null;

        // The newest day is index 0
        final latest = vals[0];
        final open  = double.tryParse(latest['open'] ?? '') ?? 0;
        final high  = double.tryParse(latest['high'] ?? '') ?? 0;
        final low   = double.tryParse(latest['low'] ?? '') ?? 0;
        final close = double.tryParse(latest['close'] ?? '') ?? 0;
        int volume  = int.tryParse(latest['volume'] ?? '0') ?? 0;

        double prevClose = 0;
        if (vals.length > 1) {
          final prev = vals[1];
          prevClose = double.tryParse(prev['close'] ?? '') ?? 0;
        }
        double absChange = close - prevClose;
        double pctChange = 0;
        if (prevClose != 0) {
          pctChange = (absChange / prevClose) * 100;
        }

        return StockData(
          symbol: pair, // or keep original?
          name: pair,
          currentPrice: close,
          openPrice: open,
          highPrice: high,
          lowPrice: low,
          volume: volume,
          absoluteChange: absChange,
          percentChange: pctChange,
        );
      }
    }
    return null;
  }

  /// Attempt to map "X:BTCUSD" -> "BTC/USD"
  /// If user typed "BTC/AUD" we pass it as is.
  static String _mapPolygonCryptoSymbolTo12Data(String polySym) {
    if (polySym.contains('/')) {
      // user typed e.g. BTC/AUD => pass as is
      return polySym;
    }
    // e.g. "X:BTCUSD"
    if (polySym.startsWith('X:')) {
      final raw = polySym.substring(2); // "BTCUSD"
      // naive approach: assume the last 3 are the fiat. For "BTCUSD" => "BTC/USD"
      // or last 4 if it's e.g. "BTCAUD"? Up to you. This is simplistic:
      final len = raw.length;
      if (len > 3) {
        final base = raw.substring(0, len - 3);
        final quote = raw.substring(len - 3);
        return '$base/$quote';
      }
      // fallback
      return raw;
    }
    return polySym;
  }

  static StockData? _parseTwelveDataQuote(Map<String, dynamic> json) {
    try {
      final symbol = (json['symbol'] ?? '').toString();
      final name   = (json['name'] ?? symbol).toString();
      final open   = double.tryParse(json['open']?.toString() ?? '') ?? 0;
      final high   = double.tryParse(json['high']?.toString() ?? '') ?? 0;
      final low    = double.tryParse(json['low']?.toString() ?? '') ?? 0;
      final close  = double.tryParse(json['close']?.toString() ?? '') ?? 0;
      final prev   = double.tryParse(json['previous_close']?.toString() ?? '') ?? 0;
      final change = double.tryParse(json['change']?.toString() ?? '') ?? 0;
      final pct    = double.tryParse(json['percent_change']?.toString() ?? '') ?? 0;
      final vol    = int.tryParse(json['volume']?.toString() ?? '0') ?? 0;

      double absChange = change;
      double percentChange = pct;

      return StockData(
        symbol: symbol,
        name: name,
        currentPrice: close,
        openPrice: open,
        highPrice: high,
        lowPrice: low,
        volume: vol,
        absoluteChange: absChange,
        percentChange: percentChange,
      );
    } catch (_) {
      return null;
    }
  }

  static StockData? getCachedQuote(String symbol) {
    return _latestQuotes[symbol];
  }
}
