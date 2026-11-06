import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

/// Every record button's label must be fully on screen, inside the safe area,
/// and actually tappable (not covered by something else).
void expectAllButtonsVisibleAndTappable(
    WidgetTester tester, DeviceSpec device, List<String> labels) {
  final safeArea = device.padding.deflateRect(Offset.zero & device.size);

  for (final label in labels) {
    final finder = find.widgetWithText(ElevatedButton, label);
    expect(finder, findsOneWidget, reason: '"$label" is not in the tree');

    final rect = tester.getRect(finder);
    expect(
      safeArea.inflate(0.5).contains(rect.topLeft) &&
          safeArea.inflate(0.5).contains(rect.bottomRight),
      isTrue,
      reason: '"$label" at $rect is outside the visible safe area $safeArea '
          'on $device',
    );

    // Throws / warns if the centre is obscured; hitTestable() makes it fail.
    expect(find.widgetWithText(ElevatedButton, label).hitTestable(),
        findsOneWidget,
        reason: '"$label" cannot be tapped on $device');
  }
}

void main() {
  for (final device in allDevices) {
    for (final rows in [1, 3, 5]) {
      for (final synced in [true, false]) {
        testWidgets(
            '$rows rows of buttons all fit on $device '
            '(${synced ? 'NTP synced' : 'no NTP'})', (tester) async {
          setDevice(tester, device);
          await pumpApp(tester,
              buttons: migraineButtons, rows: rows, ntpSynced: synced);

          // A RenderFlex overflow is reported as an exception by the
          // framework.
          expect(tester.takeException(), isNull);
          expectAllButtonsVisibleAndTappable(tester, device, migraineButtons);

          await unmountApp(tester);
        });
      }
    }
  }

  testWidgets('event list keeps some room on iPhone 15 Pro landscape',
      (tester) async {
    setDevice(tester, iPhone15ProLandscape);
    await pumpApp(tester, buttons: migraineButtons, rows: 5);

    final list = tester.getRect(find.byType(ListView));
    expect(list.height, greaterThan(0));

    await unmountApp(tester);
  });

  testWidgets('buttons at the bottom also fit on iPhone 15 Pro landscape',
      (tester) async {
    setDevice(tester, iPhone15ProLandscape);
    await pumpApp(tester,
        buttons: migraineButtons,
        rows: 5,
        extraPrefs: {'buttonSectionLocation': 'ButtonLocation.bottom'});

    expect(tester.takeException(), isNull);
    expectAllButtonsVisibleAndTappable(
        tester, iPhone15ProLandscape, migraineButtons);

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
