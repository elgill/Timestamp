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

/// What cuts into the screen at the top (portrait) / left (landscape).
enum Cutout { none, notch, dynamicIsland, punchHole }

/// A simulated device screen, in logical points.
class DeviceSpec {
  const DeviceSpec(
    this.name,
    this.size,
    this.devicePixelRatio,
    this.padding, {
    this.cutout = Cutout.none,
    this.textScale = 1.0,
  });

  final String name;
  final Size size;
  final double devicePixelRatio;

  /// Safe-area insets (notch / Dynamic Island / home indicator / status
  /// bar), in points.
  final EdgeInsets padding;

  final Cutout cutout;

  /// System font size setting (1.0 = default).
  final double textScale;

  bool get isLandscape => size.width > size.height;

  /// Same device with a larger system text size.
  DeviceSpec withTextScale(double scale) => DeviceSpec(
      '$name, text ${(scale * 100).round()}%', size, devicePixelRatio, padding,
      cutout: cutout, textScale: scale);

  /// Approximate area hidden by the camera cutout, in points, assuming the
  /// device is rotated so the cutout is on the left in landscape.
  Rect? get cutoutRect {
    final (double long, double short, double inset) = switch (cutout) {
      Cutout.none => (0.0, 0.0, 0.0),
      Cutout.notch => (162.0, 32.0, 0.0),
      Cutout.dynamicIsland => (126.0, 37.0, 11.0),
      Cutout.punchHole => (24.0, 24.0, 10.0),
    };
    if (cutout == Cutout.none) return null;
    return isLandscape
        ? Rect.fromLTWH(inset, (size.height - long) / 2, short, long)
        : Rect.fromLTWH((size.width - long) / 2, inset, long, short);
  }

  @override
  String toString() => name;
}

// ---------------------------------------------------------------------------
// Device catalog. Sizes are logical points; insets are the system safe areas
// (approximate for Android, which varies by manufacturer and nav mode).
// ---------------------------------------------------------------------------

// iPhones
const iPhoneSEPortrait = DeviceSpec('iPhone SE portrait', Size(375, 667), 2,
    EdgeInsets.only(top: 20));
const iPhoneSELandscape =
    DeviceSpec('iPhone SE landscape', Size(667, 375), 2, EdgeInsets.zero);
const iPhone13MiniPortrait = DeviceSpec('iPhone 13 mini portrait',
    Size(375, 812), 3, EdgeInsets.only(top: 50, bottom: 34),
    cutout: Cutout.notch);
const iPhone13MiniLandscape = DeviceSpec('iPhone 13 mini landscape',
    Size(812, 375), 3, EdgeInsets.only(left: 50, right: 50, bottom: 21),
    cutout: Cutout.notch);
const iPhone15ProPortrait = DeviceSpec('iPhone 15 Pro portrait',
    Size(393, 852), 3, EdgeInsets.only(top: 59, bottom: 34),
    cutout: Cutout.dynamicIsland);
const iPhone15ProLandscape = DeviceSpec('iPhone 15 Pro landscape',
    Size(852, 393), 3, EdgeInsets.only(left: 59, right: 59, bottom: 21),
    cutout: Cutout.dynamicIsland);
const iPhone15ProMaxPortrait = DeviceSpec('iPhone 15 Pro Max portrait',
    Size(430, 932), 3, EdgeInsets.only(top: 59, bottom: 34),
    cutout: Cutout.dynamicIsland);
const iPhone15ProMaxLandscape = DeviceSpec('iPhone 15 Pro Max landscape',
    Size(932, 430), 3, EdgeInsets.only(left: 59, right: 59, bottom: 21),
    cutout: Cutout.dynamicIsland);
const iPhone16ProPortrait = DeviceSpec('iPhone 16 Pro portrait',
    Size(402, 874), 3, EdgeInsets.only(top: 62, bottom: 34),
    cutout: Cutout.dynamicIsland);
const iPhone16ProLandscape = DeviceSpec('iPhone 16 Pro landscape',
    Size(874, 402), 3, EdgeInsets.only(left: 62, right: 62, bottom: 21),
    cutout: Cutout.dynamicIsland);
const iPhone16ProMaxPortrait = DeviceSpec('iPhone 16 Pro Max portrait',
    Size(440, 956), 3, EdgeInsets.only(top: 62, bottom: 34),
    cutout: Cutout.dynamicIsland);
const iPhone16ProMaxLandscape = DeviceSpec('iPhone 16 Pro Max landscape',
    Size(956, 440), 3, EdgeInsets.only(left: 62, right: 62, bottom: 21),
    cutout: Cutout.dynamicIsland);

// iPads
const iPadMiniPortrait = DeviceSpec('iPad mini portrait', Size(744, 1133), 2,
    EdgeInsets.only(top: 24, bottom: 20));
const iPadMiniLandscape = DeviceSpec('iPad mini landscape', Size(1133, 744),
    2, EdgeInsets.only(top: 24, bottom: 20));
const iPadPortrait = DeviceSpec('iPad portrait', Size(820, 1180), 2,
    EdgeInsets.only(top: 24, bottom: 20));
const iPadLandscape = DeviceSpec('iPad landscape', Size(1180, 820), 2,
    EdgeInsets.only(top: 24, bottom: 20));
const iPadPro13Landscape = DeviceSpec('iPad Pro 13in landscape',
    Size(1376, 1032), 2, EdgeInsets.only(top: 24, bottom: 20));
const iPadSlideOver = DeviceSpec('iPad Slide Over', Size(320, 980), 2,
    EdgeInsets.only(top: 24, bottom: 20));
const iPadSplitViewLandscape = DeviceSpec('iPad split view half landscape',
    Size(586, 820), 2, EdgeInsets.only(top: 24, bottom: 20));

// Android
const androidSmallPortrait = DeviceSpec('Small Android portrait',
    Size(360, 640), 2, EdgeInsets.only(top: 24));
const androidSmallLandscape = DeviceSpec('Small Android landscape',
    Size(640, 360), 2, EdgeInsets.only(top: 24));
const pixel7Portrait = DeviceSpec('Pixel 7 portrait', Size(412, 915), 2.625,
    EdgeInsets.only(top: 32, bottom: 24),
    cutout: Cutout.punchHole);
const pixel7Landscape = DeviceSpec('Pixel 7 landscape', Size(915, 412), 2.625,
    EdgeInsets.only(left: 32, top: 24, bottom: 16),
    cutout: Cutout.punchHole);
const galaxyS23Portrait = DeviceSpec('Galaxy S23 portrait', Size(360, 780), 3,
    EdgeInsets.only(top: 36, bottom: 24),
    cutout: Cutout.punchHole);
const galaxyS23Landscape = DeviceSpec('Galaxy S23 landscape', Size(780, 360),
    3, EdgeInsets.only(left: 36, top: 24, bottom: 16),
    cutout: Cutout.punchHole);
const foldCoverPortrait = DeviceSpec('Galaxy Z Fold cover portrait',
    Size(344, 882), 2.625, EdgeInsets.only(top: 32, bottom: 24),
    cutout: Cutout.punchHole);
const foldCoverLandscape = DeviceSpec('Galaxy Z Fold cover landscape',
    Size(882, 344), 2.625, EdgeInsets.only(left: 32, top: 24, bottom: 16),
    cutout: Cutout.punchHole);
const foldOpenPortrait = DeviceSpec('Galaxy Z Fold open portrait',
    Size(690, 829), 2.625, EdgeInsets.only(top: 32, bottom: 24));
const foldOpenLandscape = DeviceSpec('Galaxy Z Fold open landscape',
    Size(829, 690), 2.625, EdgeInsets.only(top: 32, bottom: 24));
const androidTabletPortrait = DeviceSpec('Android tablet portrait',
    Size(800, 1280), 2, EdgeInsets.only(top: 24, bottom: 48));

const iPhones = [
  iPhoneSEPortrait,
  iPhoneSELandscape,
  iPhone13MiniPortrait,
  iPhone13MiniLandscape,
  iPhone15ProPortrait,
  iPhone15ProLandscape,
  iPhone15ProMaxPortrait,
  iPhone15ProMaxLandscape,
  iPhone16ProPortrait,
  iPhone16ProLandscape,
  iPhone16ProMaxPortrait,
  iPhone16ProMaxLandscape,
];

const iPads = [
  iPadMiniPortrait,
  iPadMiniLandscape,
  iPadPortrait,
  iPadLandscape,
  iPadPro13Landscape,
  iPadSlideOver,
  iPadSplitViewLandscape,
];

const androidDevices = [
  androidSmallPortrait,
  androidSmallLandscape,
  pixel7Portrait,
  pixel7Landscape,
  galaxyS23Portrait,
  galaxyS23Landscape,
  foldCoverPortrait,
  foldCoverLandscape,
  foldOpenPortrait,
  foldOpenLandscape,
  androidTabletPortrait,
];

const allDevices = [...iPhones, ...iPads, ...androidDevices];

/// A few of the tightest screens with the system text size turned up.
final largeTextDevices = [
  iPhoneSEPortrait.withTextScale(1.3),
  iPhoneSELandscape.withTextScale(1.3),
  iPhone15ProLandscape.withTextScale(1.3),
  androidSmallLandscape.withTextScale(1.3),
  foldCoverPortrait.withTextScale(1.3),
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
  tester.platformDispatcher.textScaleFactorTestValue = device.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

bool _realFontsLoaded = false;

/// Replaces the test font (where every glyph is a 1em square) with Roboto
/// from the Flutter SDK so text measurements are realistic. Call inside
/// `tester.runAsync`.
Future<void> loadRealFonts() async {
  if (_realFontsLoaded) return;
  _realFontsLoaded = true;
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

/// 20 buttons (4 per row over 5 rows) for a denser layout.
const manyButtons = [
  ...migraineButtons,
  'Jaw pain',
  'Tingling',
  'Ate',
  'Caffeine',
  'Slept',
];
