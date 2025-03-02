import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';
import '../pages/main_page.dart';

class PipTickerView extends StatefulWidget {
  final List<StockData> stocks;
  final Map<String, bool> displayPrefs;
  final String separator;

  const PipTickerView({
    Key? key,
    required this.stocks,
    required this.displayPrefs,
    required this.separator,
  }) : super(key: key);

  @override
  State<PipTickerView> createState() => _PipTickerViewState();
}

class _PipTickerViewState extends State<PipTickerView> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoScroll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When PiP is exited (app resumed), notify parent to update state
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(),
            maintainState: true,  // Try to maintain the state
          ),
        );
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(Duration(seconds: 3), (_) {
      if (_currentPage < widget.stocks.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  String _buildDisplayText(StockData stock) {
    List<String> displayParts = [];
    
    if (widget.displayPrefs['showSymbol'] ?? true) {
      displayParts.add(stock.symbol);
    }
    if (widget.displayPrefs['showName'] ?? false) {
      displayParts.add(stock.name);
    }
    if (widget.displayPrefs['showPrice'] ?? true) {
      displayParts.add('\$${stock.currentPrice.toStringAsFixed(2)}');
    }
    if (widget.displayPrefs['showPercentChange'] ?? true) {
      String change = '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%';
      displayParts.add(change);
    }
    if (widget.displayPrefs['showAbsoluteChange'] ?? false) {
      displayParts.add('${stock.absoluteChange >= 0 ? '+' : ''}${stock.absoluteChange.toStringAsFixed(2)}');
    }
    if (widget.displayPrefs['showVolume'] ?? false) {
      displayParts.add('Vol: ${stock.volume}');
    }
    if (widget.displayPrefs['showOpeningPrice'] ?? false) {
      displayParts.add('Open: \$${stock.openPrice.toStringAsFixed(2)}');
    }
    if (widget.displayPrefs['showDailyHighLow'] ?? false) {
      displayParts.add('H: \$${stock.highPrice.toStringAsFixed(2)} L: \$${stock.lowPrice.toStringAsFixed(2)}');
    }

    return displayParts.join(widget.separator);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.stocks.length,
        itemBuilder: (context, index) {
          final stock = widget.stocks[index];
          return Center(
            child: RichText(
              text: TextSpan(
                children: _buildDisplayText(stock)
                    .split(widget.separator)
                    .map((part) {
                      bool isValue = part.contains('\$') || part.contains('%');
                      bool isPositive = stock.percentChange >= 0;
                      
                      return TextSpan(
                        text: part + (part == _buildDisplayText(stock).split(widget.separator).last ? '' : widget.separator),
                        style: TextStyle(
                          color: isValue 
                              ? (isPositive ? Colors.green : Colors.red)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
} 