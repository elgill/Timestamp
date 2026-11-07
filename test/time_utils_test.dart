import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/utils/time_utils.dart';

void main() {
  group('formatAbsoluteTime', () {
    final afternoon = DateTime(2026, 3, 5, 14, 7, 9, 123);
    final tz = afternoon.timeZoneName;

    test('local 24 hour', () {
      expect(formatAbsoluteTime(afternoon, TimeFormat.local24Hour),
          '14:07:09.1 $tz');
    });

    test('local 12 hour afternoon', () {
      expect(formatAbsoluteTime(afternoon, TimeFormat.local12Hour),
          '2:07:09.1 PM $tz');
    });

    test('12 hour midnight and noon', () {
      final midnight = DateTime(2026, 3, 5);
      final noon = DateTime(2026, 3, 5, 12);
      expect(formatAbsoluteTime(midnight, TimeFormat.local12Hour),
          '12:00:00.0 AM ${midnight.timeZoneName}');
      expect(formatAbsoluteTime(noon, TimeFormat.local12Hour),
          '12:00:00.0 PM ${noon.timeZoneName}');
    });

    test('UTC format converts a local time', () {
      final utc = DateTime.utc(2026, 3, 5, 23, 30, 15, 900);
      expect(formatAbsoluteTime(utc.toLocal(), TimeFormat.utc24Hour),
          '23:30:15.9 UTC');
    });

    test('tenths are truncated, never rounded up', () {
      final time = DateTime(2026, 3, 5, 14, 7, 9, 999);
      expect(formatAbsoluteTime(time, TimeFormat.local24Hour),
          '14:07:09.9 ${time.timeZoneName}');
      expect(formatAbsoluteTime(time, TimeFormat.local12Hour),
          '2:07:09.9 PM ${time.timeZoneName}');
      expect(formatAbsoluteTime(time, TimeFormat.utc24Hour),
          endsWith(':09.9 UTC'));
    });
  });

  group('formatRelativeTime', () {
    final reference = DateTime.utc(2026, 1, 1);
    String after(Duration d) => formatRelativeTime(reference.add(d), reference);

    test('no difference has no sign', () {
      expect(after(Duration.zero), '00:00:00.0');
    });

    test('later times are positive, earlier negative', () {
      expect(after(const Duration(seconds: 5)), '+00:00:05.0');
      expect(after(const Duration(seconds: -5)), '-00:00:05.0');
    });

    test('hours, minutes, seconds and tenths', () {
      expect(
          after(const Duration(
              hours: 23, minutes: 59, seconds: 58, milliseconds: 950)),
          '+23:59:58.9');
    });

    test('below one tenth still keeps its sign', () {
      expect(after(const Duration(milliseconds: 99)), '+00:00:00.0');
    });

    test('days', () {
      expect(after(const Duration(days: 1)), '+1d 00:00:00.0');
      expect(after(const Duration(days: 364, hours: 2)), '+364d 02:00:00.0');
    });

    test('years', () {
      expect(after(const Duration(days: 365)), '+1y 00:00:00.0');
      expect(after(const Duration(days: 365 * 2 + 3, minutes: 1)),
          '+2y 3d 00:01:00.0');
      expect(after(const Duration(days: -366)), '-1y 1d 00:00:00.0');
    });
  });

  group('calendarDay', () {
    // Each format has to give the day it was asked for whatever time zone
    // the tests run in, so these only use times that pin that day down.
    test('UTC format uses the UTC day', () {
      expect(calendarDay(DateTime.utc(2026, 3, 2, 23, 30), TimeFormat.utc24Hour),
          DateTime.utc(2026, 3, 2));
      expect(calendarDay(DateTime.utc(2026, 3, 3, 0, 30), TimeFormat.utc24Hour),
          DateTime.utc(2026, 3, 3));
    });

    test('UTC format converts a local time first', () {
      final local = DateTime.utc(2026, 3, 2, 23, 30).toLocal();
      expect(calendarDay(local, TimeFormat.utc24Hour), DateTime.utc(2026, 3, 2));
    });

    test('local formats use the local day', () {
      for (final format in [TimeFormat.local12Hour, TimeFormat.local24Hour]) {
        expect(calendarDay(DateTime(2026, 3, 5, 0, 30), format),
            DateTime.utc(2026, 3, 5));
        expect(calendarDay(DateTime(2026, 3, 5, 23, 30), format),
            DateTime.utc(2026, 3, 5));
      }
    });

    test('formatDate shows that day for every format', () {
      final day = calendarDay(DateTime.utc(2026, 3, 2, 12), TimeFormat.utc24Hour);
      for (final format in TimeFormat.values) {
        expect(formatDate(day, format), 'Mon Mar 02, 2026');
      }
    });
  });

  group('formatDate', () {
    test('local formats use the local calendar day', () {
      final time = DateTime(2026, 3, 5, 23, 59);
      expect(formatDate(time, TimeFormat.local24Hour), 'Thu Mar 05, 2026');
      expect(formatDate(time, TimeFormat.local12Hour), 'Thu Mar 05, 2026');
    });

    test('UTC format uses the UTC calendar day', () {
      // Whatever zone the tests run in, this is Mar 5 in UTC.
      final time = DateTime.utc(2026, 3, 5, 0, 30).toLocal();
      expect(formatDate(time, TimeFormat.utc24Hour), 'Thu Mar 05, 2026');
    });
  });
}
