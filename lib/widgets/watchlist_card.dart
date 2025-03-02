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
  final bool isChecked;
  final VoidCallback onCheckboxChanged;

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
    required this.isChecked,
    required this.onCheckboxChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = stock.absoluteChange >= 0 ? Colors.green : Colors.red;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row: name & checkbox
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showName)
                  Text(
                    stock.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                Checkbox(
                  value: isChecked,
                  onChanged: (_) => onCheckboxChanged(),
                ),
              ],
            ),
            if (showSymbol)
              Text(
                stock.symbol,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            if (showPrice)
              Text(
                '\$${stock.currentPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (showAbsoluteChange || showPercentChange)
              Row(
                children: [
                  if (showAbsoluteChange)
                    Text(
                      '${stock.absoluteChange >= 0 ? '+' : ''}${stock.absoluteChange.toStringAsFixed(2)} ',
                      style: TextStyle(color: color, fontSize: 16),
                    ),
                  if (showPercentChange)
                    Text(
                      '(${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%)',
                      style: TextStyle(color: color, fontSize: 16),
                    ),
                ],
              ),
            if (showVolume)
              Text('Vol: ${stock.volume}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (showOpeningPrice)
              Text('Open: \$${stock.openPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (showDailyHighLow)
              Text(
                'H: \$${stock.highPrice.toStringAsFixed(2)}  L: \$${stock.lowPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
