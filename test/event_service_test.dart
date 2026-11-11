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

  group('choosing the reference', () {
    test('records when, and survives a restart', () async {
      final lap = at(10);
      final service = EventService()
        ..addEvent(at(9))
        ..addEvent(lap);
      final before = DateTime.now();
      service.setReference(lap);
      expect(service.referenceEvent, same(lap));
      expect(service.referenceSetAt!.isBefore(before), isFalse);

      final restored = await reloaded();
      expect(restored.referenceEvent?.id, lap.id);
      expect(restored.referenceSetAt, isNotNull);
    });

    test('a reference never chosen has no time', () async {
      EventService().addEvent(at(9));
      expect((await reloaded()).referenceSetAt, isNull);
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

  group('upgrading from a version without ids', () {
    // Exactly what version 1.1.5 saves, and older versions before colors
    // and descriptions existed.
    const oldEvents = [
      '{"time":"2026-03-05T12:00:00.000","precision":8,"description":"Finish","color":1}',
      '{"time":"2026-03-05T10:30:00.250","precision":-1,"description":"","color":0}',
      '{"time":"2026-03-05T10:00:00.000","precision":15,"description":"Lap"}',
      '{"time":"2026-03-05T09:00:00.000","precision":12}',
    ];
    const oldReference =
        '{"time":"2026-03-05T10:00:00.000","precision":15,"description":"Lap"}';

    setUp(() => SharedPreferences.setMockInitialValues({
          'events': oldEvents,
          referenceEventKey: oldReference,
        }));

    test('every event loads with all its fields', () async {
      final restored = await reloaded();
      expect(restored.events, [
        Event(DateTime(2026, 3, 5, 12), 8,
            description: 'Finish', color: PredefinedColor.red),
        Event(DateTime(2026, 3, 5, 10, 30, 0, 250), -1),
        Event(DateTime(2026, 3, 5, 10), 15, description: 'Lap'),
        Event(DateTime(2026, 3, 5, 9), 12),
      ]);
    });

    test('the reference stays on the same event', () async {
      final restored = await reloaded();
      expect(restored.referenceEvent, same(restored.events[2]));
      expect(restored.referenceEvent?.description, 'Lap');
    });

    test('each event gets a different id', () async {
      final ids = (await reloaded()).events.map((e) => e.id).toSet();
      expect(ids, hasLength(oldEvents.length));
    });

    test('the new ids are saved straight away', () async {
      await reloaded();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('events')!;
      expect(saved, hasLength(oldEvents.length));
      for (final json in saved) {
        expect(Event.hasId(jsonDecode(json)), isTrue, reason: json);
      }
    });

    test('ids stay the same from one launch to the next', () async {
      final first = (await reloaded()).events.map((e) => e.id).toList();
      final second = (await reloaded()).events.map((e) => e.id).toList();
      expect(second, first);
    });

    test('the saved reference has the same id as its event', () async {
      final restored = await reloaded();
      await reloaded();
      final prefs = await SharedPreferences.getInstance();
      final reference = Event.fromJson(prefs.getString(referenceEventKey)!);
      expect(reference.id, restored.referenceEvent!.id);
    });

    test('a log that already has ids is not saved again', () async {
      final event = at(9, 'a');
      SharedPreferences.setMockInitialValues({
        'events': [event.toJson()],
      });
      final service = await reloaded();
      final prefs = await SharedPreferences.getInstance();
      // A save would also write the reference.
      expect(prefs.getString(referenceEventKey), isNull);
      expect(service.events.single.id, event.id);
    });
  });

  group('ids', () {
    test('of two identical events, the reference is the one with its id',
        () async {
      final first = at(9, 'twin');
      final second = at(9, 'twin');
      SharedPreferences.setMockInitialValues({
        'events': [first.toJson(), second.toJson()],
        referenceEventKey: second.toJson(),
      });
      final restored = await reloaded();
      expect(restored.referenceEvent?.id, second.id);
      expect(restored.referenceEvent, same(restored.events.last));
    });

    test('a reference whose description changed is still found by id',
        () async {
      final event = at(9, 'renamed');
      SharedPreferences.setMockInitialValues({
        'events': [at(9, 'other').toJson(), event.toJson()],
        referenceEventKey: Event(event.time, event.precision,
                id: event.id, description: 'old name')
            .toJson(),
      });
      final restored = await reloaded();
      expect(restored.referenceEvent?.id, event.id);
      expect(restored.referenceEvent?.description, 'renamed');
    });

    test('ids survive a restart', () async {
      final event = at(9);
      EventService().addEvent(event);
      expect((await reloaded()).events.single.id, event.id);
    });
  });
}
