import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';

void main() {
  group('Event JSON', () {
    test('round trips every field', () {
      final event = Event(DateTime(2026, 3, 5, 14, 7, 9, 123, 456), 42,
          description: 'Aura "quoted", with comma', color: PredefinedColor.purple);
      final restored = Event.fromJson(event.toJson());

      expect(restored, event);
      expect(restored.time.microsecond, 456);
    });

    test('keeps the unknown-accuracy marker', () {
      expect(Event.fromJson(Event(DateTime(2026), -1).toJson()).precision, -1);
    });

    test('round trips a UTC time as the same instant', () {
      final event = Event(DateTime.utc(2026, 3, 5, 23, 59, 59), 1);
      final restored = Event.fromJson(event.toJson());
      expect(restored.time.isUtc, isTrue);
      expect(restored.time, event.time);
    });

    test('reads events saved before colors existed', () {
      final restored = Event.fromJson(jsonEncode({
        'time': '2024-01-02T03:04:05.000',
        'precision': 7,
        'description': 'old',
      }));
      expect(restored.color, PredefinedColor.defaultColor);
      expect(restored.description, 'old');
    });

    for (final color in [9, -1, 'red', null]) {
      test('a stored color of $color falls back to the default', () {
        final restored = Event.fromJson(jsonEncode({
          'time': '2024-01-02T03:04:05.000',
          'precision': 7,
          'description': 'kept',
          'color': color,
        }));
        expect(restored.color, PredefinedColor.defaultColor);
        expect(restored.description, 'kept');
      });
    }

    test('reads events saved before descriptions existed', () {
      final restored = Event.fromJson(jsonEncode({
        'time': '2024-01-02T03:04:05.000',
        'precision': 7,
        'description': null,
      }));
      expect(restored.description, '');
    });

    test('colors are stored by enum index, so the order must not change', () {
      // Reordering PredefinedColor would recolor every saved event.
      expect(PredefinedColor.values.map((c) => c.name), [
        'defaultColor',
        'red',
        'green',
        'orange',
        'purple',
      ]);
    });
  });

  group('Event equality', () {
    final time = DateTime(2026, 1, 1);
    final base = Event(time, 1, description: 'a', color: PredefinedColor.red);

    test('equal when every field matches', () {
      final same = Event(time, 1, description: 'a', color: PredefinedColor.red);
      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    test('differs on each field', () {
      expect(base == Event(time.add(const Duration(milliseconds: 1)), 1,
          description: 'a', color: PredefinedColor.red), isFalse);
      expect(base == Event(time, 2, description: 'a', color: PredefinedColor.red),
          isFalse);
      expect(base == Event(time, 1, description: 'b', color: PredefinedColor.red),
          isFalse);
      expect(base == Event(time, 1, description: 'a', color: PredefinedColor.green),
          isFalse);
    });
  });

  group('ButtonModel', () {
    test('round trips through JSON', () {
      final model = ButtonModel('Aura', PredefinedColor.orange);
      expect(ButtonModel.fromJson(model.toJson()), model);
    });

    test('equality and hashCode use name and color', () {
      final model = ButtonModel('Aura', PredefinedColor.orange);
      final same = ButtonModel('Aura', PredefinedColor.orange);
      expect(model, same);
      expect(model.hashCode, same.hashCode);
      expect(model == ButtonModel('Nausea', PredefinedColor.orange), isFalse);
      expect(model == ButtonModel('Aura', PredefinedColor.red), isFalse);
    });
  });
}
