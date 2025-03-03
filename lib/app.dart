import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'pages/auth_page.dart';
import 'pages/main_page.dart';
import 'app_theme.dart';
import 'services/data_repository.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// We let the user’s preference (saved in Firestore) override system theme.
/// We store that preference in DataRepository or a new “ThemeProvider.”
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Optionally listen for changes if we store theme in DataRepository
    // For brevity, we won't implement a separate provider.
  }

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);

    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'StockTok',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // We store user’s theme preference in dataRepo.darkMode
        themeMode: dataRepo.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const MainWrapper(),
      ),
    );
  }
}

/// Decides which page to show based on authentication state
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
          // Logged in
          return const MainPage();
        } else {
          // Not logged in
          return const AuthPage();
        }
      },
    );
  }
}
