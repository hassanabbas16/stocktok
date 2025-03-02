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

  /// You might store your latest data in a shared repository or in some map
  static final Map<String, StockData> _latestQuotes = {};

  /// Initialize the queue processor
  static void initQueueProcessor() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _processQueueBatch();
    });
  }

  /// Add a symbol to the queue
  static void enqueueSymbol(String symbol) {
    if (!_fetchQueue.contains(symbol)) {
      _fetchQueue.add(symbol);
    }
  }

  /// Process up to 500 symbols from the queue
  static Future<void> _processQueueBatch() async {
    int batchCount = 0;
    while (_fetchQueue.isNotEmpty && batchCount < _maxSymbolsPerMinute) {
      final symbol = _fetchQueue.removeFirst();
      await _fetchAndStoreQuote(symbol);
      batchCount++;
    }
  }

  /// Directly fetch and return the quote for a single symbol
  /// *But* also store it in _latestQuotes for future usage
  static Future<StockData?> fetchQuote(String symbol) async {
    final data = await _fetchAndStoreQuote(symbol);
    return data;
  }

  static Future<StockData?> _fetchAndStoreQuote(String symbol) async {
    try {
      final url = Uri.parse(
        'https://api.twelvedata.com/quote?symbol=$symbol&apikey=$_twelveDataKey',
      );
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);

        if (decoded is Map<String, dynamic> && decoded.containsKey('symbol')) {
          final stock = _parseTwelveDataQuote(decoded);
          if (stock != null) {
            _latestQuotes[symbol] = stock;
            return stock;
          }
        }
      }
    } catch (e) {
      // handle error
    }
    return null;
  }

  static StockData? _parseTwelveDataQuote(Map<String, dynamic> json) {
    try {
      final symbol = json['symbol'] as String;
      final name   = json['name'] ?? symbol;
      final open   = double.tryParse(json['open']?.toString() ?? '') ?? 0;
      final high   = double.tryParse(json['high']?.toString() ?? '') ?? 0;
      final low    = double.tryParse(json['low']?.toString() ?? '') ?? 0;
      final close  = double.tryParse(json['close']?.toString() ?? '') ?? 0;
      final prev   = double.tryParse(json['previous_close']?.toString() ?? '') ?? 0;
      final change = double.tryParse(json['change']?.toString() ?? '') ?? 0;
      final pct    = double.tryParse(json['percent_change']?.toString() ?? '') ?? 0;
      final vol    = int.tryParse(json['volume']?.toString() ?? '0') ?? 0;

      // If prev is 0, we can fallback to close - change for absolute
      final double absChange = change;
      final double percentChange = pct;

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

  /// Return the latest stored data for a symbol (if any)
  static StockData? getCachedQuote(String symbol) {
    return _latestQuotes[symbol];
  }
}
