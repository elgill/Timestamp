import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

import 'main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
  ], child: const TimestampApp()));
}

class TimestampApp extends StatelessWidget {
  const TimestampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timestamp',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ), // Light mode
      darkTheme: ThemeData.dark(), // Dark mode
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}
