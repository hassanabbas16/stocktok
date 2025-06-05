import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PiPService {
  static const _channel = MethodChannel('com.stocktok/pip');

  static Future<void> enterPiPMode() async {
    try {
      await _channel.invokeMethod('enterPiP');
    } catch (e) {
      debugPrint('Failed to enter PiP mode: $e');
    }
  }

  static Future<void> setIsMainPage(bool isMainPage) async {
    try {
      await _channel.invokeMethod('setIsMainPage', isMainPage);
    } catch (e) {
      debugPrint('Failed to set main page state: $e');
    }
  }
}