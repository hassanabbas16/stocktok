import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'pages/main_page.dart';
import 'pages/splash_page.dart';
import 'app_theme.dart';
import 'services/data_repository.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);

    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'StockTok',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dataRepo.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const MainWrapper(),
      ),
    );
  }
}

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

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
          return const MainPage();  // Logged in -> MainPage
        } else {
          return const SplashPage();  // Not logged in -> SplashPage
        }
      },
    );
  }
}
