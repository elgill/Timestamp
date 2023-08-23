import 'package:flutter/material.dart';

import 'main_screen.dart';

void main() => runApp(const TimestampApp());

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
