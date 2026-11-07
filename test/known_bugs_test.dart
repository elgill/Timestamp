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
  });
}
