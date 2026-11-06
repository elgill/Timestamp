// Renders the main screen on simulated devices and writes PNGs, so layout
// changes can be eyeballed without a phone or simulator.
//
//   flutter test test/screenshot_test.dart --dart-define=SCREENSHOTS=true
//
// Output goes to build/screenshots/. Skipped during a normal `flutter test`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

/// Approximate Dynamic Island rect (points) for iPhone 15 Pro devices.
Rect? _dynamicIsland(DeviceSpec device) {
  if (!device.name.startsWith('iPhone 15')) return null;
  const long = 126.0, short = 37.0, inset = 11.0;
  return device.isLandscape
      ? Rect.fromLTWH(inset, (device.size.height - long) / 2, short, long)
      : Rect.fromLTWH((device.size.width - long) / 2, inset, long, short);
}

void main() {
  for (final device in allDevices) {
    testWidgets('screenshot $device', skip: !_enabled, (tester) async {
      await tester.runAsync(loadRealFonts);
      // Tests draw shadows as solid outlines by default; draw real ones.
      debugDisableShadows = false;
      setDevice(tester, device);
      await pumpApp(tester, buttons: migraineButtons, rows: 5);
      tester.takeException(); // Capture even if the layout overflows.

      final name = device.name.replaceAll(' ', '_');
      await tester.runAsync(() async {
        final frame =
            await captureImage(tester.element(find.byType(MaterialApp)));
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawImage(frame, Offset.zero, Paint());
        final island = _dynamicIsland(device);
        if (island != null) {
          final dpr = device.devicePixelRatio;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTRB(island.left * dpr, island.top * dpr,
                    island.right * dpr, island.bottom * dpr),
                Radius.circular(20 * dpr)),
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
