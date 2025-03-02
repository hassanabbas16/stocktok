import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class StockCard extends StatefulWidget {
  final StockData stock;
  final Map<String, bool> showFilters;
  final String separator;
  final VoidCallback onToggle;

  const StockCard({
    Key? key,
    required this.stock,
    required this.showFilters,
    required this.separator,
    required this.onToggle,
  }) : super(key: key);

  @override
  _StockCardState createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.stock.absoluteChange >= 0 ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed view.
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.stock.symbol,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      Text(widget.stock.name, style: TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${widget.stock.currentPrice.toStringAsFixed(2)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
                      Row(
                        children: [
                          Text(
                            '${widget.stock.absoluteChange >= 0 ? '+' : ''}${widget.stock.absoluteChange.toStringAsFixed(2)} ',
                            style: TextStyle(color: color, fontSize: 14),
                          ),
                          Text(
                            '(${widget.stock.percentChange >= 0 ? '+' : ''}${widget.stock.percentChange.toStringAsFixed(2)}%)',
                            style: TextStyle(color: color, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Volume: ${widget.stock.volume}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        SizedBox(height: 8),
                        Text('Open: \$${widget.stock.openPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        SizedBox(height: 8),
                        Text('High: \$${widget.stock.highPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        SizedBox(height: 8),
                        Text('Low: \$${widget.stock.lowPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        // Adjust this icon based on whether the stock is in the watchlist.
                        Icons.star_border,
                        color: Colors.grey,
                      ),
                      onPressed: widget.onToggle,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
