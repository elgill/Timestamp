// Each test here describes the CORRECT behavior for a bug that exists in the
// app today, so each one fails. They are skipped during a normal
// `flutter test` to keep the suite green. To see them fail:
//
//   flutter test test/known_bugs_test.dart --dart-define=KNOWN_BUGS=true
//
// When you fix a bug, move its test to the matching test file and drop the
// `skip`. A test here that starts passing means the bug is gone.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/services/export_service.dart';

import 'helpers/test_app.dart';

const _skip = !bool.fromEnvironment('KNOWN_BUGS');

const phone = iPhone15ProPortrait;

EventService eventsOf(WidgetTester tester) =>
    appContainer(tester).read(eventServiceProvider);

Finder inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

Map<String, Object> history(List<Event> events, {Event? reference}) => {
      'events': events.map((e) => e.toJson()).toList(),
      if (reference != null) referenceEventKey: reference.toJson(),
    };

Future<SharedUtility> utilityWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedUtility(sharedPreferences: await SharedPreferences.getInstance());
}

Future<void> deleteSelected(WidgetTester tester) async {
  await tester.tap(find.text('Delete Selected'));
  await settle(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Delete'));
  await settle(tester);
}

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Timestamp',
        packageName: 'dev.gillin.timestamp',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      ));

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

    // _groupedEvents keys each day as local midnight, then formatDate calls
    // toUtc() on that key. East of UTC, local midnight is still the previous
    // UTC day, so every heading is a day early. Only fails in such a zone:
    //
    //   TZ=Asia/Kolkata flutter test test/known_bugs_test.dart \
    //       --dart-define=KNOWN_BUGS=true
    testWidgets('UTC date headings show the UTC day', skip: _skip,
        (tester) async {
      setDevice(tester, phone);
      final event = Event(DateTime.utc(2026, 3, 3, 12).toLocal(), 1);
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: {
        ...history([event], reference: event),
        sharedTimeFormatKey: 'TimeFormat.utc24Hour',
      });

      final headings = find.text('Tue Mar 03, 2026').evaluate().length;
      await unmountApp(tester);
      expect(headings, 1);
    });

    // The description dialog edits the same controller the event is built
    // from, so Cancel does not discard what was typed.
    testWidgets('canceling the description dialog discards the text',
        skip: _skip, (tester) async {
      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: [], rows: 1);
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.tap(find.text('Manual Event Entry'));
      await settle(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'typo');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      final description = eventsOf(tester).events.single.description;
      await settle(tester);
      await unmountApp(tester);
      expect(description, '');
    });

    // recordEvent always inserts the new selection flag at index 0, but a
    // future-dated manual event sorts above the new event. The flags shift
    // and the wrong event gets deleted.
    testWidgets('selection stays correct when a future event exists',
        skip: _skip, (tester) async {
      setDevice(tester, phone);
      final future = Event(DateTime.now().add(const Duration(days: 1)), -1,
          description: 'future');
      await pumpApp(tester, buttons: ['New'], rows: 1,
          extraPrefs: history([future], reference: future));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.tap(inList(find.text('future')));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'New'));
      await tester.pump();
      await deleteSelected(tester);

      final remaining =
          eventsOf(tester).events.map((e) => e.description).toList();
      await unmountApp(tester);
      expect(remaining, ['New']);
    });

    // After a restart referenceEvent and its entry in events are separate
    // objects. Editing the entry breaks their equality, so deleting it no
    // longer clears the reference and relative times use a deleted event.
    testWidgets('deleting an edited reference event after a relaunch',
        skip: _skip, (tester) async {
      setDevice(tester, phone);
      final event = Event(DateTime(2026, 3, 2, 10), 1, description: 'ref');
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history([event], reference: event));

      await tester.tap(inList(find.text('ref')));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'renamed');
      await tester.pump();
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.tap(inList(find.text('renamed')));
      await tester.pump();
      await deleteSelected(tester);

      final reference = eventsOf(tester).referenceEvent;
      await unmountApp(tester);
      expect(reference, isNull);
    });

    // Rows look themselves up with events.indexOf, which uses value equality,
    // so two identical events both act on the first one.
    testWidgets('identical events can be selected separately', skip: _skip,
        (tester) async {
      setDevice(tester, phone);
      final time = DateTime(2026, 3, 2, 10);
      final a = Event(time, -1, description: 'same');
      final b = Event(time, -1, description: 'same');
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history([a, b], reference: a));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();

      final checked = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      await unmountApp(tester);
      expect(checked, [false, true]);
    });

    // loadData throws on the first bad entry, leaving the list empty; the
    // next recorded event then overwrites the whole saved log.
    test('one unreadable event does not lose the rest', skip: _skip, () async {
      final good = Event(DateTime(2026, 3, 2), 1, description: 'good');
      SharedPreferences.setMockInitialValues({
        'events': [good.toJson(), '{not json'],
      });
      final service = EventService();
      await service.loadData().catchError((_) {});
      expect(service.events, [good]);
    });

    // Color == MaterialColor is always false (different runtimeType), so
    // the migration from the old raw-color format turns every color to
    // default.
    test('migrating old button colors keeps the color', skip: _skip, () async {
      final utility = await utilityWith({
        customButtonModelsKey: [
          jsonEncode({'name': 'Aura', 'color': Colors.red.toARGB32()}),
        ],
      });
      expect(utility.getCustomButtonModels(),
          [ButtonModel('Aura', PredefinedColor.red)]);
    });

    // Quotes in a description aren't doubled. convertEventsToCsv isn't wired
    // to any UI yet, but would produce a corrupt file when it is.
    test('CSV escapes quotes', skip: _skip, () {
      final time = DateTime.utc(2026, 3, 5);
      expect(convertEventsToCsv([Event(time, 1, description: 'a "b" c')]),
          contains('"a ""b"" c"'));
    });
  });

  group('crashes', () {
    // ReorderableListView rows are keyed by name.
    testWidgets('adding a duplicate button name', skip: _skip, (tester) async {
      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: ['Aura'], rows: 1);
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.tap(find.text('Custom Button Names'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Aura');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      final error = tester.takeException();
      await unmountApp(tester);
      expect(error, isNull);
    });

    // Only getThemeMode has an orElse. A value from a newer version or a
    // renamed enum throws on every build, so the app can't open.
    test('unknown saved enum values fall back to the default', skip: _skip,
        () async {
      final utility = await utilityWith({
        sharedTimeFormatKey: 'TimeFormat.gone',
        sharedTimeServerKey: 'TimeServer.gone',
        buttonLocationKey: 'ButtonLocation.gone',
      });
      expect(utility.getTimeFormat(), TimeFormat.local24Hour);
      expect(utility.getTimeServer(), TimeServer.timeGoogleCom);
      expect(utility.getButtonLocation(), ButtonLocation.top);
    });

    // _launchURL throws a String from an async callback that nothing awaits.
    testWidgets('a link that cannot open does not raise an error', skip: _skip,
        (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: [], rows: 1);
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.tap(find.text('Privacy Policy'));
      await settle(tester);
      await unmountApp(tester);
    });
  });

  group('settings that do not fully work', () {
    // MainScreen.build only ever calls enable(); nothing calls disable()
    // when the setting is turned off.
    testWidgets('turning off Disable Auto Lock lets the screen sleep',
        skip: _skip, (tester) async {
      final wakelock = installFakeWakelock();
      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: {disableAutoLockKey: true});
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);

      await tester.tap(find.descendant(
          of: find.ancestor(
              of: find.text('Disable Auto Lock'),
              matching: find.byType(SettingsTile)),
          matching: find.byType(Switch)));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      final last = wakelock.calls.last;
      await unmountApp(tester);
      expect(last, isFalse);
    });

    // Whitespace passes the isNotEmpty check, giving a blank button.
    testWidgets('a blank button name is ignored', skip: _skip, (tester) async {
      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: [], rows: 1);
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.tap(find.text('Custom Button Names'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      final names = appContainer(tester).read(customButtonNamesProvider);
      await unmountApp(tester);
      expect(names, isEmpty);
    });
  });

  group('efficiency and polish', () {
    // WakelockPlus.enable() is in build(), which the clock timer runs up to
    // 100 times a second: a platform call on every frame.
    testWidgets('the wakelock is requested once, not on every frame',
        skip: _skip, (tester) async {
      final wakelock = installFakeWakelock();
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: {disableAutoLockKey: true});

      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      final calls = wakelock.calls.where((enable) => enable).length;
      await unmountApp(tester);
      expect(calls, lessThanOrEqualTo(1));
    });

    // Both NtpService's constructor and MainScreen.initState start a sync.
    testWidgets('one NTP query at startup', skip: _skip, (tester) async {
      setDevice(tester, phone);
      late FakeNtpService ntp;
      await pumpApp(tester,
          buttons: [], rows: 1, onNtpCreated: (service) => ntp = service);

      final requests = ntp.syncRequests;
      await unmountApp(tester);
      expect(requests, 1);
    });

    testWidgets('the bottom bar spells Received correctly', skip: _skip,
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, ntpSynced: false);

      final misspelled = find.text('No Time Data Recieved').evaluate().length;
      await unmountApp(tester);
      expect(misspelled, 0);
    });
  });
}
