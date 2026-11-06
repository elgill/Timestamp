import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/widgets/auto_size_label.dart';

import 'helpers/test_app.dart';

/// Smallest label font we accept for 3-4 buttons per row.
const minLegibleFontSize = 12.0;

/// Every record button must be fully on screen, inside the safe area, and
/// actually tappable (not covered by something else).
void expectAllButtonsVisibleAndTappable(
    WidgetTester tester, DeviceSpec device, List<String> labels) {
  final safeArea =
      device.padding.deflateRect(Offset.zero & device.size).inflate(0.5);

  for (final label in labels) {
    final finder = find.widgetWithText(ElevatedButton, label);
    expect(finder, findsOneWidget, reason: '"$label" is not in the tree');

    final rect = tester.getRect(finder);
    expect(
      safeArea.contains(rect.topLeft) && safeArea.contains(rect.bottomRight),
      isTrue,
      reason: '"$label" at $rect is outside the visible safe area $safeArea '
          'on $device',
    );

    expect(finder.hitTestable(), findsOneWidget,
        reason: '"$label" cannot be tapped on $device');
  }
}

/// Every label is fully inside its button and uses a readable font size
/// (i.e. it didn't need the scale-down fallback).
void expectLabelsLegible(
    WidgetTester tester, DeviceSpec device, List<String> labels) {
  for (final label in labels) {
    final button = find.widgetWithText(ElevatedButton, label);
    final text = find.descendant(
        of: find.descendant(of: button, matching: find.byType(AutoSizeLabel)),
        matching: find.text(label));

    expect(find.descendant(of: button, matching: find.byType(FittedBox)),
        findsNothing,
        reason: '"$label" had to be squeezed onto one line on $device');

    final size = tester.widget<Text>(text).style!.fontSize!;
    expect(size, greaterThanOrEqualTo(minLegibleFontSize),
        reason: '"$label" is only ${size}pt on $device');

    final buttonRect = tester.getRect(button);
    final textRect = tester.getRect(text);
    expect(buttonRect.inflate(0.5).contains(textRect.topLeft) &&
            buttonRect.inflate(0.5).contains(textRect.bottomRight),
        isTrue,
        reason: '"$label" text $textRect is clipped by its button '
            '$buttonRect on $device');
  }
}

Future<void> checkLayout(
  WidgetTester tester,
  DeviceSpec device, {
  required List<String> buttons,
  required int rows,
  bool bottom = false,
  bool ntpSynced = true,
  bool checkLegibility = true,
}) async {
  await tester.runAsync(loadRealFonts);
  setDevice(tester, device);
  await pumpApp(tester,
      buttons: buttons,
      rows: rows,
      ntpSynced: ntpSynced,
      extraPrefs: {
        if (bottom) 'buttonSectionLocation': 'ButtonLocation.bottom',
      });

  // A RenderFlex overflow is reported as an exception by the framework.
  expect(tester.takeException(), isNull);
  expectAllButtonsVisibleAndTappable(tester, device, buttons);
  if (checkLegibility) expectLabelsLegible(tester, device, buttons);

  await unmountApp(tester);
}

void main() {
  for (final device in [...allDevices, ...largeTextDevices]) {
    group('$device:', () {
      // 15 buttons in 1 or 3 rows means 15 or 5 buttons per row: everything
      // must still fit, but labels can't be expected to stay readable on
      // narrow screens, since words are never split.
      for (final rows in [1, 3]) {
        testWidgets('$rows rows, buttons on top', (tester) async {
          await checkLayout(tester, device,
              buttons: migraineButtons, rows: rows, checkLegibility: false);
        });
      }

      testWidgets('5 rows, buttons on top', (tester) async {
        await checkLayout(tester, device, buttons: migraineButtons, rows: 5);
      });

      testWidgets('5 rows, buttons at the bottom', (tester) async {
        await checkLayout(tester, device,
            buttons: migraineButtons, rows: 5, bottom: true);
      });

      testWidgets('5 rows, no NTP sync yet', (tester) async {
        await checkLayout(tester, device,
            buttons: migraineButtons, rows: 5, ntpSynced: false);
      });

      testWidgets('20 buttons in 5 rows', (tester) async {
        await checkLayout(tester, device,
            buttons: manyButtons,
            rows: 5,
            // 4 per row with enlarged text is too tight on the narrowest
            // screens (e.g. Fold cover); layout must still hold.
            checkLegibility: device.textScale == 1.0);
      });
    });
  }

  testWidgets('event list keeps some room on iPhone 15 Pro landscape',
      (tester) async {
    setDevice(tester, iPhone15ProLandscape);
    await pumpApp(tester, buttons: migraineButtons, rows: 5);

    final list = tester.getRect(find.byType(ListView));
    expect(list.height, greaterThan(0));

    await unmountApp(tester);
  });

  testWidgets('tapping the last (5th row) button records an event in landscape',
      (tester) async {
    setDevice(tester, iPhone15ProLandscape);
    await pumpApp(tester, buttons: migraineButtons, rows: 5);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Relief'));
    await tester.pump();

    // The event list now shows the recorded label (outside the button).
    expect(
        find.descendant(
            of: find.byType(ListView), matching: find.text('Relief')),
        findsOneWidget);

    await unmountApp(tester);
  });
}
