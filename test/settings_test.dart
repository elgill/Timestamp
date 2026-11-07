import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/utils/time_utils.dart';

import 'helpers/test_app.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

Future<void> openSettings(WidgetTester tester,
    {List<String> buttons = const [],
    int rows = 1,
    Map<String, Object> prefs = const {}}) async {
  setDevice(tester, tallScreen);
  await pumpApp(tester, buttons: buttons, rows: rows, extraPrefs: prefs);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.settings));
  await settle(tester);
}

/// Leaves settings and clears the app so no timer outlives the test.
Future<void> closeApp(WidgetTester tester) async {
  await unmountApp(tester);
  // Lets the settings route's snackbar/animation timers finish.
  await tester.pump(const Duration(seconds: 1));
}

/// The settings row with the given title.
Finder tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SettingsTile));

/// The value shown on a settings row.
Finder tileValue(String title, String value) =>
    find.descendant(of: tile(title), matching: find.text(value));

Future<void> flipSwitch(WidgetTester tester, String title) async {
  await tester.tap(
      find.descendant(of: tile(title), matching: find.byType(Switch)));
  await settle(tester);
}

bool switchValue(WidgetTester tester, String title) => tester
    .widget<Switch>(
        find.descendant(of: tile(title), matching: find.byType(Switch)))
    .value;

/// Opens a picker from settings and chooses an option.
Future<void> choose(WidgetTester tester, String row, String option) async {
  await tester.tap(find.text(row));
  await settle(tester);
  await tester.tap(find.text(option));
  await settle(tester);
}

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Timestamp',
        packageName: 'dev.gillin.timestamp',
        version: '9.8.7',
        buildNumber: '1',
        buildSignature: '',
      ));

  group('settings list', () {
    testWidgets('shows the defaults', (tester) async {
      await openSettings(tester);

      expect(tileValue('Time Server', 'time.google.com'), findsOneWidget);
      expect(tileValue('Time Format', 'Local 24 Hour'), findsOneWidget);
      expect(tileValue('Time Display Mode', 'Absolute Time'), findsOneWidget);
      expect(tileValue('Button Location', 'Top'), findsOneWidget);
      expect(tileValue('Max Button Rows', '1'), findsOneWidget);
      expect(tileValue('Theme', 'System'), findsOneWidget);
      expect(switchValue(tester, 'Hide Running Timer'), isFalse);
      expect(switchValue(tester, 'Record on Touch Down'), isFalse);
      expect(switchValue(tester, 'Include Accuracy in Export'), isFalse);
      await closeApp(tester);
    });

    testWidgets('shows the app version', (tester) async {
      await openSettings(tester);
      await tester.pump();
      expect(find.text('Version: 9.8.7'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('pickers', () {
    testWidgets('time server', (tester) async {
      await openSettings(tester);
      await tester.tap(find.text('Time Server'));
      await settle(tester);

      expect(find.text('Select Time Server'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('time.nist.gov'));
      await settle(tester);

      expect(tileValue('Time Server', 'time.nist.gov'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(sharedTimeServerKey), 'TimeServer.timeNistGov');
      await closeApp(tester);
    });

    testWidgets('time format changes how events are shown', (tester) async {
      final time = DateTime(2026, 3, 2, 15, 4, 5);
      await openSettings(tester, prefs: {
        'events': [Event(time, 1, description: 'Aura').toJson()],
      });

      await choose(tester, 'Time Format', 'Local 12 Hour');
      expect(tileValue('Time Format', 'Local 12 Hour'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      expect(find.text(formatAbsoluteTime(time, TimeFormat.local12Hour)),
          findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('time display mode', (tester) async {
      await openSettings(tester);

      await choose(tester, 'Time Display Mode', 'Relative Time');
      expect(tileValue('Time Display Mode', 'Relative Time'), findsOneWidget);

      await choose(tester, 'Time Display Mode', 'Absolute Time');
      expect(tileValue('Time Display Mode', 'Absolute Time'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('button location moves the buttons', (tester) async {
      await openSettings(tester, buttons: ['Aura']);

      await choose(tester, 'Button Location', 'Bottom');
      expect(tileValue('Button Location', 'Bottom'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      expect(
          tester.getTopLeft(find.widgetWithText(ElevatedButton, 'Aura')).dy,
          greaterThan(tester.getTopLeft(find.byType(ListView)).dy));
      await closeApp(tester);
    });

    testWidgets('max button rows re-flows the buttons', (tester) async {
      await openSettings(tester, buttons: ['A', 'B']);

      await tester.tap(find.text('Max Button Rows'));
      await settle(tester);
      expect(find.byType(SettingsTile), findsNWidgets(5));
      await tester.tap(find.text('2'));
      await settle(tester);
      expect(tileValue('Max Button Rows', '2'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      expect(tester.getTopLeft(find.widgetWithText(ElevatedButton, 'B')).dy,
          greaterThan(tester.getTopLeft(find.widgetWithText(ElevatedButton, 'A')).dy));
      await closeApp(tester);
    });

    for (final (option, mode) in [
      ('Dark', ThemeMode.dark),
      ('Light', ThemeMode.light),
    ]) {
      testWidgets('theme $option applies immediately', (tester) async {
        await openSettings(tester);

        await choose(tester, 'Theme', option);

        expect(tileValue('Theme', option), findsOneWidget);
        expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            mode);
        await closeApp(tester);
      });
    }

    testWidgets('the current choice is checked in each picker', (tester) async {
      await openSettings(tester, prefs: {
        sharedTimeFormatKey: 'TimeFormat.utc24Hour',
        maxButtonRowsKey: 3,
        themeModeKey: 'ThemeMode.dark',
        buttonLocationKey: 'ButtonLocation.bottom',
        displayModeKey: 'DisplayMode.relative',
      });

      for (final (row, current) in [
        ('Time Format', 'UTC 24 Hour'),
        ('Max Button Rows', '3'),
        ('Theme', 'Dark'),
        ('Button Location', 'Bottom'),
        ('Time Display Mode', 'Relative Time'),
      ]) {
        await tester.tap(find.text(row));
        await settle(tester);
        expect(find.byIcon(Icons.check), findsOneWidget, reason: row);
        expect(
            find.descendant(
                of: tile(current), matching: find.byIcon(Icons.check)),
            findsOneWidget,
            reason: row);
        await tester.pageBack();
        await settle(tester);
      }
      await closeApp(tester);
    });
  });

  group('switches', () {
    testWidgets('hide running timer hides the clock', (tester) async {
      await openSettings(tester);

      await flipSwitch(tester, 'Hide Running Timer');
      expect(switchValue(tester, 'Hide Running Timer'), isTrue);

      await tester.pageBack();
      await settle(tester);
      expect(
          find.byWidgetPredicate(
              (w) => w is Text && w.style?.fontFamily == 'Courier New'),
          findsNothing);
      await closeApp(tester);
    });

    testWidgets('record on touch down takes effect on the main screen',
        (tester) async {
      await openSettings(tester, buttons: ['Aura']);

      await flipSwitch(tester, 'Record on Touch Down');
      expect(switchValue(tester, 'Record on Touch Down'), isTrue);

      await tester.pageBack();
      await settle(tester);
      final gesture = await tester.startGesture(
          tester.getCenter(find.widgetWithText(ElevatedButton, 'Aura')));
      await tester.pump();
      expect(await savedEvents(), hasLength(1));
      await gesture.up();
      await closeApp(tester);
    });

    testWidgets('disable auto lock is saved', (tester) async {
      installFakeWakelock();
      await openSettings(tester);

      expect(switchValue(tester, 'Disable Auto Lock'), isFalse);
      await flipSwitch(tester, 'Disable Auto Lock');
      expect(switchValue(tester, 'Disable Auto Lock'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(disableAutoLockKey), isTrue);
      await closeApp(tester);
    });
  });

  group('sharing', () {
    late List<Map<Object?, Object?>> shared;

    setUp(() {
      shared = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
        shared.add(call.arguments as Map<Object?, Object?>);
        return 'dev.fluttercommunity.plus/share/success';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, null));
    });

    final event = Event(DateTime(2026, 3, 2, 15, 4, 5), 15, description: 'Aura');

    testWidgets('shares the log in the selected format', (tester) async {
      await openSettings(tester, prefs: {
        'events': [event.toJson()],
        sharedTimeFormatKey: 'TimeFormat.local12Hour',
      });

      await tester.tap(find.text('Share Event Log'));
      await settle(tester);

      expect(shared, hasLength(1));
      expect(shared.single['subject'], 'Timestamp Event Log');
      final text = shared.single['text'] as String;
      expect(text, startsWith('Timestamp Event Log'));
      expect(text, contains('Aura'));
      expect(text,
          contains(formatAbsoluteTime(event.time, TimeFormat.local12Hour)));
      expect(text, isNot(contains('±15ms')));
      await closeApp(tester);
    });

    testWidgets('the accuracy switch adds accuracy to the log', (tester) async {
      await openSettings(tester, prefs: {
        'events': [event.toJson()],
      });

      await flipSwitch(tester, 'Include Accuracy in Export');
      await tester.tap(find.text('Share Event Log'));
      await settle(tester);

      expect(shared.single['text'], contains('±15ms'));
      await closeApp(tester);
    });

    testWidgets('gives iPads a popover origin', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Share Event Log'));
      await settle(tester);

      expect(shared.single['originWidth'], greaterThan(0));
      expect(shared.single['originHeight'], greaterThan(0));
      await closeApp(tester);
    });
  });

  group('links', () {
    late List<String> launched;

    setUp(() {
      launched = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlChannel, (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlChannel, null));
    });

    for (final (title, url) in [
      ('Privacy Policy', 'https://gillin.dev/privacy'),
      ('Feedback & Support', 'https://gillin.dev/#contact'),
    ]) {
      testWidgets('$title opens the right page', (tester) async {
        await openSettings(tester);

        await tester.tap(find.text(title));
        await settle(tester);

        expect(launched, [url]);
        await closeApp(tester);
      });
    }
  });
}
