// Renders the main screen on simulated devices and writes PNGs, so layout
// changes can be eyeballed without a phone or simulator.
//
//   flutter test test/screenshot_test.dart --dart-define=SCREENSHOTS=true
//
// Output goes to build/screenshots/, plus report.json with per-device
// metrics (visible buttons, rendered label sizes, overflow). Skipped during a
// normal `flutter test`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

final _report = <Map<String, Object?>>[];

/// Measures what the user would actually see, independent of how the app
/// implements its layout (so it works on old and new code alike).
Map<String, Object?> _measure(
    WidgetTester tester, DeviceSpec device, Object? exception) {
  final safeArea =
      device.padding.deflateRect(Offset.zero & device.size).inflate(0.5);
  final cutout = device.cutoutRect;
  final screen = (Offset.zero & device.size).inflate(0.5);
  var onScreen = 0, inSafeArea = 0, underCutout = 0;
  final fontSizes = <double>[];

  for (final label in migraineButtons) {
    final button = find.widgetWithText(ElevatedButton, label);
    if (button.evaluate().isEmpty) continue;
    final rect = tester.getRect(button);
    final tappable = button.hitTestable().evaluate().isNotEmpty;
    bool inside(Rect r) => r.contains(rect.topLeft) && r.contains(rect.bottomRight);
    if (tappable && inside(screen)) onScreen++;
    if (tappable && inside(safeArea)) inSafeArea++;
    if (cutout != null && cutout.overlaps(rect)) underCutout++;

    // Rendered size = style size x system text scale x any FittedBox scale.
    final text = find.descendant(of: button, matching: find.text(label));
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final styleSize = paragraph.text.style?.fontSize ?? 14;
    final scale = tester.getRect(text).width / paragraph.size.width;
    fontSizes.add(styleSize * device.textScale * scale);
  }
  fontSizes.sort();

  final overflow = RegExp(r'overflowed by ([0-9.]+) pixels')
      .firstMatch(exception?.toString() ?? '')
      ?.group(1);

  double round(double v) => (v * 10).round() / 10;
  return {
    'device': device.name,
    'width': device.size.width,
    'height': device.size.height,
    'landscape': device.isLandscape,
    'textScale': device.textScale,
    'total': migraineButtons.length,
    'onScreen': onScreen,
    'inSafeArea': inSafeArea,
    'underCutout': underCutout,
    'minFont': fontSizes.isEmpty ? null : round(fontSizes.first),
    'medianFont':
        fontSizes.isEmpty ? null : round(fontSizes[fontSizes.length ~/ 2]),
    'overflowPx': overflow == null ? 0 : double.parse(overflow),
    'image': '${_fileName(device)}.png',
  };
}

String _fileName(DeviceSpec device) =>
    device.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

void main() {
  tearDownAll(() {
    if (!_enabled) return;
    File('build/screenshots/report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_report));
  });

  for (final device in [...allDevices, ...largeTextDevices]) {
    testWidgets('screenshot $device', skip: !_enabled, (tester) async {
      await tester.runAsync(loadRealFonts);
      // Tests draw shadows as solid outlines by default; draw real ones.
      debugDisableShadows = false;
      setDevice(tester, device);
      await pumpApp(tester, buttons: migraineButtons, rows: 5);
      // Capture even if the layout overflows, but record it.
      final exception = tester.takeException();
      _report.add(_measure(tester, device, exception));

      final name = _fileName(device);
      await tester.runAsync(() async {
        final frame =
            await captureImage(tester.element(find.byType(MaterialApp)));
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawImage(frame, Offset.zero, Paint());
        // Paint the camera cutout so it's visible what it would hide.
        final cutout = device.cutoutRect;
        if (cutout != null) {
          final dpr = device.devicePixelRatio;
          final r = Rect.fromLTRB(cutout.left * dpr, cutout.top * dpr,
              cutout.right * dpr, cutout.bottom * dpr);
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2)),
            Paint()..color = Colors.black,
          );
        }
        final composed =
            await recorder.endRecording().toImage(frame.width, frame.height);
        final png = await composed.toByteData(format: ui.ImageByteFormat.png);
        File('build/screenshots/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });

      await unmountApp(tester);
      debugDisableShadows = true; // Must be restored before the test ends.
    });
  }
}
