// Host side of test_driver/store_screenshots.dart: asks the app for each
// scene and photographs the simulator. simctl, unlike Flutter's own capture,
// includes the status bar. Run through tool/store_screenshots.dart.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> simctl(List<String> args) async {
  final result = await Process.run('xcrun', ['simctl', ...args]);
  if (result.exitCode != 0) throw Exception(result.stderr);
}

/// Tidy status bar, as in Apple's own marketing images. The time has to be
/// the last override, or the iPad shows a stock date instead of this one.
Future<void> overrideStatusBar(String udid) async {
  await simctl([
    'status_bar', udid, 'override',
    '--dataNetwork', 'wifi',
    '--wifiMode', 'active',
    '--wifiBars', '3',
    '--cellularMode', 'active',
    '--cellularBars', '4',
    '--batteryState', 'discharging',
    '--batteryLevel', '100',
  ]);
  await simctl([
    'status_bar', udid, 'override',
    '--time', DateTime(2026, 11, 3, 9, 41).toUtc().toIso8601String(),
  ]);
}

Future<void> main() async {
  final udid = Platform.environment['SCREENSHOT_UDID']!;
  final outDir = Platform.environment['SCREENSHOT_DIR']!;
  final display = Platform.environment['SCREENSHOT_DISPLAY'];

  // If the app dies on launch the driver would otherwise wait forever.
  const timeout = Duration(minutes: 1);
  final driver = await FlutterDriver.connect(timeout: timeout);
  final scenes =
      (await driver.requestData('scenes', timeout: timeout)).split(',');
  await overrideStatusBar(udid);
  for (final (index, scene) in scenes.indexed) {
    await driver.requestData(scene, timeout: timeout);
    final number = '${index + 1}'.padLeft(2, '0');
    await simctl([
      'io', udid, 'screenshot',
      if (display != null) '--display=$display',
      '$outDir/${number}_$scene.png',
    ]);
  }
  await driver.close();
}
