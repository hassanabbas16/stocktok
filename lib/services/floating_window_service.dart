import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/stock_data.dart';

class FloatingWindowService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Initialize notifications
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Create notification channel
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'stocktok_service',
        'StockTok Ticker',
        description: 'Shows stock ticker information',
        importance: Importance.low,
      ),
    );

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'stocktok_service',
        initialNotificationTitle: 'StockTok Ticker',
        initialNotificationContent: 'Loading...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      Map<String, dynamic> stockData = {};
      
      service.on('updateNotification').listen((event) {
        if (event != null) {
          service.setForegroundNotificationInfo(
            title: "StockTok Ticker",
            content: event['displayText'] ?? '',
          );
        }
      });
      
      service.on('setStocks').listen((event) {
        if (event != null) {
          stockData = event;
          service.setForegroundNotificationInfo(
            title: "StockTok Ticker",
            content: stockData['displayText'] ?? '',
          );
        }
      });
    }
  }

  Future<void> startService(List<StockData> stocks, Map<String, bool> displayPrefs) async {
    final service = FlutterBackgroundService();
    await service.startService();
    String displayText = _buildDisplayText(stocks[0], displayPrefs);
    service.invoke('updateNotification', {'displayText': displayText});
  }

  String _buildDisplayText(StockData stock, Map<String, bool> displayPrefs) {
    List<String> displayParts = [];
    if (displayPrefs['showSymbol'] ?? true) displayParts.add(stock.symbol);
    if (displayPrefs['showPrice'] ?? true) displayParts.add('\$${stock.currentPrice.toStringAsFixed(2)}');
    if (displayPrefs['showPercentChange'] ?? true) displayParts.add('${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%');
    return displayParts.join(' | ');
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  void dispose() async {
    await stopService();
  }
} 