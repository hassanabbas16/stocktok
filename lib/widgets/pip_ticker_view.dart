import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class PipTickerView extends StatefulWidget {
  final List<StockData> stocks;
  final Map<String, bool> displayPrefs;
  final String separator;

  // We'll forcibly do black text in light mode, white in dark mode
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // if user hits Home, we remain in PiP
    super.didChangeAppLifecycleState(state);
  }

  /// Build an infinite loop by:
  /// 1) converting each watchlist item to a text segment
  /// 2) appending an ad at the end of each set
  /// 3) duplicating the entire set to ensure a seamless loop
  void _buildSegments() {
    final baseSegments = <String>[];

    for (final stock in widget.stocks) {
      baseSegments.add(_buildDisplayText(stock));
    }

    // Insert an ad item after watchlist
    baseSegments.add('[AD => Brought to you by Emergitech Solutions]');

    // now duplicate
    _liveSegments.clear();
    // so we have watchlist+ad, watchlist+ad
    _liveSegments.addAll(baseSegments);
    _liveSegments.addAll(baseSegments);
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

      // infinite loop approach: if we exceed half, jump back by half
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final nonNumericColor = (brightness == Brightness.dark) ? Colors.white : Colors.black;
    final bgColor = (brightness == Brightness.dark) ? Colors.black : Colors.white;

    return Container(
      color: bgColor,
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _liveSegments.map((seg) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSegmentRichText(seg, nonNumericColor),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentRichText(String segment, Color nonNumericColor) {
    final words = segment.split(' ');
    final List<TextSpan> spans = [];

    for (var word in words) {
      bool isPositive = word.contains('+') && !word.contains('Vol') && !word.contains('AD');
      bool isNegative = word.contains('-') && !word.contains('Vol') && !word.contains('AD');

      Color color = nonNumericColor;
      if (_isNumericWord(word)) {
        color = isPositive ? Colors.green : (isNegative ? Colors.red : nonNumericColor);
      }

      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
