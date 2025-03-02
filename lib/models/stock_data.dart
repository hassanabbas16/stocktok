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

  /// Create an instance from Polygon API JSON.
  factory StockData.fromPolygonJson(Map<String, dynamic> json) {
    final symbol = (json['T'] ?? '').toString();
    final open = (json['o'] ?? 0).toDouble();
    final close = (json['c'] ?? 0).toDouble();
    final high = (json['h'] ?? 0).toDouble();
    final low = (json['l'] ?? 0).toDouble();
    final volume = (json['v'] ?? 0).toInt();
    return StockData(
      symbol: symbol,
      name: symbol, // In production, you might map to a proper name.
      currentPrice: close,
      openPrice: open,
      highPrice: high,
      lowPrice: low,
      volume: volume,
      absoluteChange: 0,
      percentChange: 0,
    );
  }

  /// Create an instance from Twelve Data API JSON.
  factory StockData.fromTwelveDataJson(Map<String, dynamic> json) {
    final symbol = json['symbol'] ?? '';
    final price = double.tryParse(json['price'] ?? '0') ?? 0;
    final open = double.tryParse(json['open'] ?? '0') ?? 0;
    final high = double.tryParse(json['high'] ?? '0') ?? 0;
    final low = double.tryParse(json['low'] ?? '0') ?? 0;
    final volume = int.tryParse(json['volume'] ?? '0') ?? 0;
    return StockData(
      symbol: symbol,
      name: symbol,
      currentPrice: price,
      openPrice: open,
      highPrice: high,
      lowPrice: low,
      volume: volume,
      absoluteChange: price - open,
      percentChange: open != 0 ? ((price - open) / open) * 100 : 0,
    );
  }
}
