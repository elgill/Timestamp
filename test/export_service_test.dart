import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/services/export_service.dart';
import 'package:timestamp/utils/time_utils.dart';

void main() {
  group('convertEventsToPlainText', () {
    final morning = DateTime(2026, 3, 5, 9, 30, 15, 200);
    final evening = DateTime(2026, 3, 5, 21, 0);
    final nextDay = DateTime(2026, 3, 6, 8, 0);

    String t(DateTime time) => formatAbsoluteTime(time, TimeFormat.local24Hour);

    test('no events is just the frame', () {
      expect(convertEventsToPlainText([], TimeFormat.local24Hour),
          'Timestamp Event Log\n------------------------\n');
    });

    test('exact layout with one described event', () {
      final text = convertEventsToPlainText(
          [Event(morning, 5, description: 'Aura', color: PredefinedColor.red)],
          TimeFormat.local24Hour);
      expect(
          text,
          'Timestamp Event Log\n'
          '------------------------\n'
          '2026-03-05\n'
          '\n'
          'Aura\n'
          '${t(morning)}\n'
          '------------------------\n');
    });

    test('an event with no description prints only its time', () {
      final lines = convertEventsToPlainText(
              [Event(morning, 5)], TimeFormat.local24Hour)
          .split('\n');
      expect(lines.sublist(2, 5), ['2026-03-05', '', t(morning)]);
    });

    test('events on one day share a heading, new days get their own', () {
      final text = convertEventsToPlainText(
          [Event(nextDay, 1), Event(evening, 1), Event(morning, 1)],
          TimeFormat.local24Hour);
      expect('2026-03-05'.allMatches(text).length, 1);
      expect('2026-03-06'.allMatches(text).length, 1);
      // Keeps the order it was given (newest first in the app).
      expect(text.indexOf('2026-03-06'), lessThan(text.indexOf('2026-03-05')));
      expect(text.indexOf(t(evening)), lessThan(text.indexOf(t(morning))));
    });

    test('accuracy is left out by default', () {
      final text = convertEventsToPlainText(
          [Event(morning, 5), Event(evening, -1)], TimeFormat.local24Hour);
      expect(text, isNot(contains('±')));
      expect(text, isNot(contains('Accuracy')));
    });

    test('accuracy lines when requested', () {
      final text = convertEventsToPlainText(
          [Event(morning, 5), Event(evening, 0), Event(nextDay, -1)],
          TimeFormat.local24Hour,
          includeAccuracy: true);
      expect(text, contains('±5ms'));
      expect(text, contains('±0ms'));
      expect(text, contains('Accuracy: Unknown'));
    });

    test('UTC format groups by the UTC day', () {
      final late = DateTime.utc(2026, 3, 5, 23, 30).toLocal();
      final early = DateTime.utc(2026, 3, 6, 0, 30).toLocal();
      final text = convertEventsToPlainText(
          [Event(early, 1), Event(late, 1)], TimeFormat.utc24Hour);
      expect(text, contains('2026-03-05'));
      expect(text, contains('2026-03-06'));
      expect(text, contains('23:30:00.0 UTC'));
      expect(text, contains('00:30:00.0 UTC'));
    });
  });

  group('convertEventsToCsv', () {
    test('header only with no events', () {
      expect(convertEventsToCsv([]), 'Date,Description\n');
    });

    test('one quoted row per event', () {
      final time = DateTime(2026, 3, 5, 9, 30);
      expect(convertEventsToCsv([Event(time, 1, description: 'Aura, mild')]),
          'Date,Description\n"${time.toIso8601String()}","Aura, mild"\n');
    });
  });
}
