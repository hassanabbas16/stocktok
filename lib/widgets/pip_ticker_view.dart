import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class PipTickerView extends StatefulWidget {
  final List<StockData> stocks;
  final Map<String, bool> displayPrefs;
  final String separator;
  final double animationSpeed;
  final double fontSizeMultiplier;

  const PipTickerView({
    Key? key,
    required this.stocks,
    required this.displayPrefs,
    required this.separator,
    this.animationSpeed = 1.0,
    this.fontSizeMultiplier = 1.0,
  }) : super(key: key);

  @override
  State<PipTickerView> createState() => _PipTickerViewState();
}

class _PipTickerViewState extends State<PipTickerView> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  static const double _baseScrollSpeed = 2.25; // Base speed
  static const Duration _scrollInterval = Duration(milliseconds: 10); // Faster interval

  final List<String> _liveSegments = [];

  double get _scrollSpeed => _baseScrollSpeed * widget.animationSpeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _buildSegments();
    _startScrolling();
  }

  @override
  void didUpdateWidget(PipTickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stocks != widget.stocks ||
        oldWidget.displayPrefs != widget.displayPrefs ||
        oldWidget.separator != widget.separator ||
        oldWidget.animationSpeed != widget.animationSpeed ||
        oldWidget.fontSizeMultiplier != widget.fontSizeMultiplier) {
      _buildSegments();
      // Restart scrolling with new speed if animation speed changed
      if (oldWidget.animationSpeed != widget.animationSpeed) {
        _scrollTimer?.cancel();
        _startScrolling();
      }
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
    
    // Create seamless loop by duplicating content
    _liveSegments
      ..clear()
      ..addAll(baseSegments)
      ..addAll(baseSegments) // Duplicate for seamless scrolling
      ..addAll(baseSegments); // Triple for better seamless effect
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

      // When we reach 1/3 of the total content (one complete cycle), reset
      // This ensures smooth transition since we have triple content
      if (newPos >= maxScroll / 3) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(newPos);
      }
    });
  }

  bool _isNumericWord(String word) {
    return RegExp(r'[\d\$\.\%]').hasMatch(word);
  }

  Widget _buildLogo(Brightness brightness) {
    return Image.asset(
      'assets/logos/logo.png',
      color: brightness == Brightness.dark ? Colors.white : null,
      width: 30,
      height: 30,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final brightness = Theme.of(context).brightness;
        final width = constraints.maxWidth;
        final isTablet = width >= 600;
        final minFontSize = isTablet ? 20.0 : 14.0;
        final maxFontSize = isTablet ? 40.0 : 28.0;
        final baseFontSize = (width * 0.03).clamp(minFontSize, maxFontSize);
        final fontSize = baseFontSize * widget.fontSizeMultiplier;
        final minMargin = isTablet ? 8.0 : 12.0;
        final maxMargin = isTablet ? 32.0 : 80.0;
        final horizontalMargin = (width * 0.025).clamp(minMargin, maxMargin); // Reduced gap
        final minLogo = isTablet ? 28.0 : 20.0;
        final maxLogo = isTablet ? 64.0 : 48.0;
        final logoSize = (width * 0.05).clamp(minLogo, maxLogo);
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
                  if (seg == 'Brought to you by Emergitech Solutions') {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/logos/logo.png',
                            color: brightness == Brightness.dark ? Colors.white : null,
                            width: logoSize,
                            height: logoSize,
                          ),
                          const SizedBox(width: 8),
                          _buildSegmentRichText(seg, nonNumericColor, fontSize),
                        ],
                      ),
                    );
                  } else {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                      child: _buildSegmentRichText(seg, nonNumericColor, fontSize),
                    );
                  }
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentRichText(String segment, Color nonNumericColor, double fontSize) {
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
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}
