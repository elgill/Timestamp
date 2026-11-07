import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/services/event_service.dart';

Event at(int hour, [String description = '']) =>
    Event(DateTime(2026, 3, 5, hour), 1, description: description);

/// A new service reading what the previous one saved, like an app restart.
Future<EventService> reloaded() async {
  await pumpEventQueue();
  final service = EventService();
  await service.loadData();
  return service;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('adding', () {
    test('keeps events sorted newest first', () {
      final service = EventService()
        ..addEvent(at(9))
        ..addEvent(at(12))
        ..addEvent(at(10));
      expect(service.events.map((e) => e.time.hour), [12, 10, 9]);
    });

    test('the first event becomes the reference and stays it', () {
      final first = at(9);
      final service = EventService()
        ..addEvent(first)
        ..addEvent(at(12));
      expect(service.referenceEvent, same(first));
    });

    test('manual events go through the same path', () {
      final service = EventService()
        ..addEvent(at(12))
        ..manualAddEvent(at(9));
      expect(service.events.map((e) => e.time.hour), [12, 9]);
      expect(service.referenceEvent, at(12));
    });
  });

  group('deleting selected', () {
    late EventService service;

    setUp(() {
      service = EventService()
        ..addEvent(at(10, 'reference'))
        ..addEvent(at(11, 'middle'))
        ..addEvent(at(9, 'oldest'))
        ..addEvent(at(12, 'newest'));
      // Newest first: newest, middle, reference, oldest.
    });

    test('removes exactly the selected indexes', () {
      service.deleteSelectedEvents([true, false, false, true]);
      expect(service.events.map((e) => e.description), ['middle', 'reference']);
    });

    test('nothing selected changes nothing', () {
      service.deleteSelectedEvents([false, false, false, false]);
      expect(service.events, hasLength(4));
      expect(service.referenceEvent?.description, 'reference');
    });

    test('keeps the reference if it survives', () {
      service.deleteSelectedEvents([true, true, false, true]);
      expect(service.referenceEvent?.description, 'reference');
    });

    test('deleting the reference falls back to the oldest event', () {
      service.deleteSelectedEvents([false, false, true, false]);
      expect(service.referenceEvent?.description, 'oldest');
    });

    test('fallback never lands on an event deleted in the same pass', () {
      service.deleteSelectedEvents([false, false, true, true]);
      expect(service.referenceEvent?.description, 'middle');
    });

    test('deleting everything clears the reference', () {
      service.deleteSelectedEvents([true, true, true, true]);
      expect(service.events, isEmpty);
      expect(service.referenceEvent, isNull);
    });
  });

  group('persistence', () {
    test('adding saves events and reference without an explicit save', () async {
      EventService()
        ..addEvent(at(9, 'a'))
        ..addEvent(at(10, 'b'));
      final restored = await reloaded();
      expect(restored.events.map((e) => e.description), ['b', 'a']);
      expect(restored.referenceEvent?.description, 'a');
    });

    test('fields other than time survive a restart', () async {
      final event = Event(DateTime(2026, 3, 5, 9, 1, 2, 345), -1,
          description: 'x', color: PredefinedColor.green);
      EventService().addEvent(event);
      expect((await reloaded()).events.single, event);
    });

    test('deleting selected events is saved', () async {
      EventService()
        ..addEvent(at(9, 'a'))
        ..addEvent(at(10, 'b'))
        ..deleteSelectedEvents([true, false]);
      expect((await reloaded()).events.single.description, 'a');
    });

    test('deleting everything removes the saved reference', () async {
      EventService()
        ..addEvent(at(9))
        ..deleteAllEvents();
      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(referenceEventKey), isNull);
      expect(prefs.getStringList('events'), isEmpty);
      expect((await reloaded()).referenceEvent, isNull);
    });

    test('a first launch has no events and no reference', () async {
      final service = await reloaded();
      expect(service.events, isEmpty);
      expect(service.referenceEvent, isNull);
    });
  });
}
