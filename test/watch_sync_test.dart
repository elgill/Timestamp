import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/services/watch_protocol.dart';
import 'package:timestamp/services/watch_sync_service.dart';

/// The examples both this and the watch app's tests check against.
String fixture(String name) =>
    File('test/fixtures/watch/$name').readAsStringSync();

DateTime fromMillis(int millis) => DateTime.fromMillisecondsSinceEpoch(millis);

Event at(int hour, [String description = '']) =>
    Event(DateTime(2026, 3, 5, hour), 1, description: description);

/// A delivery from the watch, as the iOS side keeps it in the inbox.
Map<String, Object> delivery(int sequence,
        {List<Event> added = const [], List<String> deleted = const []}) =>
    {
      'sequence': sequence,
      'json': jsonEncode({
        'added': added.map(WatchProtocol.eventToMap).toList(),
        'deleted': deleted,
      }),
    };

/// A new service reading what the previous one saved, like an app restart.
Future<EventService> reloaded() async {
  await pumpEventQueue();
  final service = EventService();
  await service.loadData();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the messages', () {
    test('the context is what the watch reads', () {
      final reference = Event(fromMillis(1794164500000), -1,
          id: '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d');
      final json = WatchProtocol.context(
        events: [
          Event(fromMillis(1794164602470), 40,
              id: '6f1c1a0e-3b55-4c9e-9f5a-0b8e5d2b1a01',
              description: 'Lap',
              color: PredefinedColor.orange),
          reference,
        ],
        reference: reference,
        buttons: [
          ButtonModel('Start', PredefinedColor.green),
          ButtonModel('Lap', PredefinedColor.orange),
        ],
        timeFormat: TimeFormat.local12Hour,
        importedIds: ['A1B2C3D4-0000-4000-8000-000000000001'],
      );
      expect(jsonDecode(json), jsonDecode(fixture('context.json')));
    });

    test('what the watch sends is read', () {
      final changes = WatchChanges.parse(fixture('changes.json'));
      expect(changes.added.single.id, 'A1B2C3D4-0000-4000-8000-000000000001');
      expect(changes.added.single, Event(fromMillis(1794164602470), -1,
          description: 'Lap', color: PredefinedColor.orange));
      expect(changes.deletedIds, ['A1B2C3D4-0000-4000-8000-000000000002']);
    });

    test('times from the watch are in local time, like the phone\'s', () {
      final event = WatchChanges.parse(fixture('changes.json')).added.single;
      expect(event.time.isUtc, isFalse);
    });

    test('an event keeps its time to the microsecond on the way out', () {
      final event = Event(DateTime(2026, 3, 5, 9, 0, 0, 123, 456), 1);
      final back = WatchProtocol.eventFromMap(
          jsonDecode(jsonEncode(WatchProtocol.eventToMap(event))));
      expect(back.time, event.time);
      expect(back.id, event.id);
    });

    test('one unreadable event does not lose the rest', () {
      final changes = WatchChanges.parse(jsonEncode({
        'added': [
          {'id': 'a', 'time': 'bad'},
          {'id': 'b', 'time': 1000, 'precision': 5, 'description': 'ok'},
        ],
      }));
      expect(changes.added.map((e) => e.id), ['b']);
      expect(changes.deletedIds, isEmpty);
    });

    test('an unknown color from the watch becomes the default', () {
      final changes = WatchChanges.parse(jsonEncode({
        'added': [
          {'id': 'a', 'time': 1000, 'precision': 5, 'color': 42}
        ],
      }));
      expect(changes.added.single.color, PredefinedColor.defaultColor);
    });

    test('the watch gets only the newest events', () {
      final events = [
        for (var i = 0; i < WatchProtocol.recentEventCount + 20; i++)
          Event(fromMillis(1794164602470 - i * 1000), 1)
      ];
      final json = jsonDecode(WatchProtocol.context(
          events: events,
          reference: events.last,
          buttons: [],
          timeFormat: TimeFormat.local24Hour,
          importedIds: []));
      expect(json['events'], hasLength(WatchProtocol.recentEventCount));
      expect(json['events'].first['id'], events.first.id);
      // The reference is sent even when it's older than those.
      expect(json['reference']['id'], events.last.id);
    });
  });

  group('taking in the watch\'s changes', () {
    test('adds its events in order', () async {
      final service = EventService()
        ..addEvent(at(9))
        ..addEvent(at(12));
      await service.applyWatchChanges([
        WatchChanges(added: [at(10, 'watch'), at(13, 'watch')])
      ]);
      expect(service.events.map((e) => e.time.hour), [13, 12, 10, 9]);
    });

    test('an event delivered twice is added once', () async {
      final lap = at(10, 'Lap');
      final service = EventService();
      await service.applyWatchChanges([
        WatchChanges(added: [lap]),
        WatchChanges(added: [lap]),
      ]);
      await service.applyWatchChanges([
        WatchChanges(added: [lap])
      ]);
      expect(service.events, hasLength(1));
    });

    test('deletes by id, leaving an identical event alone', () async {
      final lap = at(10, 'Lap');
      final twin = at(10, 'Lap');
      final service = EventService()
        ..addEvent(at(9))
        ..addEvent(twin);
      await service.applyWatchChanges([
        WatchChanges(added: [lap]),
        WatchChanges(deletedIds: [lap.id]),
      ]);
      expect(service.events.where((e) => identical(e, twin)), hasLength(1));
      expect(service.events.map((e) => e.id), isNot(contains(lap.id)));
    });

    test('keeps the reference', () async {
      final reference = at(9);
      final service = EventService()..addEvent(reference);
      await service.applyWatchChanges([
        WatchChanges(added: [at(8), at(10)])
      ]);
      expect(service.referenceEvent, same(reference));
    });

    test('without events, the oldest from the watch is the reference',
        () async {
      final service = EventService();
      await service.applyWatchChanges([
        WatchChanges(added: [at(10), at(8), at(9)])
      ]);
      expect(service.referenceEvent?.time.hour, 8);
    });

    test('deleting the reference falls back to the oldest', () async {
      final lap = at(9);
      final service = EventService();
      await service.applyWatchChanges([
        WatchChanges(added: [lap, at(10), at(11)])
      ]);
      expect(service.referenceEvent, same(lap));
      await service.applyWatchChanges([
        WatchChanges(deletedIds: [lap.id])
      ]);
      expect(service.referenceEvent?.time.hour, 10);
    });

    test('deleting an event that isn\'t here changes nothing', () async {
      final service = EventService()..addEvent(at(9));
      await service.applyWatchChanges([
        WatchChanges(deletedIds: ['missing'])
      ]);
      expect(service.events, hasLength(1));
    });

    test('is saved, ids and all', () async {
      final lap = at(10, 'Lap');
      await EventService().applyWatchChanges([
        WatchChanges(added: [lap])
      ]);
      final restored = await reloaded();
      expect(restored.events.single, lap);
      expect(restored.events.single.id, lap.id);
      expect(restored.referenceEvent, same(restored.events.single));
    });

    test('does not disturb events saved before ids existed', () async {
      SharedPreferences.setMockInitialValues({
        'events': [
          '{"time":"2026-03-05T09:00:00.000","precision":12,"description":"old","color":1}'
        ],
        referenceEventKey:
            '{"time":"2026-03-05T09:00:00.000","precision":12,"description":"old","color":1}',
      });
      final service = await reloaded();
      await service.applyWatchChanges([
        WatchChanges(added: [at(10, 'watch')])
      ]);
      final restored = await reloaded();
      expect(restored.events.map((e) => e.description), ['watch', 'old']);
      expect(restored.referenceEvent?.description, 'old');
      expect(restored.events.last.color, PredefinedColor.red);
    });
  });

  group('the sync service', () {
    late List<MethodCall> calls;
    late List<Map<String, Object>> inbox;
    late EventService events;
    late WatchSyncService sync;
    var buttons = <ButtonModel>[];
    var failClear = false;

    setUp(() async {
      calls = [];
      inbox = [];
      buttons = [];
      failClear = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchChannel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'readInbox':
            return inbox;
          case 'clearInbox':
            if (failClear) throw PlatformException(code: 'nope');
            final upTo = (call.arguments as Map)['upTo'] as int;
            inbox.removeWhere((item) => (item['sequence'] as int) <= upTo);
        }
        return null;
      });
      events = EventService();
      sync = WatchSyncService(
        events: events,
        prefs: await SharedPreferences.getInstance(),
        buttons: () => buttons,
        timeFormat: () => TimeFormat.utc24Hour,
      );
    });

    tearDown(() {
      sync.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchChannel, null);
    });

    Map<String, dynamic> lastContext() => jsonDecode(
        (calls.lastWhere((c) => c.method == 'updateContext').arguments
            as Map)['json']);

    test('takes in the inbox, then clears what it took', () async {
      final lap = at(10, 'Lap');
      inbox.addAll([
        delivery(1, added: [lap]),
        delivery(2, added: [at(11)])
      ]);
      await sync.importInbox();
      expect(events.events, hasLength(2));
      expect(inbox, isEmpty);
      expect(calls.firstWhere((c) => c.method == 'clearInbox').arguments,
          {'upTo': 2});
    });

    test('a delivery read twice, because clearing failed, is added once',
        () async {
      inbox.add(delivery(1, added: [at(10)]));
      failClear = true;
      await sync.importInbox();
      failClear = false;
      await sync.importInbox();
      expect(events.events, hasLength(1));
      expect(inbox, isEmpty);
    });

    test('imports at the same time are applied one after the other',
        () async {
      inbox.add(delivery(1, added: [at(10)]));
      await Future.wait([sync.importInbox(), sync.importInbox()]);
      expect(events.events, hasLength(1));
    });

    test('an unreadable delivery is cleared and does not block the rest',
        () async {
      inbox.addAll([
        {'sequence': 1, 'json': '{not json'},
        delivery(2, added: [at(10)]),
      ]);
      await sync.importInbox();
      expect(events.events, hasLength(1));
      expect(inbox, isEmpty);
    });

    test('tells the watch which of its events it took in', () async {
      final lap = at(10, 'Lap');
      inbox.add(delivery(1, added: [lap]));
      await sync.importInbox();
      expect(lastContext()['importedIds'], [lap.id]);
      expect(lastContext()['events'].single['id'], lap.id);
    });

    test('remembers taken-in ids across restarts, up to a limit', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(WatchSyncService.importedIdsKey,
          [for (var i = 0; i < WatchSyncService.importedIdsKept; i++) 'old$i']);
      final lap = at(10);
      inbox.add(delivery(1, added: [lap]));
      await sync.importInbox();
      final kept = prefs.getStringList(WatchSyncService.importedIdsKey)!;
      expect(kept, hasLength(WatchSyncService.importedIdsKept));
      expect(kept.last, lap.id);
      expect(kept.first, 'old1');
    });

    test('an empty inbox changes nothing', () async {
      events.addEvent(at(9));
      calls.clear();
      await sync.importInbox();
      expect(calls.map((c) => c.method), ['readInbox']);
    });

    test('sends the buttons, time format and reference', () async {
      buttons = [ButtonModel('Start', PredefinedColor.green)];
      final reference = at(9);
      events.addEvent(reference);
      await sync.pushContext();
      expect(lastContext()['buttons'], [
        {'name': 'Start', 'color': PredefinedColor.green.index}
      ]);
      expect(lastContext()['timeFormat'], TimeFormat.utc24Hour.index);
      expect(lastContext()['reference']['id'], reference.id);
    });

    test('once started, every change on the phone is sent', () async {
      await sync.start();
      calls.clear();
      events.addEvent(at(9, 'phone'));
      await pumpEventQueue();
      expect(lastContext()['events'].single['description'], 'phone');
    });

    test('when disabled, nothing reaches the channel', () async {
      final off = WatchSyncService(
        events: events,
        prefs: await SharedPreferences.getInstance(),
        buttons: () => [],
        timeFormat: () => TimeFormat.local24Hour,
        enabled: false,
      );
      await off.start();
      await off.importInbox();
      await off.pushContext();
      expect(calls, isEmpty);
    });

    test('without the iOS side, nothing throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchChannel, null);
      await sync.importInbox();
      await sync.pushContext();
    });
  });
}
