import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class CustomScrollingTicker extends StatefulWidget {
  final List<StockData> stocks;
  final Map<String, bool> displayPrefs;
  final String separator;
  final bool isLandscape;

  const CustomScrollingTicker({
    Key? key,
    required this.stocks,
    required this.displayPrefs,
    required this.separator,
    required this.isLandscape,
  }) : super(key: key);

  @override
  State<CustomScrollingTicker> createState() => _CustomScrollingTickerState();
}

class _CustomScrollingTickerState extends State<CustomScrollingTicker> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  static const double _scrollSpeed = 1.0;
  static const Duration _scrollInterval = Duration(milliseconds: 15);

  final List<String> _liveSegments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _buildSegments();
    _startScrolling();
  }

  @override
  void didUpdateWidget(CustomScrollingTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stocks != widget.stocks ||
        oldWidget.displayPrefs != widget.displayPrefs ||
        oldWidget.separator != widget.separator) {
      _buildSegments();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  void _buildSegments() {
    final baseSegments = <String>[];
    int count = 0;
    for (final stock in widget.stocks) {
      baseSegments.add(_buildDisplayText(stock));
      count++;
      if (count % 3 == 0) {
        baseSegments.add('Brought to you by Emergitech Solutions');
      }
    }
    _liveSegments
      ..clear()
      ..addAll(baseSegments)
      ..addAll(baseSegments);
  }

  String _buildDisplayText(StockData stock) {
    final dp = widget.displayPrefs;
    List<String> parts = [];

    if (dp['showSymbol'] ?? true) parts.add(stock.symbol);
    if (dp['showName'] ?? false) parts.add(stock.name);
    if (dp['showPrice'] ?? true) {
      parts.add('\$${stock.currentPrice.toStringAsFixed(2)}');
    }
    if (dp['showPercentChange'] ?? true) {
      final sign = stock.percentChange >= 0 ? '+' : '';
      parts.add('$sign${stock.percentChange.toStringAsFixed(2)}%');
    }
    if (dp['showAbsoluteChange'] ?? false) {
      final sign = stock.absoluteChange >= 0 ? '+' : '';
      parts.add('$sign${stock.absoluteChange.toStringAsFixed(2)}');
    }
    if (dp['showVolume'] ?? false) {
      parts.add('Vol:${stock.volume}');
    }
    if (dp['showOpeningPrice'] ?? false) {
      parts.add('Open:\$${stock.openPrice.toStringAsFixed(2)}');
    }
    if (dp['showDailyHighLow'] ?? false) {
      parts.add('H:\$${stock.highPrice.toStringAsFixed(2)} L:\$${stock.lowPrice.toStringAsFixed(2)}');
    }

    return parts.join(widget.separator);
  }

  void _startScrolling() {
    _scrollTimer = Timer.periodic(_scrollInterval, (_) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final newPos = _scrollController.offset + _scrollSpeed;

      if (newPos >= maxScroll / 2) {
        _scrollController.jumpTo(newPos - (maxScroll / 2));
      } else {
        _scrollController.jumpTo(newPos);
      }
    });
  }

  bool _isNumericWord(String word) {
    return RegExp(r'[\d\$\.\%]').hasMatch(word);
  }

  Widget _buildLogo(Brightness brightness) {
    // Larger logo in landscape mode
    final double size = widget.isLandscape ? 42 : 30;
    
    return Image.asset(
      'assets/logos/logo.png',
      color: brightness == Brightness.dark ? Colors.white : null,
      width: size,
      height: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final nonNumericColor = (brightness == Brightness.dark) ? Colors.white : Colors.black;
    final bgColor = (brightness == Brightness.dark) ? Colors.black : Colors.white;
    
    // Adjust horizontal margins based on orientation
    final horizontalMargin = widget.isLandscape ? 80.0 : 40.0;

    return Container(
      color: bgColor,
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _liveSegments.map((seg) {
              // If this segment is the ad, we prepend the logo
              if (seg == 'Brought to you by Emergitech Solutions') {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Row(
                    children: [
                      _buildLogo(brightness),
                      SizedBox(width: widget.isLandscape ? 12 : 8),
                      _buildSegmentRichText(seg, nonNumericColor),
                    ],
                  ),
                );
              } else {
                // Normal text segments
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: _buildSegmentRichText(seg, nonNumericColor),
                );
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentRichText(String segment, Color nonNumericColor) {
    final words = segment.split(' ');
    final List<TextSpan> spans = [];
    
    // Larger font size in landscape
    final double fontSize = widget.isLandscape ? 30.0 : 18.0;
    final fontWeight = FontWeight.bold;

    for (var word in words) {
      bool isPositive = word.contains('+') && !word.contains('Vol') && !word.contains('AD');
      bool isNegative = word.contains('-') && !word.contains('Vol') && !word.contains('AD');

      Color color = nonNumericColor;
      if (_isNumericWord(word)) {
        color = isPositive ? Colors.green : (isNegative ? Colors.red : nonNumericColor);
      }

      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
} 