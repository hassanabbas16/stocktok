class StockData {
  final String symbol;
  final String name;
  final double currentPrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int volume;
  final double absoluteChange;
  final double percentChange;

  StockData({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.absoluteChange,
    required this.percentChange,
  });

  /// Constructs [StockData] from Polygon’s grouped daily endpoint response item.
  ///
  /// Sample Polygon JSON structure (one “result”):
  /// ```json
  /// {
  ///   "T": "AAPL",
  ///   "v": 56796200,
  ///   "o": 236.95,
  ///   "c": 241.84,
  ///   "h": 242.089996,
  ///   "l": 230.2,
  ///   "t": 1740603600000,
  ///   "n": 10009
  /// }
  /// ```
  factory StockData.fromPolygonJson(Map<String, dynamic> json) {
    final symbol = (json['T'] ?? '').toString();
    final open   = (json['o'] ?? 0).toDouble();
    final close  = (json['c'] ?? 0).toDouble();
    final high   = (json['h'] ?? 0).toDouble();
    final low    = (json['l'] ?? 0).toDouble();
    final vol    = (json['v'] ?? 0).toDouble();

    // Polygon doesn't return company/crypto name here, so you could store
    // the symbol again as name, or use a separate lookup table.
    return StockData(
      symbol: symbol,
      name: symbol,
      currentPrice: close,
      openPrice: open,
      highPrice: high,
      lowPrice: low,
      volume: vol.toInt(),
      // By default, from a single day's polygon call alone, we don’t have
      // change or percentChange. You’ll calculate them later if needed.
      absoluteChange: 0,
      percentChange: 0,
    );
  }

  /// Constructs [StockData] from Twelve Data’s quote endpoint response.
  ///
  /// Sample Twelve Data JSON structure:
  /// ```json
  /// {
  ///   "symbol": "AAPL",
  ///   "name": "Apple Inc.",
  ///   "open": "236.95000",
  ///   "high": "242.089996",
  ///   "low": "230.20000",
  ///   "close": "241.84000",
  ///   "previous_close": "237.30000",
  ///   "change": "4.53999",
  ///   "percent_change": "1.91319",
  ///   "volume": "56796200",
  ///   ...
  /// }
  /// ```
  factory StockData.fromTwelveDataJson(Map<String, dynamic> json) {
    final symbol   = (json['symbol'] ?? '').toString();
    final name     = (json['name'] ?? symbol).toString();
    final openStr  = json['open']?.toString() ?? '0';
    final highStr  = json['high']?.toString() ?? '0';
    final lowStr   = json['low']?.toString() ?? '0';
    final closeStr = json['close']?.toString() ?? '0';
    final volStr   = json['volume']?.toString() ?? '0';
    final changeStr = json['change']?.toString() ?? '0';
    final pctChangeStr = json['percent_change']?.toString() ?? '0';

    final open   = double.tryParse(openStr) ?? 0;
    final high   = double.tryParse(highStr) ?? 0;
    final low    = double.tryParse(lowStr) ?? 0;
    final close  = double.tryParse(closeStr) ?? 0;
    final volume = int.tryParse(volStr) ?? 0;
    final change = double.tryParse(changeStr) ?? 0;
    final percentChange = double.tryParse(pctChangeStr) ?? 0;

    return StockData(
      symbol: symbol,
      name: name,
      currentPrice: close,
      openPrice: open,
      highPrice: high,
      lowPrice: low,
      volume: volume,
      absoluteChange: change,
      percentChange: percentChange,
    );
  }
}
