import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('with no custom buttons a single record button is shown',
      (tester) async {
    setDevice(tester, iPhone15ProPortrait);
    await pumpApp(tester, buttons: [], rows: 3);

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    // The recorded event shows up in the list (no description, so it is
    // displayed as a time).
    expect(
        find.descendant(of: find.byType(ListView), matching: find.byType(Text)),
        findsWidgets);

    await unmountApp(tester);
  });

  testWidgets('very short screen falls back to scrolling the buttons',
      (tester) async {
    setDevice(
        tester,
        const DeviceSpec(
            'tiny landscape', Size(600, 250), 2.0, EdgeInsets.zero));
    await pumpApp(tester, buttons: migraineButtons, rows: 5);
    expect(tester.takeException(), isNull);

    // The last row is reachable by scrolling the button section.
    final scrollable = find
        .ancestor(
            of: find.widgetWithText(ElevatedButton, 'Aura'),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Relief'), 40,
        scrollable: scrollable);
    expect(find.widgetWithText(ElevatedButton, 'Relief').hitTestable(),
        findsOneWidget);

    await unmountApp(tester);
  });
}
