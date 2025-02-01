// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Overlay plugin
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// Your pages
import 'pages/auth_page.dart';
import 'pages/main_page.dart';

// IMPORTANT: Import overlay_main.dart so Dart knows overlayMain() exists
import 'overlay_main.dart'; // <-- This must contain @pragma("vm:entry-point") void overlayMain()

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called whenever the app lifecycle changes (foreground, background, etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // App going to background -> start overlay if not already
      if (!_overlayActive) {
        _startOverlay();
        _overlayActive = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came back -> close the overlay
      if (_overlayActive) {
        FlutterOverlayWindow.closeOverlay();
        _overlayActive = false;
      }
    }
  }

  /// Request "Draw over other apps" permission if needed, then show the overlay
  Future<void> _startOverlay() async {
    bool? canDraw = await FlutterOverlayWindow.isPermissionGranted();
    if (canDraw != true) {
      // Ask user to grant permission in system settings
      bool? granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) {
        debugPrint("Overlay permission not granted by user.");
        return;
      }
    }

    // No entryPointName in v0.4.5 single-engine. The plugin auto-calls overlayMain().
    try {
      await FlutterOverlayWindow.showOverlay(
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        height: 400,
        width: 300,
      );
      debugPrint("Overlay started successfully.");
    } catch (e) {
      debugPrint("Error showing overlay: $e");
    }
  }

  /// Send data (JSON string) to the overlay
  Future<void> updateOverlayData(String jsonString) async {
    // This calls the overlay's data listener
    await FlutterOverlayWindow.shareData(jsonString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StockTok',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainWrapper(
        onSendOverlayData: updateOverlayData,
      ),
    );
  }
}

class MainWrapper extends StatelessWidget {
  final Future<void> Function(String jsonData)? onSendOverlayData;
  const MainWrapper({Key? key, this.onSendOverlayData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // If logged in, show MainPage, pass the overlay method
          return MainPage(
            onSendOverlayData: onSendOverlayData,
          );
        } else {
          // else show AuthPage
          return const AuthPage();
        }
      },
    );
  }
}
