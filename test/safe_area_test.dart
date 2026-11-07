// Pages other than the main screen must keep their content clear of what
// cuts into the sides of the screen: the camera in landscape, and the status
// pill on iPhone Duo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

const device = iPhone15ProLandscape;

void expectInsideSides(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(device.padding.left));
  expect(rect.right,
      lessThanOrEqualTo(device.size.width - device.padding.right));
}

void main() {
  Future<void> open(WidgetTester tester, Finder button) async {
    setDevice(tester, device);
    await pumpApp(tester, buttons: ['Aura'], rows: 1);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('settings', (tester) async {
    await open(tester, find.byIcon(Icons.settings));
    expectInsideSides(tester, find.text('Time Server'));
    expectInsideSides(tester, find.byType(Switch).first);
    await unmountApp(tester);
  });

  testWidgets('help', (tester) async {
    await open(tester, find.byTooltip('Help'));
    expectInsideSides(tester, find.byType(ListView));
    await unmountApp(tester);
  });
}
