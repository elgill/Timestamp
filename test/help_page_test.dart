import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/main_screen.dart';
import 'package:timestamp/pages/help_page.dart';
import 'package:timestamp/utils/time_utils.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('the help button opens the help page and back returns',
      (tester) async {
    setDevice(tester, iPhone15ProPortrait);
    await pumpApp(tester, buttons: ['Aura'], rows: 1);

    final helpButton = tester.getRect(find.byIcon(Icons.help_outline));
    expect(helpButton.center.dx, lessThan(iPhone15ProPortrait.size.width / 2));

    await tester.tap(find.byIcon(Icons.help_outline));
    await settle(tester);

    expect(find.byType(HelpPage), findsOneWidget);
    expect(find.text('Record an event'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);

    expect(find.byType(HelpPage), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('the help button is reachable with the clock in the app bar',
      (tester) async {
    setDevice(tester, iPhoneSELandscape);
    await pumpApp(tester, buttons: ['Aura'], rows: 1);

    await tester.tap(find.byIcon(Icons.help_outline));
    await settle(tester);

    expect(find.byType(HelpPage), findsOneWidget);
    await unmountApp(tester);
  });

  test('the relative time example matches what the app shows', () {
    DateTime parse(String clock) => DateTime.parse('2026-01-01 $clock');
    final examples = HelpPage.relativeTimeExample;
    final reference =
        parse(examples.firstWhere((e) => e.label == 'Reference').clock);

    for (final example in examples) {
      expect(formatRelativeTime(parse(example.clock), reference),
          example.relative);
    }
  });

  testWidgets('relative time comes right after recording', (tester) async {
    setDevice(tester, iPhoneSEPortrait);
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));

    final top = tester.getTopLeft(find.text('Relative time')).dy;
    expect(
        top, greaterThan(tester.getTopLeft(find.text('Record an event')).dy));
    expect(top, lessThan(iPhoneSEPortrait.size.height));
  });

  for (final device in [
    iPadSlideOver,
    iPhoneSEPortrait,
    iPhone15ProLandscape,
    iPhoneSEPortrait.withTextScale(1.3),
  ]) {
    testWidgets('every help topic can be scrolled to on $device',
        (tester) async {
      setDevice(tester, device);
      await tester.pumpWidget(const MaterialApp(home: HelpPage()));

      await tester.scrollUntilVisible(find.text('More settings'), 200);

      expect(find.text('More settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('only iOS explains Shortcuts and the Action button',
      (tester) async {
    setDevice(tester, iPhoneSEPortrait);
    const title = 'Shortcuts, Siri and the Action button';

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    await tester.scrollUntilVisible(find.text(title), 200);
    expect(find.textContaining('less precise than a tap'), findsOneWidget);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
        const MaterialApp(home: HelpPage(key: ValueKey('android'))));
    expect(find.text(title, skipOffstage: false), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
