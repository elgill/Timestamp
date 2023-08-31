import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_screen.dart';

void main() => runApp(const ProviderScope(child: TimestampApp()));


class TimestampApp extends StatelessWidget {
  const TimestampApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timestamp',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MainScreen(),
    );
  }
}
