import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/utils/button_layout.dart';

void main() {
  group('splitIntoRows', () {
    test('splits evenly and keeps order', () {
      final names = List.generate(15, (i) => '$i');
      final rows = splitIntoRows(names, 5);
      expect(rows.length, 5);
      expect(rows.every((r) => r.length == 3), isTrue);
      expect(rows.expand((r) => r).toList(), names);
    });

    test('never produces empty rows when there are fewer buttons than rows',
        () {
      final rows = splitIntoRows(['a', 'b', 'c'], 5);
      expect(rows, [
        ['a'],
        ['b'],
        ['c']
      ]);
    });

    test('uneven split keeps every button', () {
      final names = List.generate(7, (i) => '$i');
      final rows = splitIntoRows(names, 3);
      expect(rows.length, 3);
      expect(rows.expand((r) => r).toList(), names);
    });

    test('empty input', () {
      expect(splitIntoRows([], 3), isEmpty);
    });
  });

  group('ButtonSectionLayout.fit', () {
    test('uses full size buttons when there is room', () {
      final l = ButtonSectionLayout.fit(rows: 5, availableHeight: 700);
      expect(l.buttonHeight, ButtonSectionLayout.preferredButtonHeight);
      expect(l.scrollable, isFalse);
      expect(l.sectionHeight, ButtonSectionLayout.contentHeight(5, 60));
    });

    test('shrinks buttons to keep room for the list', () {
      final l = ButtonSectionLayout.fit(rows: 5, availableHeight: 320);
      expect(l.buttonHeight, lessThan(60));
      expect(l.buttonHeight,
          greaterThanOrEqualTo(ButtonSectionLayout.minButtonHeight));
      expect(320 - l.sectionHeight,
          closeTo(ButtonSectionLayout.minListHeight, 0.001));
      expect(l.scrollable, isFalse);
    });

    test('gives up list space before scrolling', () {
      final minimum = ButtonSectionLayout.contentHeight(
          5, ButtonSectionLayout.minButtonHeight);
      final l = ButtonSectionLayout.fit(rows: 5, availableHeight: minimum + 1);
      expect(l.buttonHeight, ButtonSectionLayout.minButtonHeight);
      expect(l.sectionHeight, minimum);
      expect(l.scrollable, isFalse);
    });

    test('scrolls only when minimum size buttons cannot fit', () {
      final l = ButtonSectionLayout.fit(rows: 5, availableHeight: 120);
      expect(l.scrollable, isTrue);
      expect(l.sectionHeight, 120);
      expect(l.buttonHeight, ButtonSectionLayout.minButtonHeight);
    });

    test('section never exceeds the available height', () {
      for (double h = 0; h <= 800; h += 7) {
        for (int rows = 1; rows <= 5; rows++) {
          final l = ButtonSectionLayout.fit(
              rows: rows, availableHeight: h, sectionPadding: 8);
          expect(l.sectionHeight, lessThanOrEqualTo(h + 1e-9),
              reason: 'rows=$rows h=$h $l');
          expect(l.buttonHeight,
              greaterThanOrEqualTo(ButtonSectionLayout.minButtonHeight));
          expect(l.buttonHeight,
              lessThanOrEqualTo(ButtonSectionLayout.preferredButtonHeight));
        }
      }
    });

    test('unbounded height uses the preferred size', () {
      final l =
          ButtonSectionLayout.fit(rows: 3, availableHeight: double.infinity);
      expect(l.buttonHeight, ButtonSectionLayout.preferredButtonHeight);
    });
  });
}
