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
  final bool tight;

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
    this.tight = false,
  }) : super(key: key);

  @override
  State<WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends State<WatchlistCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final minFontSize = widget.tight ? 16.0 : 14.0;
        final maxFontSize = widget.tight ? 24.0 : 22.0;
        final nameFontSize = (width * 0.045).clamp(minFontSize, maxFontSize);
        final symbolFontSize = (width * 0.05).clamp(minFontSize, maxFontSize + 2);
        final priceFontSize = (width * 0.05).clamp(minFontSize, maxFontSize + 2);
        final changeFontSize = (width * 0.037).clamp(minFontSize - 2, maxFontSize);
        final padding = widget.tight ? (width * 0.02).clamp(6.0, 16.0) : (width * 0.04).clamp(12.0, 32.0);
        final extraItemFontSize = (width * 0.04).clamp(minFontSize - 2, maxFontSize);
        final extraItemLabelFontSize = (width * 0.04).clamp(minFontSize - 2, maxFontSize);
        final color = (widget.stock.absoluteChange >= 0) ? Colors.green : Colors.red;

        Widget topRow = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showName)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.70,
                          ),
                          child: Text(
                            widget.stock.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: nameFontSize,
                            ),
                          ),
                        );
                      },
                    ),
                  if (widget.showSymbol)
                    Text(
                      widget.stock.symbol,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: symbolFontSize,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.showPrice)
                  Text(
                    '\$${widget.stock.currentPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (widget.showAbsoluteChange || widget.showPercentChange)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showAbsoluteChange)
                        Text(
                          '${widget.stock.absoluteChange >= 0 ? '+' : ''}${widget.stock.absoluteChange.toStringAsFixed(2)} ',
                          style: TextStyle(color: color, fontSize: changeFontSize),
                        ),
                      if (widget.showPercentChange)
                        Text(
                          '(${widget.stock.percentChange >= 0 ? '+' : ''}${widget.stock.percentChange.toStringAsFixed(2)}%)',
                          style: TextStyle(color: color, fontSize: changeFontSize),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        );

        Widget? expandedRow;
        if (_isExpanded) {
          List<Widget> extraItems = [];
          if (widget.showVolume) {
            extraItems.add(_buildExtraItem('Vol', widget.stock.volume.toString(), extraItemLabelFontSize, extraItemFontSize));
          }
          if (widget.showOpeningPrice) {
            extraItems.add(_buildExtraItem('Open', '\$${widget.stock.openPrice.toStringAsFixed(2)}', extraItemLabelFontSize, extraItemFontSize));
          }
          if (widget.showDailyHighLow) {
            extraItems.add(
              _buildExtraItem(
                'H/L',
                '\$${widget.stock.highPrice.toStringAsFixed(2)} / \$${widget.stock.lowPrice.toStringAsFixed(2)}',
                extraItemLabelFontSize, extraItemFontSize,
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
            color: Colors.transparent,
            padding: EdgeInsets.all(padding),
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
      },
    );
  }

  Widget _buildExtraItem(String label, String value, double labelFontSize, double valueFontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: labelFontSize,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: valueFontSize,
          ),
        ),
      ],
    );
  }
}
