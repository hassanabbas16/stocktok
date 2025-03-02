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
} 