import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class WatchlistCard extends StatelessWidget {
  final StockData stock;
  final bool showSymbol;
  final bool showName;
  final bool showPrice;
  final bool showPercentChange;
  final bool showAbsoluteChange;
  final bool showVolume;
  final bool showOpeningPrice;
  final bool showDailyHighLow;
  final VoidCallback onCheckboxChanged;
  final bool isChecked;

  const WatchlistCard({
    Key? key,
    required this.stock,
    required this.showSymbol,
    required this.showName,
    required this.showPrice,
    required this.showPercentChange,
    required this.showAbsoluteChange,
    required this.showVolume,
    required this.showOpeningPrice,
    required this.showDailyHighLow,
    required this.onCheckboxChanged,
    required this.isChecked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade100,
              stock.absoluteChange >= 0 ? Colors.green : Colors.red,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row with Title & checkbox
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showName)
                  Text(
                    stock.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Checkbox(
                  value: isChecked,
                  onChanged: (_) => onCheckboxChanged(),
                  activeColor: Colors.amber,
                ),
              ],
            ),
            if (showSymbol)
              Text(
                stock.symbol,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (showPrice)
              Text(
                '\$${stock.currentPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (showAbsoluteChange || showPercentChange)
              Row(
                children: [
                  if (showAbsoluteChange)
                    Text(
                      '${stock.absoluteChange >= 0 ? '+' : ''}'
                          '${stock.absoluteChange.toStringAsFixed(2)}  ',
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                      ),
                    ),
                  if (showPercentChange)
                    Text(
                      '${stock.percentChange >= 0 ? '+' : ''}'
                          '${stock.percentChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                      ),
                    ),
                ],
              ),
            if (showVolume)
              Text(
                'Vol: ${stock.volume}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (showOpeningPrice)
              Text(
                'Open: \$${stock.openPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (showDailyHighLow)
              Text(
                'H: \$${stock.highPrice.toStringAsFixed(2)}  '
                    'L: \$${stock.lowPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
