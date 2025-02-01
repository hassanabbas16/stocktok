// lib/overlay_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// overlay_main.dart
@pragma("vm:entry-point")
void overlayMain() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.yellow,
      body: Center(
        child: Container(
          color: Colors.red,
          width: 200,
          height: 200,
          child: const Center(child: Text("Overlay Test", style: TextStyle(fontSize: 24))),
        ),
      ),
    ),
  ));
}
