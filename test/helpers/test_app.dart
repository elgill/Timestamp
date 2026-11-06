import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/main.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/services/ntp_service.dart';

/// NtpService that never touches the network.
///
/// With [synced] it pretends a sync succeeded, which makes the bottom bar
/// show its (taller) sync details.
class FakeNtpService extends NtpService {
  FakeNtpService(super.ref, {this.synced = false});

  final bool synced;

  @override
  Future<void> updateNtpOffset() async {}

  @override
  bool get isInfoRecieved => synced;
  @override
  int get ntpOffset => synced ? 12 : 0;
  @override
  int get roundTripTime => synced ? 40 : 9999;
  @override
  DateTime get lastSyncTime =>
      synced ? DateTime(2026, 11, 6, 9, 41) : super.lastSyncTime;
}

/// A simulated device screen, in logical points.
class DeviceSpec {
  const DeviceSpec(this.name, this.size, this.devicePixelRatio, this.padding);

  final String name;
  final Size size;
  final double devicePixelRatio;

  /// Safe-area insets (notch / Dynamic Island / home indicator), in points.
  final EdgeInsets padding;

  bool get isLandscape => size.width > size.height;

  @override
  String toString() => name;
}

const iPhone15ProPortrait = DeviceSpec(
  'iPhone 15 Pro portrait',
  Size(393, 852),
  3.0,
  EdgeInsets.only(top: 59, bottom: 34),
);

const iPhone15ProLandscape = DeviceSpec(
  'iPhone 15 Pro landscape',
  Size(852, 393),
  3.0,
  EdgeInsets.only(left: 59, right: 59, bottom: 21),
);

const iPhoneSELandscape = DeviceSpec(
  'iPhone SE landscape',
  Size(667, 375),
  2.0,
  EdgeInsets.zero,
);

const iPadPortrait = DeviceSpec(
  'iPad portrait',
  Size(820, 1180),
  2.0,
  EdgeInsets.only(top: 24, bottom: 20),
);

const allDevices = [
  iPhone15ProPortrait,
  iPhone15ProLandscape,
  iPhoneSELandscape,
  iPadPortrait,
];

/// Configures the test view to look like [device].
void setDevice(WidgetTester tester, DeviceSpec device) {
  final dpr = device.devicePixelRatio;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = device.size * dpr;
  final p = device.padding * dpr;
  final fake = FakeViewPadding(
      left: p.left, top: p.top, right: p.right, bottom: p.bottom);
  tester.view.padding = fake;
  tester.view.viewPadding = fake;
  addTearDown(tester.view.reset);
}

/// Pumps the full app with the given button labels and row count.
Future<void> pumpApp(
  WidgetTester tester, {
  required List<String> buttons,
  required int rows,
  bool ntpSynced = true,
  Map<String, Object> extraPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    customEventNamesKey: buttons,
    maxButtonRowsKey: rows,
    // Wakelock talks to a platform plugin that doesn't exist in tests.
    disableAutoLockKey: false,
    ...extraPrefs,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ntpServiceProvider
          .overrideWith((ref) => FakeNtpService(ref, synced: ntpSynced)),
    ],
    child: const TimestampApp(),
  ));
  await tester.pump();
}

/// MainScreen runs a periodic timer; replace the tree so it gets cancelled.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Symptom-tracking labels similar to the ones in the user report:
/// 15 buttons over 5 rows, including some longer than 12 characters.
const migraineButtons = [
  'Aura',
  'Headache',
  'Nausea',
  'Light sensitivity',
  'Sound sensitivity',
  'Took medication',
  'Dizzy',
  'Neck pain',
  'Vomiting',
  'Blurred vision',
  'Fatigue',
  'Brain fog',
  'Pain level 5+',
  'Lay down',
  'Relief',
];

/// Replaces the test font (where every glyph is a 1em square) with Roboto
/// from the Flutter SDK so text measurements are realistic. Call inside
/// `tester.runAsync`.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT not set; run tests with `flutter test`.');
  }
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const roboto = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf'];
  await load('Roboto', roboto);
  await load('Courier New', ['Roboto-Regular.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
