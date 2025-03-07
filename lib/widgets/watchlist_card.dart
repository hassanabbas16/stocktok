import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class WatchlistCard extends StatefulWidget {
  final StockData stock;

  // Filter toggles
  final bool showSymbol;
  final bool showName;
  final bool showPrice;
  final bool showPercentChange;
  final bool showAbsoluteChange;
  final bool showVolume;
  final bool showOpeningPrice;
  final bool showDailyHighLow;

  final bool isChecked; // we won’t display a checkbox, but kept for logic
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
  State<WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends State<WatchlistCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final color = (widget.stock.absoluteChange >= 0) ? Colors.green : Colors.red;

    // Top row: name/symbol on the left, price + changes on the right
    Widget topRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: name + symbol
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showName)
              Text(
                widget.stock.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            if (widget.showSymbol)
              Text(
                widget.stock.symbol,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
          ],
        ),

        // Right side: price & changes
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.showPrice)
              Text(
                '\$${widget.stock.currentPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (widget.showAbsoluteChange || widget.showPercentChange)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showAbsoluteChange)
                    Text(
                      '${widget.stock.absoluteChange >= 0 ? '+' : ''}'
                          '${widget.stock.absoluteChange.toStringAsFixed(2)} ',
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                  if (widget.showPercentChange)
                    Text(
                      '(${widget.stock.percentChange >= 0 ? '+' : ''}'
                          '${widget.stock.percentChange.toStringAsFixed(2)}%)',
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                ],
              ),
          ],
        ),
      ],
    );

    // Expanded row: only if toggles and user taps
    Widget? expandedRow;
    if (_isExpanded) {
      List<Widget> extraItems = [];
      if (widget.showVolume) {
        extraItems.add(_buildExtraItem('Vol', widget.stock.volume.toString()));
      }
      if (widget.showOpeningPrice) {
        extraItems.add(_buildExtraItem('Open', '\$${widget.stock.openPrice.toStringAsFixed(2)}'));
      }
      if (widget.showDailyHighLow) {
        extraItems.add(
          _buildExtraItem(
            'H/L',
            '\$${widget.stock.highPrice.toStringAsFixed(2)} / \$${widget.stock.lowPrice.toStringAsFixed(2)}',
          ),
        );
      }

      if (extraItems.isNotEmpty) {
        expandedRow = Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: extraItems,
          ),
        );
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        color: Colors.transparent, // no card bg color
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topRow,
            if (expandedRow != null)
              Center(
                child: expandedRow,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
