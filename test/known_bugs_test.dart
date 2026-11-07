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
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/time_server.dart';
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
