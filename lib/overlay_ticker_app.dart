// lib/overlay_ticker_app.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Minimal model for passing ticker data from JSON
class StockDataModel {
  final String symbol;
  final String name;
  final double currentPrice;
  final double absoluteChange;
  final double percentChange;

  StockDataModel({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.absoluteChange,
    required this.percentChange,
  });

  factory StockDataModel.fromJson(Map<String, dynamic> json) {
    return StockDataModel(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      absoluteChange: (json['absoluteChange'] ?? 0).toDouble(),
      percentChange: (json['percentChange'] ?? 0).toDouble(),
    );
  }
}

class OverlayTickerApp extends StatefulWidget {
  const OverlayTickerApp({Key? key}) : super(key: key);

  @override
  State<OverlayTickerApp> createState() => _OverlayTickerAppState();
}

class _OverlayTickerAppState extends State<OverlayTickerApp> {
  /// We'll keep a list of StockDataModel.
  final ValueNotifier<List<StockDataModel>> _stocksNotifier =
  ValueNotifier([]);

  @override
  void initState() {
    super.initState();

    /// Listen for incoming data from the main app
    FlutterOverlayWindow.overlayListenerSetup((data) {
      // data is a String
      debugPrint("Overlay received data: $data");

      try {
        // Expecting data to be a JSON-encoded list of stock objects
        final List<dynamic> decoded = jsonDecode(data);
        final List<StockDataModel> newList = decoded.map((item) {
          return StockDataModel.fromJson(item);
        }).toList();

        _stocksNotifier.value = newList;
      } catch (e) {
        debugPrint("Error parsing overlay data: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // We want a transparent background, so let's do a minimal MaterialApp
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ValueListenableBuilder<List<StockDataModel>>(
            valueListenable: _stocksNotifier,
            builder: (context, stocks, child) {
              if (stocks.isEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "No Ticker Data",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                );
              }

              return Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                // We'll do a blackish container with some opacity
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: stocks.map((stock) {
                      return _buildOverlayTickerCard(stock);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayTickerCard(StockDataModel stock) {
    final color = (stock.absoluteChange >= 0) ? Colors.green : Colors.red;

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white12,
        border: Border.all(color: Colors.white38, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stock.symbol,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            stock.name,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "\$${stock.currentPrice.toStringAsFixed(2)}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (stock.absoluteChange >= 0 ? "+" : "") +
                    stock.absoluteChange.toStringAsFixed(2),
                style: TextStyle(color: color, fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                "(${(stock.percentChange >= 0 ? "+" : "")}"
                    "${stock.percentChange.toStringAsFixed(2)}%)",
                style: TextStyle(color: color, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
