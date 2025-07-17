import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class SearchResultCard extends StatefulWidget {
  final StockData stock;
  final bool isChecked;
  final VoidCallback onCheckboxChanged;
  final bool tight;

  const SearchResultCard({
    Key? key,
    required this.stock,
    required this.isChecked,
    required this.onCheckboxChanged,
    this.tight = false,
  }) : super(key: key);

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = constraints.maxWidth;
        final minFontSize = widget.tight ? 16.0 : 14.0;
        final maxFontSize = widget.tight ? 24.0 : 22.0;
        final symbolFontSize = (width * 0.05).clamp(minFontSize, maxFontSize + 2);
        final nameFontSize = (width * 0.04).clamp(minFontSize - 2, maxFontSize);
        final priceFontSize = (width * 0.05).clamp(minFontSize, maxFontSize + 2);
        final changeFontSize = (width * 0.037).clamp(minFontSize - 2, maxFontSize);
        final padding = widget.tight ? (width * 0.02).clamp(6.0, 16.0) : (width * 0.04).clamp(12.0, 32.0);
        final extraItemFontSize = (width * 0.04).clamp(minFontSize - 2, maxFontSize);
        final extraItemLabelFontSize = (width * 0.04).clamp(minFontSize - 2, maxFontSize);

        final stock = widget.stock;
        final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;

        Widget topRow = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: symbolFontSize,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: width * 0.01),
                  Text(
                    widget.stock.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: nameFontSize,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: width * 0.02),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${stock.currentPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stock.absoluteChange >= 0 ? '+' : ''}'
                            '${stock.absoluteChange.toStringAsFixed(2)} ',
                        style: TextStyle(color: color, fontSize: changeFontSize),
                      ),
                      Text(
                        '(${stock.percentChange >= 0 ? '+' : ''}'
                            '${stock.percentChange.toStringAsFixed(2)}%)',
                        style: TextStyle(color: color, fontSize: changeFontSize),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        Widget? expandedRow;
        if (_isExpanded) {
          List<Widget> extraItems = [];
          extraItems.add(_buildExtraItem('Vol', stock.volume.toString(), extraItemLabelFontSize, extraItemFontSize));
          extraItems.add(_buildExtraItem('Open', '\$${stock.openPrice.toStringAsFixed(2)}', extraItemLabelFontSize, extraItemFontSize));
          extraItems.add(_buildExtraItem(
            'H/L',
            '\$${stock.highPrice.toStringAsFixed(2)} / \$${stock.lowPrice.toStringAsFixed(2)}',
            extraItemLabelFontSize, extraItemFontSize,
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
                      fontSize: extraItemFontSize,
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
            padding: EdgeInsets.all(padding),
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
      },
    );
  }

  Widget _buildExtraItem(String label, String value, double labelFontSize, double valueFontSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: labelFontSize,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
