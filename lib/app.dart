import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Fetch the user's doc in Firestore to get the saved "darkMode" setting.
  Future<void> _fetchDarkModeAndSet(User user, DataRepository dataRepo) async {
    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (docSnap.exists) {
      final data = docSnap.data();
      if (data != null && data.containsKey('darkMode')) {
        final isDark = data['darkMode'] as bool? ?? false;
        dataRepo.darkMode = isDark;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        // Still checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is not logged in => show splash
        if (!snapshot.hasData) {
          return const SplashPage();
        }

        // If user is logged in => fetch their theme setting from Firestore
        final user = snapshot.data!;
        return FutureBuilder<void>(
          future: _fetchDarkModeAndSet(user, dataRepo),
          builder: (ctx, themeSnapshot) {
            if (themeSnapshot.connectionState == ConnectionState.waiting) {
              // still loading doc => show loading
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Done fetching, show main page with the correct theme
            return const MainPage();
          },
        );
      },
    );
  }
}
