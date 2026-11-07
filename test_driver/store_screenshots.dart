// The app as it appears in the App Store screenshots: real UI on a simulator,
// with demo data and a frozen clock. Started by tool/store_screenshots.dart.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/main.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/providers/display_mode_provider.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';
import 'package:timestamp/services/ntp_service.dart';

/// Matches the 9:41 the tool puts in the status bar.
final _now = DateTime(2026, 11, 3, 9, 41, 27, 300);

const _detailEvent = 'Finish line';

const _buttons = [
  ('Start', PredefinedColor.green),
  ('Checkpoint', PredefinedColor.defaultColor),
  ('Finish', PredefinedColor.purple),
  ('Break', PredefinedColor.orange),
  ('Incident', PredefinedColor.red),
  ('Note', PredefinedColor.defaultColor),
];

final _events = [
  _event(0, 4, 'Note', PredefinedColor.defaultColor),
  _event(2, 51, _detailEvent, PredefinedColor.purple),
  _event(9, 18, 'Checkpoint', PredefinedColor.defaultColor),
  _event(14, 37, 'Incident', PredefinedColor.red),
  _event(21, 6, 'Break', PredefinedColor.orange),
  _event(28, 44, 'Checkpoint', PredefinedColor.defaultColor),
  _event(37, 12, 'Checkpoint', PredefinedColor.defaultColor),
  _event(46, 29, 'Start', PredefinedColor.green),
];

Event _event(int minutes, int seconds, String name, PredefinedColor color) =>
    Event(_now.subtract(Duration(minutes: minutes, seconds: seconds)), 18,
        description: name, color: color);

/// Always synced, and time stands still so reruns give identical images.
class _DemoNtpService extends NtpService {
  _DemoNtpService(super.ref);

  @override
  Future<void> updateNtpOffset() async {}
  @override
  DateTime get currentTime => _now;
  @override
  bool get isInfoRecieved => true;
  @override
  int get ntpOffset => 6;
  @override
  int get roundTripTime => 36;
  @override
  int get ntpStratum => 1;
  @override
  String get timeServer => 'time.google.com';
  @override
  DateTime get lastSyncTime => _now.subtract(const Duration(minutes: 3));
}

Future<void> main() async {
  late final LiveWidgetController controller;
  late final ProviderContainer container;

  Future<void> settle() => Future.delayed(const Duration(milliseconds: 900));

  // Each scene starts from where the previous one left off.
  final scenes = <String, Future<void> Function()>{
    // After a cold launch the status bar stays dark on the teal app bar until
    // the theme changes.
    'events': () async {
      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      await settle();
      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    },
    'relative_dark': () async {
      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      container
          .read(displayModeProvider.notifier)
          .setDisplayMode(DisplayMode.relative);
    },
    'event_detail': () async {
      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      container
          .read(displayModeProvider.notifier)
          .setDisplayMode(DisplayMode.absolute);
      await settle();
      await controller.tap(find.text(_detailEvent));
    },
    'settings': () async {
      await controller.tap(find.byType(BackButton));
      await settle();
      await controller.tap(find.byIcon(CupertinoIcons.settings));
    },
  };

  enableFlutterDriverExtension(handler: (request) async {
    if (request == 'scenes') return scenes.keys.join(',');
    await scenes[request]!();
    await settle();
    return 'ready';
  });
  controller = LiveWidgetController(WidgetsBinding.instance);

  // Debug builds are all a simulator can run; hide what gives that away.
  WidgetsApp.debugAllowBannerOverride = false;

  // In memory, so nothing on the simulator is read or overwritten.
  SharedPreferences.setMockInitialValues({
    customButtonModelsKey: [
      for (final (name, color) in _buttons)
        jsonEncode(ButtonModel(name, color).toJson()),
    ],
    customEventNamesKey: [for (final (name, _) in _buttons) name],
    maxButtonRowsKey: 2,
    themeModeKey: ThemeMode.light.toString(),
    'events': [for (final event in _events) event.toJson()],
    referenceEventKey: _events.last.toJson(),
  });
  final prefs = await SharedPreferences.getInstance();

  container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    ntpServiceProvider.overrideWith((ref) => _DemoNtpService(ref)),
  ]);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const TimestampApp(),
  ));
}
