import 'dart:convert';
import 'package:http/http.dart' as http;

class AlphaVantageService {
  static const String _apiKey = 'VuAp8k6bioJUIuflawofK1jbfA0U1V9s';

  /// Fetch real-time quote data from Alpha Vantage (Global Quote)
  /// Returns a map like:
  /// {
  ///   '01. symbol': ...,
  ///   '02. open': ...,
  ///   '03. high': ...,
  ///   '04. low': ...,
  ///   '05. price': ...,
  ///   '09. change': ...,
  ///   '10. change percent': ...,
  ///   ...
  /// }
  static Future<Map<String, dynamic>?> fetchStockQuote(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quote = data['Global Quote'];
        if (quote != null && quote.isNotEmpty) {
          return quote as Map<String, dynamic>;
        } else {
          print('No quote found for $symbol');
        }
      } else {
        print('HTTP Error (Global Quote): ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data for $symbol: $e');
    }
    return null;
  }

  /// Fetches the "name" of the symbol via SYMBOL_SEARCH from Alpha Vantage.
  /// This returns JSON like:
  /// {
  ///   "bestMatches": [
  ///     {
  ///       "1. symbol": "TSLA",
  ///       "2. name": "Tesla Inc",
  ///       "3. type": "Equity",
  ///       ...
  ///     },
  ///     ...
  ///   ]
  /// }
  /// We'll pick the first match. If none, returns null.
  static Future<String?> fetchSymbolName(String symbol) async {
    final url = Uri.parse(
      'https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=$symbol&apikey=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['bestMatches'] != null &&
            data['bestMatches'] is List &&
            (data['bestMatches'] as List).isNotEmpty) {
          // Take the first match
          final first = data['bestMatches'][0];
          // The name is in key "2. name"
          final name = first['2. name'];
          return name?.toString();
        }
      } else {
        print('HTTP Error (Symbol Search): ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching name for $symbol: $e');
    }
    return null;
  }
}
