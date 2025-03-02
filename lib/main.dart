import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/data_repository.dart';
import 'services/twelve_data_service.dart';

import 'app.dart';
import 'services/floating_window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize .env
  await dotenv.load(fileName: ".env");

  // Firebase
  await Firebase.initializeApp();

  // Floating window / background service
  await FloatingWindowService.initialize();

  TwelveDataService.initQueueProcessor();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DataRepository(),
      child: const MyApp(),
    ),
  );
}
