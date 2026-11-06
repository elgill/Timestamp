import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/widgets/auto_size_label.dart';

import 'helpers/test_app.dart';

double fontSizeOf(WidgetTester tester, String text) {
  final t = tester.widget<Text>(find.text(text));
  return t.style!.fontSize!;
}

Future<void> pumpLabel(WidgetTester tester, String text, Size box,
    {double textScale = 1}) async {
  await tester.runAsync(loadRealFonts);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox.fromSize(size: box, child: AutoSizeLabel(text)),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('short labels get the maximum size', (tester) async {
    await pumpLabel(tester, 'Aura', const Size(120, 56));
    expect(fontSizeOf(tester, 'Aura'), 20);
  });

  testWidgets('long labels wrap onto two lines instead of shrinking',
      (tester) async {
    // 'Light sensitivity' doesn't fit on one line at a large size in a
    // narrow portrait button, but fits on two.
    await pumpLabel(tester, 'Light sensitivity', const Size(90, 56));
    final size = fontSizeOf(tester, 'Light sensitivity');
    final rect = tester.getRect(find.text('Light sensitivity'));
    expect(rect.height, greaterThan(size * 1.5), reason: 'should be 2 lines');
    // The old single-line label shrank this well below 14.
    expect(size, greaterThanOrEqualTo(14));
  });

  testWidgets('words are never broken mid-word', (tester) async {
    await pumpLabel(tester, 'Photophobia', const Size(70, 56));
    final size = fontSizeOf(tester, 'Photophobia');
    expect(find.byType(FittedBox), findsNothing);
    final style = tester.widget<Text>(find.text('Photophobia')).style!;
    final painter = TextPainter(
      text: TextSpan(text: 'Photophobia', style: style.copyWith(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(70));
    painter.dispose();
  });

  testWidgets('falls back to scale-down if nothing fits', (tester) async {
    await pumpLabel(tester, 'Supercalifragilistic', const Size(30, 20));
    expect(find.byType(FittedBox), findsOneWidget);
  });

  testWidgets('respects the system text size setting', (tester) async {
    await pumpLabel(tester, 'Aura', const Size(120, 56), textScale: 2);
    final rect = tester.getRect(find.text('Aura'));
    expect(rect.height, lessThanOrEqualTo(56));
    expect(rect.width, lessThanOrEqualTo(120));
  });

  testWidgets('labels on the main screen are larger in landscape',
      (tester) async {
    await tester.runAsync(loadRealFonts);
    Future<double> sizeOn(DeviceSpec device) async {
      setDevice(tester, device);
      await pumpApp(tester, buttons: migraineButtons, rows: 5);
      final size = tester
          .widget<Text>(find.descendant(
              of: find.byType(AutoSizeLabel),
              matching: find.text('Light sensitivity')))
          .style!
          .fontSize!;
      await unmountApp(tester);
      return size;
    }

    final portrait = await sizeOn(iPhone15ProPortrait);
    final landscape = await sizeOn(iPhone15ProLandscape);
    expect(portrait, greaterThanOrEqualTo(14));
    expect(landscape, greaterThanOrEqualTo(portrait));
  });
}
