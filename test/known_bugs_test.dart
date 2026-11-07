// Each test here describes the CORRECT behavior for a bug that exists in the
// app today, so each one fails. They are skipped during a normal
// `flutter test` to keep the suite green. To see them fail:
//
//   flutter test test/known_bugs_test.dart --dart-define=KNOWN_BUGS=true
//
// When you fix a bug, move its test to the matching test file and drop the
// `skip`. A test here that starts passing means the bug is gone.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/services/export_service.dart';

import 'helpers/test_app.dart';

const _skip = !bool.fromEnvironment('KNOWN_BUGS');

void main() {
  group('wrong or lost data', () {
    // Event.toJson stores local wall-clock time with no UTC offset. After a
    // change of time zone (or across the DST fall-back hour) the same string
    // is read back as a different instant.
    test('saved events identify an exact instant', skip: _skip, () {
      final saved = jsonDecode(Event(DateTime(2026, 3, 5, 14), 1).toJson());
      expect(saved['time'], matches(RegExp(r'(Z|[+-]\d\d:\d\d)$')));
    });

    // Same issue in the exported CSV dates.
    test('exported CSV dates identify an exact instant', skip: _skip, () {
      final csv = convertEventsToCsv([Event(DateTime(2026, 3, 5, 14), 1)]);
      expect(csv.split('\n')[1], matches(RegExp(r'^"[^"]*(Z|[+-]\d\d:\d\d)"')));
    });

    // Quotes in a description aren't doubled. convertEventsToCsv isn't wired
    // to any UI yet, but would produce a corrupt file when it is.
    test('CSV escapes quotes', skip: _skip, () {
      final time = DateTime.utc(2026, 3, 5);
      expect(convertEventsToCsv([Event(time, 1, description: 'a "b" c')]),
          contains('"a ""b"" c"'));
    });
  });

  group('efficiency and polish', () {
    // Both NtpService's constructor and MainScreen.initState start a sync.
    testWidgets('one NTP query at startup', skip: _skip, (tester) async {
      setDevice(tester, iPhone15ProPortrait);
      late FakeNtpService ntp;
      await pumpApp(tester,
          buttons: [], rows: 1, onNtpCreated: (service) => ntp = service);

      final requests = ntp.syncRequests;
      await unmountApp(tester);
      expect(requests, 1);
    });
  });
}
