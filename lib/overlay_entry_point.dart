// lib/overlay_entry_point.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'overlay_ticker_app.dart';

@pragma('vm:entry-point')
void overlayEntryPoint() {
  runApp(const OverlayTickerApp());
}
