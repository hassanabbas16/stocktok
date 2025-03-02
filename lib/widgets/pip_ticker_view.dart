import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';
import '../pages/main_page.dart';

class PipTickerView extends StatefulWidget {
  final List<StockData> stocks;
  final Map<String, bool> displayPrefs;
  final String separator;

  final Color textColor;    // color for non-numeric text
  final String adText;      // text to insert as ad

  const PipTickerView({
    Key? key,
    required this.stocks,
    required this.displayPrefs,
    required this.separator,
    this.textColor = Colors.white,
    this.adText = 'Brought to you by Emergitech Solutions',
  }) : super(key: key);

  @override
  State<PipTickerView> createState() => _PipTickerViewState();
}

class _PipTickerViewState extends State<PipTickerView> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late Timer _scrollTimer;
  late Timer _adInsertTimer;

  static const double _scrollSpeed = 1.0;          // pixels per step
  static const Duration _scrollInterval = Duration(milliseconds: 15);

  final List<String> _segments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _buildSegments();
    _startScrolling();
    _startAdInsertion();
  }

  void _buildSegments() {
    _segments.clear();
    for (final stock in widget.stocks) {
      _segments.add(_buildDisplayText(stock));
    }
  }

  // Build the text from displayPrefs
  String _buildDisplayText(StockData stock) {
    final dp = widget.displayPrefs;
    List<String> parts = [];

    if (dp['showSymbol'] ?? true) parts.add(stock.symbol);
    if (dp['showName'] ?? false) parts.add(stock.name);
    if (dp['showPrice'] ?? true) parts.add('\$${stock.currentPrice.toStringAsFixed(2)}');
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
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.offset + _scrollSpeed);
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (_scrollController.offset >= maxScroll) {
          _scrollController.jumpTo(0);
        }
      }
    });
  }

  void _startAdInsertion() {
    _adInsertTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {
        _segments.add(widget.adText);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When PiP is exited
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer.cancel();
    _adInsertTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Decide coloring
  bool _isNumericWord(String word) {
    // e.g. if word has digits, $, or %
    return RegExp(r'[\d\$\.\%]').hasMatch(word);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return Container(
      color: backgroundColor,
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _segments.map((seg) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildSegmentRichText(seg),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSegmentRichText(String segment) {
    final words = segment.split(' ');
    final List<TextSpan> spans = [];

    for (var word in words) {
      // Are we seeing a positive or negative number?
      bool isPositive = word.contains('+') && !word.contains('Vol');
      bool isNegative = word.contains('-') && !word.contains('Vol');

      Color color = widget.textColor;
      if (_isNumericWord(word)) {
        // color numeric
        color = isPositive ? Colors.green : (isNegative ? Colors.red : widget.textColor);
      }

      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
