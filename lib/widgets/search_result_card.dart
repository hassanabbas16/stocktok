import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class SearchResultCard extends StatelessWidget {
  final StockData stock;
  final bool isChecked;
  final VoidCallback onCheckboxChanged;

  const SearchResultCard({
    Key? key,
    required this.stock,
    required this.isChecked,
    required this.onCheckboxChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          stock.symbol,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          stock.name,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        trailing: Checkbox(
          value: isChecked,
          onChanged: (_) => onCheckboxChanged(),
        ),
        leading: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\$${stock.currentPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stock.absoluteChange >= 0 ? '+' : ''}'
                      '${stock.absoluteChange.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${stock.percentChange >= 0 ? '+' : ''}'
                      '${stock.percentChange.toStringAsFixed(2)}%)',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
