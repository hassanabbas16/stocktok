import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/stock_data.dart';

class FloatingWindowService {
  static final FlutterLocalNotificationsPlugin _notifs =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // ----- Local notifications (Android + iOS + macOS) -----
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _notifs.initialize(initSettings);

    // Ask for permissions (iOS/macOS)
    await _notifs
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifs
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android channel
    if (Platform.isAndroid) {
      await _notifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'stock_stream_service',
          'Stock Stream App Ticker',
          description: 'Shows stock ticker information',
          importance: Importance.low,
        ),
      );
    }

    // ----- Background service ticker (Android only) -----
    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'stock_stream_service',
          initialNotificationTitle: 'Stock Stream App Ticker',
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
  }

  static Future<bool> onIosBackground(ServiceInstance service) async => true;

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('updateNotification').listen((event) {
        final content = (event?['displayText'] as String?) ?? '';
        service.setForegroundNotificationInfo(
          title: 'Stock Stream App Ticker',
          content: content,
        );
      });

      service.on('setStocks').listen((event) {
        final content = (event?['displayText'] as String?) ?? '';
        service.setForegroundNotificationInfo(
          title: 'Stock Stream App Ticker',
          content: content,
        );
      });
    }
  }

  Future<void> startService(
    List<StockData> stocks,
    Map<String, bool> displayPrefs,
  ) async {
    final text = _buildDisplayText(stocks.first, displayPrefs);

    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('updateNotification', {'displayText': text});
    } else {
      await _showSimple(
        id: 888,
        title: 'Stock Stream App Ticker',
        body: text,
      );
    }
  }

  Future<void> stopService() async {
    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    }
  }

  String _buildDisplayText(StockData stock, Map<String, bool> displayPrefs) {
    final parts = <String>[];
    if (displayPrefs['showSymbol'] ?? true) parts.add(stock.symbol);
    if (displayPrefs['showPrice'] ?? true) {
      parts.add('\$${stock.currentPrice.toStringAsFixed(2)}');
    }
    if (displayPrefs['showPercentChange'] ?? true) {
      final sign = stock.percentChange >= 0 ? '+' : '';
      parts.add('$sign${stock.percentChange.toStringAsFixed(2)}%');
    }
    return parts.join(' | ');
  }

  Future<void> _showSimple({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'stock_stream_service',
      'Stock Stream App Ticker',
      channelDescription: 'Shows stock ticker information',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _notifs.show(id, title, body, details);
  }
}
