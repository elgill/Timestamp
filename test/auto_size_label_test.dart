import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Lines and size of the label as rendered (style size x any FittedBox
/// scale), and whether every word fits the box width on its own.
({int lines, double size, bool wordsFit, bool cutOff}) rendered(
    WidgetTester tester, String text, Size box) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final style = paragraph.text.style!;
  final scale = tester.getRect(find.text(text)).width / paragraph.size.width;
  final fitted = find.byType(FittedBox).evaluate().isNotEmpty;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: fitted ? 1 : 2,
  )..layout(maxWidth: fitted ? double.infinity : box.width);
  final lines = painter.computeLineMetrics().length;
  final cutOff = painter.didExceedMaxLines;
  painter.dispose();
  final wordsFit = text.split(' ').every((word) {
    final p = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final ok = p.width * scale <= box.width;
    p.dispose();
    return ok;
  });
  return (
    lines: lines,
    size: style.fontSize! * scale,
    wordsFit: wordsFit,
    cutOff: cutOff,
  );
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

  group('labels too big for the minimum size', () {
    // About the width of a button in a 5-button row on a 375pt-wide phone.
    const box = Size(63, 56);

    testWidgets('wrap between words instead of shrinking onto one line',
        (tester) async {
      // 'AMIODARONE' alone is too wide at 10pt.
      await pumpLabel(tester, 'AMIODARONE 300', box);
      expect(find.byType(FittedBox), findsNothing);
      final r = rendered(tester, 'AMIODARONE 300', box);
      expect(r.lines, 2);
      expect(r.wordsFit, isTrue);
      expect(r.size, lessThan(10));
      // On one line it was squeezed to about 7.5pt.
      expect(r.size, greaterThan(9));
    });

    testWidgets('three or more words still wrap onto two lines',
        (tester) async {
      for (final label in [
        'Return of spontaneous circulation',
        'Pt care transferred to ED',
        'ROSC achieved at scene',
      ]) {
        await pumpLabel(tester, label, box);
        expect(find.byType(FittedBox), findsNothing, reason: label);
        final r = rendered(tester, label, box);
        expect(r.lines, 2, reason: label);
        expect(r.wordsFit, isTrue, reason: label);
        expect(r.cutOff, isFalse, reason: label);
      }
    });

    testWidgets('a single word still scales down on one line',
        (tester) async {
      await pumpLabel(tester, 'Defibrillation', const Size(40, 56));
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('wrapping is never smaller than one line would be',
        (tester) async {
      await tester.runAsync(loadRealFonts);
      const style = TextStyle(fontSize: 10);
      for (final label in [
        'AMIODARONE 300',
        'Return of spontaneous circulation',
        'A B',
        'EPINEPHRINE 1 mg IV',
      ]) {
        for (final size in const [Size(63, 56), Size(40, 56), Size(63, 30)]) {
          final wrapped = AutoSizeLabel.wrappedFallbackFontSize(
            text: label,
            style: style,
            maxWidth: size.width,
            maxHeight: size.height,
            textScaler: TextScaler.noScaling,
            textDirection: TextDirection.ltr,
          );
          if (wrapped == null) continue;
          final p = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: TextDirection.ltr,
          )..layout();
          final oneLine = 10 *
              math.min(size.width / p.width, size.height / p.height);
          p.dispose();
          expect(wrapped, greaterThanOrEqualTo(oneLine - 0.1),
              reason: '$label in $size');
          expect(wrapped, lessThan(10), reason: '$label in $size');
        }
      }
    });

    test('single words get no wrapped size', () {
      expect(
        AutoSizeLabel.wrappedFallbackFontSize(
          text: 'Defibrillation',
          style: const TextStyle(fontSize: 10),
          maxWidth: 20,
          maxHeight: 56,
          textScaler: TextScaler.noScaling,
          textDirection: TextDirection.ltr,
        ),
        isNull,
      );
    });

    testWidgets('nothing is ever cut off or overflows', (tester) async {
      for (final size in const [Size(63, 56), Size(40, 56), Size(63, 36)]) {
        for (final label in [
          'AMIODARONE 300',
          'Return of spontaneous circulation',
          'Post-defibrillation check',
          '💉 EPINEPHRINE',
          'AMIODARONE   300',
          'Defibrillation',
        ]) {
          await pumpLabel(tester, label, size);
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.text(label));
          expect(rect.width, lessThanOrEqualTo(size.width + 0.5),
              reason: '$label in $size');
          expect(rect.height, lessThanOrEqualTo(size.height + 0.5),
              reason: '$label in $size');
          expect(rendered(tester, label, size).cutOff, isFalse,
              reason: '$label in $size');
        }
      }
    });
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
