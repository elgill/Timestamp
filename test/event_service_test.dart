import 'dart:convert';

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

    /// The events at the positions flagged true.
    List<Event> flagged(List<bool> flags) => [
          for (var i = 0; i < flags.length; i++)
            if (flags[i]) service.events[i]
        ];

    setUp(() {
      service = EventService()
        ..addEvent(at(10, 'reference'))
        ..addEvent(at(11, 'middle'))
        ..addEvent(at(9, 'oldest'))
        ..addEvent(at(12, 'newest'));
      // Newest first: newest, middle, reference, oldest.
    });

    test('removes exactly the selected events', () {
      service.deleteSelectedEvents(flagged([true, false, false, true]));
      expect(service.events.map((e) => e.description), ['middle', 'reference']);
    });

    test('nothing selected changes nothing', () {
      service.deleteSelectedEvents(flagged([false, false, false, false]));
      expect(service.events, hasLength(4));
      expect(service.referenceEvent?.description, 'reference');
    });

    test('keeps the reference if it survives', () {
      service.deleteSelectedEvents(flagged([true, true, false, true]));
      expect(service.referenceEvent?.description, 'reference');
    });

    test('deleting the reference falls back to the oldest event', () {
      service.deleteSelectedEvents(flagged([false, false, true, false]));
      expect(service.referenceEvent?.description, 'oldest');
    });

    test('fallback never lands on an event deleted in the same pass', () {
      service.deleteSelectedEvents(flagged([false, false, true, true]));
      expect(service.referenceEvent?.description, 'middle');
    });

    test('deleting everything clears the reference', () {
      service.deleteSelectedEvents(flagged([true, true, true, true]));
      expect(service.events, isEmpty);
      expect(service.referenceEvent, isNull);
    });

    test('deleting a copy of an event leaves the original', () {
      final original = at(8, 'twin');
      final copy = at(8, 'twin');
      service
        ..addEvent(original)
        ..addEvent(copy)
        ..deleteSelectedEvents([copy]);
      expect(service.events.where((e) => identical(e, original)), hasLength(1));
      expect(service.events.where((e) => identical(e, copy)), isEmpty);
    });

    test('deleting a copy of the reference keeps the reference', () {
      final reference = at(9, 'twin');
      final copy = at(9, 'twin');
      final other = EventService()
        ..addEvent(reference)
        ..addEvent(copy)
        ..addEvent(at(8, 'oldest'))
        ..deleteSelectedEvents([copy]);
      expect(other.referenceEvent, same(reference));
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
      final newer = at(10, 'b');
      EventService()
        ..addEvent(at(9, 'a'))
        ..addEvent(newer)
        ..deleteSelectedEvents([newer]);
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

    test('one unreadable event does not lose the rest', () async {
      final good = at(9, 'good');
      SharedPreferences.setMockInitialValues({
        'events': [good.toJson(), '{not json', '{"time":"bad"}'],
      });
      expect((await reloaded()).events, [good]);
    });

    test('an unknown color keeps the event, through a save too', () async {
      final json = jsonDecode(at(9, 'kept').toJson()) as Map<String, dynamic>;
      SharedPreferences.setMockInitialValues({
        'events': [
          jsonEncode({...json, 'color': 9})
        ],
      });
      final restored = await reloaded();
      expect(restored.events.single.description, 'kept');

      await restored.saveData();
      expect((await reloaded()).events.single.description, 'kept');
    });

    test('the reference is the same object as its event after a restart',
        () async {
      EventService()
        ..addEvent(at(9, 'a'))
        ..addEvent(at(10, 'b'));
      final restored = await reloaded();
      expect(restored.referenceEvent, same(restored.events.last));
    });

    test('a reference that drifted from its event is matched back to it',
        () async {
      final event = at(9, 'renamed');
      SharedPreferences.setMockInitialValues({
        'events': [at(10, 'newer').toJson(), event.toJson()],
        referenceEventKey: at(9, 'old name').toJson(),
      });
      final restored = await reloaded();
      expect(restored.referenceEvent, same(restored.events.last));
      expect(restored.referenceEvent?.description, 'renamed');
    });

    test('of two events at the same time, the exact match is the reference',
        () async {
      SharedPreferences.setMockInitialValues({
        'events': [at(9, 'breakfast').toJson(), at(9, 'meds').toJson()],
        referenceEventKey: at(9, 'meds').toJson(),
      });
      final restored = await reloaded();
      expect(restored.referenceEvent, same(restored.events.last));
      expect(restored.referenceEvent?.description, 'meds');
    });

    test('a reference to a deleted event falls back to the oldest', () async {
      SharedPreferences.setMockInitialValues({
        'events': [at(10, 'newer').toJson(), at(9, 'oldest').toJson()],
        referenceEventKey: at(8, 'deleted').toJson(),
      });
      expect((await reloaded()).referenceEvent?.description, 'oldest');
    });

    test('an unreadable reference falls back to the oldest', () async {
      SharedPreferences.setMockInitialValues({
        'events': [at(10, 'newer').toJson(), at(9, 'oldest').toJson()],
        referenceEventKey: '{not json',
      });
      expect((await reloaded()).referenceEvent?.description, 'oldest');
    });

    test('a saved reference with no events left is cleared', () async {
      SharedPreferences.setMockInitialValues({
        referenceEventKey: at(8, 'deleted').toJson(),
      });
      expect((await reloaded()).referenceEvent, isNull);
    });

    test('a first launch has no events and no reference', () async {
      final service = await reloaded();
      expect(service.events, isEmpty);
      expect(service.referenceEvent, isNull);
    });
  });
}
