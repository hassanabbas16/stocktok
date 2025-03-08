import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class SearchResultCard extends StatefulWidget {
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
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    final stock = widget.stock;
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;

    // Top row: symbol/name on left, price + changes on right
    Widget topRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: symbol & name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stock.symbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: width * 0.045,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: width * 0.01),
            Text(
              stock.name,
              style: TextStyle(
                fontSize: width * 0.035,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),

        // Right side: price & changes
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${stock.currentPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: width * 0.045,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stock.absoluteChange >= 0 ? '+' : ''}'
                      '${stock.absoluteChange.toStringAsFixed(2)} ',
                  style: TextStyle(color: color, fontSize: width * 0.032),
                ),
                Text(
                  '(${stock.percentChange >= 0 ? '+' : ''}'
                      '${stock.percentChange.toStringAsFixed(2)}%)',
                  style: TextStyle(color: color, fontSize: width * 0.032),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    // Expanded content: volume, open, H/L + "Add to Watchlist" row
    Widget? expandedRow;
    if (_isExpanded) {
      // Build three items for volume, open, high/low
      List<Widget> extraItems = [];
      extraItems.add(_buildExtraItem('Vol', stock.volume.toString()));
      extraItems.add(_buildExtraItem('Open', '\$${stock.openPrice.toStringAsFixed(2)}'));
      extraItems.add(_buildExtraItem(
        'H/L',
        '\$${stock.highPrice.toStringAsFixed(2)} / \$${stock.lowPrice.toStringAsFixed(2)}',
      ));

      expandedRow = Column(
        children: [
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: extraItems,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: widget.isChecked,
                onChanged: (_) => widget.onCheckboxChanged(),
              ),
              Text(
                'Add to Watchlist',
                style: TextStyle(
                  fontSize: width * 0.037,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        color: Colors.transparent,
        width: double.infinity,
        padding: EdgeInsets.all(width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topRow,
            if (expandedRow != null) ...[
              const SizedBox(height: 8),
              Center(child: expandedRow),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtraItem(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: width * 0.035,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: width * 0.035,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
