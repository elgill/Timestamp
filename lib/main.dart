import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';

import 'main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
  ], child: const TimestampApp()));
}

class TimestampApp extends ConsumerWidget {
  const TimestampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Timestamp',
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.teal,
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: false,
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
