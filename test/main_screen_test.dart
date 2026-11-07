import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/utils/time_utils.dart';

import 'helpers/test_app.dart';

const phone = iPhone15ProPortrait;

Finder inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

Finder recordButton(String label) => find.widgetWithText(ElevatedButton, label);

EventService eventsOf(WidgetTester tester) =>
    appContainer(tester).read(eventServiceProvider);

/// Saved form of [events], for starting the app with history.
Map<String, Object> history(List<Event> events, {Event? reference}) => {
      'events': events.map((e) => e.toJson()).toList(),
      if (reference != null) referenceEventKey: reference.toJson(),
    };

void main() {
  group('recording', () {
    testWidgets('a named button records its label, accuracy and time',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1);

      final before = DateTime.now();
      await tester.tap(recordButton('Aura'));
      await tester.pump();

      final event = eventsOf(tester).events.single;
      expect(event.description, 'Aura');
      // FakeNtpService has a 40ms round trip; accuracy is half of that.
      expect(event.precision, 20);
      expect(event.time.difference(before).inSeconds.abs(), lessThan(2));
      expect(inList(find.text('Aura')), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('the unnamed button records an event with no description',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();

      expect(eventsOf(tester).events.single.description, '');
      await unmountApp(tester);
    });

    testWidgets('accuracy is unknown until NTP has synced', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1, ntpSynced: false);

      await tester.tap(recordButton('Aura'));
      await tester.pump();

      expect(eventsOf(tester).events.single.precision, -1);
      await unmountApp(tester);
    });

    testWidgets('an event keeps the color of its button', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1, extraPrefs: {
        customButtonModelsKey: [
          jsonEncode(ButtonModel('Aura', PredefinedColor.red).toJson())
        ],
      });

      final button = tester.widget<ElevatedButton>(recordButton('Aura'));
      expect(button.style!.backgroundColor!.resolve({}), Colors.red);

      await tester.tap(recordButton('Aura'));
      await tester.pump();
      expect(eventsOf(tester).events.single.color, PredefinedColor.red);
      await unmountApp(tester);
    });

    testWidgets('newest event is listed first and everything is saved',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['First', 'Second'], rows: 1);

      await tester.tap(recordButton('First'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(recordButton('Second'));
      await tester.pump();

      expect(
          tester.getTopLeft(inList(find.text('Second'))).dy,
          lessThan(tester.getTopLeft(inList(find.text('First'))).dy));
      final saved = await savedEvents();
      expect(saved.map((e) => e.description).toSet(), {'First', 'Second'});
      await unmountApp(tester);
    });

    testWidgets('recorded events come back after a relaunch', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1);
      await tester.tap(recordButton('Aura'));
      await tester.pump();
      await unmountApp(tester);

      await relaunchApp(tester);
      expect(inList(find.text('Aura')), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('when an event is recorded', () {
    Future<void> setUpMode(WidgetTester tester, {required bool touchDown}) async {
      setDevice(tester, phone);
      await pumpApp(tester,
          buttons: ['Aura'],
          rows: 1,
          extraPrefs: {recordOnTouchDownKey: touchDown});
    }

    Future<TestGesture> press(WidgetTester tester) async {
      final gesture =
          await tester.startGesture(tester.getCenter(recordButton('Aura')));
      await tester.pump();
      return gesture;
    }

    testWidgets('by default only when the finger lifts', (tester) async {
      await setUpMode(tester, touchDown: false);

      final gesture = await press(tester);
      expect(eventsOf(tester).events, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(eventsOf(tester).events, hasLength(1));
      await unmountApp(tester);
    });

    testWidgets('by default sliding off the button cancels', (tester) async {
      await setUpMode(tester, touchDown: false);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(0, 400));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(eventsOf(tester).events, isEmpty);
      await unmountApp(tester);
    });

    testWidgets('with touch down, the moment the finger lands', (tester) async {
      await setUpMode(tester, touchDown: true);

      final gesture = await press(tester);
      expect(eventsOf(tester).events, hasLength(1));

      await gesture.up();
      await tester.pump();
      expect(eventsOf(tester).events, hasLength(1),
          reason: 'lifting the finger must not record a second event');
      await unmountApp(tester);
    });

    testWidgets('with touch down, timestamps the press and not the release',
        (tester) async {
      await setUpMode(tester, touchDown: true);

      final gesture = await press(tester);
      final recorded = eventsOf(tester).events.single;
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(eventsOf(tester).events.single, same(recorded));
      await unmountApp(tester);
    });

    testWidgets('with touch down, the press still counts if the finger slides',
        (tester) async {
      await setUpMode(tester, touchDown: true);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(0, 400));
      await gesture.up();
      await tester.pump();

      expect(eventsOf(tester).events, hasLength(1));
      await unmountApp(tester);
    });

    testWidgets('with touch down, each tap is one event', (tester) async {
      await setUpMode(tester, touchDown: true);

      for (var i = 0; i < 3; i++) {
        await tester.tap(recordButton('Aura'));
        await tester.pump(kDoubleTapTimeout);
      }
      expect(eventsOf(tester).events, hasLength(3));
      await unmountApp(tester);
    });

    testWidgets('touch down works for the unnamed button too', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester,
          buttons: [], rows: 1, extraPrefs: {recordOnTouchDownKey: true});

      final gesture = await tester
          .startGesture(tester.getCenter(find.byIcon(Icons.arrow_downward)));
      await tester.pump();
      expect(eventsOf(tester).events, hasLength(1));

      await gesture.up();
      await unmountApp(tester);
    });
  });

  group('event list', () {
    final monday = DateTime(2026, 3, 2, 10);
    final tuesday = DateTime(2026, 3, 3, 10);

    testWidgets('groups events under one date heading per day, newest first',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: history([
        Event(tuesday, 1, description: 'b'),
        Event(monday.add(const Duration(hours: 1)), 1, description: 'a2'),
        Event(monday, 1, description: 'a1'),
      ]));
      await tester.pump();

      final tue = inList(find.text('Tue Mar 03, 2026'));
      final mon = inList(find.text('Mon Mar 02, 2026'));
      expect(tue, findsOneWidget);
      expect(mon, findsOneWidget);
      expect(tester.getTopLeft(tue).dy, lessThan(tester.getTopLeft(mon).dy));
      await unmountApp(tester);
    });

    testWidgets('an event with no description shows only its time',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history([Event(monday, 1)]));
      await tester.pump();

      expect(
          inList(find.text(formatAbsoluteTime(monday, TimeFormat.local24Hour))),
          findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('uses the selected time format', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: {
        ...history([Event(monday, 1, description: 'a')]),
        sharedTimeFormatKey: 'TimeFormat.local12Hour',
      });
      await tester.pump();

      expect(
          inList(find.text(formatAbsoluteTime(monday, TimeFormat.local12Hour))),
          findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('UTC format puts events on their UTC day', (tester) async {
      setDevice(tester, phone);
      final beforeMidnight = DateTime.utc(2026, 3, 2, 23, 30).toLocal();
      final afterMidnight = DateTime.utc(2026, 3, 3, 0, 30).toLocal();
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: {
        ...history([Event(afterMidnight, 1), Event(beforeMidnight, 1)]),
        sharedTimeFormatKey: 'TimeFormat.utc24Hour',
      });
      await tester.pump();

      // Two separate days in any zone. The heading text itself is covered in
      // known_bugs_test.dart: it is a day early east of UTC.
      expect(inList(find.textContaining(', 2026')), findsNWidgets(2));
      await unmountApp(tester);
    });

    testWidgets('a colored event gets an indicator, a default one does not',
        (tester) async {
      setDevice(tester, phone);
      Finder indicators() => inList(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == Colors.red));

      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history([Event(monday, 1, description: 'plain')]));
      await tester.pump();
      expect(indicators(), findsNothing);
      await unmountApp(tester);

      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: history([
        Event(monday, 1, description: 'red', color: PredefinedColor.red)
      ]));
      await tester.pump();
      expect(indicators(), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('clock and display mode', () {
    final reference = DateTime(2026, 3, 2, 10);
    final later = reference.add(const Duration(minutes: 2, seconds: 15));

    Finder clock() => find.byWidgetPredicate((w) =>
        w is Text && w.style?.fontFamily == 'Courier New');

    testWidgets('tapping the clock switches to relative times and back',
        (tester) async {
      setDevice(tester, phone);
      final events = [Event(later, 1, description: 'b'), Event(reference, 1, description: 'a')];
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history(events, reference: events.last));
      await tester.pump();

      final absolute = formatAbsoluteTime(later, TimeFormat.local24Hour);
      expect(inList(find.text(absolute)), findsOneWidget);

      await tester.tap(clock());
      await tester.pump();
      expect(inList(find.text('+00:02:15.0')), findsOneWidget);
      expect(inList(find.text('00:00:00.0')), findsOneWidget);

      await tester.tap(clock());
      await tester.pump();
      expect(inList(find.text(absolute)), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('events before the reference show as negative', (tester) async {
      setDevice(tester, phone);
      final events = [Event(later, 1, description: 'ref'), Event(reference, 1, description: 'x')];
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: {
        ...history(events, reference: events.first),
        displayModeKey: 'DisplayMode.relative',
      });
      await tester.pump();

      expect(inList(find.text('-00:02:15.0')), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('relative mode with nothing recorded shows zero',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: {displayModeKey: 'DisplayMode.relative'});

      expect(tester.widget<Text>(clock()).data, '00:00:00.0');
      await unmountApp(tester);
    });

    testWidgets('the clock is in the body normally', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      expect(find.text('Timestamp'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: clock()),
          findsNothing);
      expect(clock(), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('on short screens the clock moves into the app bar',
        (tester) async {
      setDevice(tester, iPhone15ProLandscape);
      await pumpApp(tester, buttons: [], rows: 1);

      expect(find.text('Timestamp'), findsNothing);
      expect(find.descendant(of: find.byType(AppBar), matching: clock()),
          findsOneWidget);
      await unmountApp(tester);
    });

    for (final device in [iPhone15ProPortrait, iPhone15ProLandscape]) {
      testWidgets('hide timer removes the clock on $device', (tester) async {
        setDevice(tester, device);
        await pumpApp(tester, buttons: [], rows: 1,
            extraPrefs: {hideRunningTimerKey: true});

        expect(clock(), findsNothing);
        expect(find.text('Timestamp'), findsOneWidget);
        await unmountApp(tester);
      });
    }

    testWidgets('the clock keeps running', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      // The timer rebuilds the clock without any interaction.
      final before = tester.widget<Text>(clock());
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.widget<Text>(clock()), isNot(same(before)));
      await unmountApp(tester);
    });
  });

  group('NTP status', () {
    testWidgets('before any sync', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, ntpSynced: false);

      expect(find.textContaining('No Time Data'), findsOneWidget);
      await tester.tap(find.textContaining('No Time Data'));
      await settle(tester);
      expect(find.text('No Time Data Received'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.text('NTP Details'), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('summary shows sync time, offset and accuracy', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      expect(find.textContaining('Last Sync: 09:41:00.0'), findsOneWidget);
      expect(find.text('Offset: 12ms'), findsOneWidget);
      expect(find.text('Accuracy: ±20ms'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('summary is a single line on short screens', (tester) async {
      setDevice(tester, iPhone15ProLandscape);
      await pumpApp(tester, buttons: [], rows: 1);

      expect(find.textContaining('Offset: 12ms  ·  Accuracy: ±20ms'),
          findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('dialog shows all the details', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      await tester.tap(find.text('Offset: 12ms'));
      await settle(tester);

      expect(find.text('Time Server: time.test'), findsOneWidget);
      expect(find.text('NTP Stratum: 2'), findsOneWidget);
      expect(find.textContaining('Last Sync Time: 09:41:00.0'), findsOneWidget);
      expect(find.text('Round Trip Time(RTT): 40ms'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('Get Time resyncs and reopens the dialog', (tester) async {
      setDevice(tester, phone);
      late FakeNtpService ntp;
      await pumpApp(tester,
          buttons: [], rows: 1, onNtpCreated: (service) => ntp = service);
      final before = ntp.syncRequests;

      await tester.tap(find.text('Offset: 12ms'));
      await settle(tester);
      await tester.tap(find.text('Get Time'));
      await settle(tester);

      expect(ntp.syncRequests, before + 1);
      expect(find.text('NTP Details'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('delete mode', () {
    final first = Event(DateTime(2026, 3, 2, 8), 1, description: 'one');
    final second = Event(DateTime(2026, 3, 2, 9), 1, description: 'two');
    final third = Event(DateTime(2026, 3, 2, 10), 1, description: 'three');

    Future<void> startWithEvents(WidgetTester tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: history(
          [third, second, first], reference: first));
      await tester.pump();
      await tester.tap(find.text('Edit'));
      await tester.pump();
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await settle(tester);
      expect(find.text('Confirm Deletion'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);
    }

    List<String> remaining(WidgetTester tester) =>
        eventsOf(tester).events.map((e) => e.description).toList();

    testWidgets('Edit shows a checkbox per event, Cancel leaves everything',
        (tester) async {
      await startWithEvents(tester);
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Delete All'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.byType(Checkbox), findsNothing);
      expect(remaining(tester), hasLength(3));
      await unmountApp(tester);
    });

    testWidgets('selecting switches Delete All to Delete Selected',
        (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('Delete Selected'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('Delete All'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('tapping a row selects it instead of opening details',
        (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.text('two'));
      await settle(tester);

      expect(find.text('Event Details'), findsNothing);
      expect(find.text('Delete Selected'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('Delete Selected removes only the selected events',
        (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.text('two'));
      await tester.pump();
      await tester.tap(find.text('Delete Selected'));
      await confirmDelete(tester);

      expect(remaining(tester), ['three', 'one']);
      expect(find.byType(Checkbox), findsNothing, reason: 'leaves delete mode');
      expect((await savedEvents()).map((e) => e.description), ['three', 'one']);
      await unmountApp(tester);
    });

    testWidgets('canceling the confirmation keeps the events and the selection',
        (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.text('two'));
      await tester.pump();
      await tester.tap(find.text('Delete Selected'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);

      expect(remaining(tester), hasLength(3));
      expect(find.text('Delete Selected'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('Delete All removes everything', (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.text('Delete All'));
      await confirmDelete(tester);

      expect(remaining(tester), isEmpty);
      expect(eventsOf(tester).referenceEvent, isNull);
      expect(await savedEvents(), isEmpty);
      await unmountApp(tester);
    });

    testWidgets('canceling Delete All keeps everything', (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.text('Delete All'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);

      expect(remaining(tester), hasLength(3));
      await unmountApp(tester);
    });

    testWidgets('recording while selecting keeps the selection on its event',
        (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['New'], rows: 1,
          extraPrefs: history([third, second, first], reference: first));
      await tester.pump();
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.tap(find.text('two'));
      await tester.pump();
      await tester.tap(recordButton('New'));
      await tester.pump();
      await tester.tap(find.text('Delete Selected'));
      await confirmDelete(tester);

      expect(remaining(tester), ['New', 'three', 'one']);
      await unmountApp(tester);
    });

    testWidgets('opening settings leaves delete mode', (tester) async {
      await startWithEvents(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('event details', () {
    final time = DateTime(2026, 3, 2, 10, 20, 30, 400);

    Future<void> openDetails(WidgetTester tester, Event event,
        {Map<String, Object> prefs = const {}}) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1, extraPrefs: {
        ...history([event], reference: event),
        ...prefs,
      });
      await tester.pump();
      await tester.tap(inList(find.text(event.description)));
      await settle(tester);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pageBack();
      await settle(tester);
      await unmountApp(tester);
    }

    testWidgets('shows date, time, accuracy and description', (tester) async {
      await openDetails(tester, Event(time, 15, description: 'Aura'));

      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('Mon Mar 02, 2026'), findsOneWidget);
      expect(find.text(formatAbsoluteTime(time, TimeFormat.local24Hour)),
          findsOneWidget);
      expect(find.text('Precision: ±15ms'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Aura'), findsOneWidget);
      await close(tester);
    });

    testWidgets('unknown accuracy', (tester) async {
      await openDetails(tester, Event(time, -1, description: 'Aura'));
      expect(find.text('Precision: Unknown'), findsOneWidget);
      await close(tester);
    });

    testWidgets('uses the selected time format', (tester) async {
      await openDetails(tester, Event(time, 1, description: 'Aura'),
          prefs: {sharedTimeFormatKey: 'TimeFormat.utc24Hour'});
      expect(find.text(formatAbsoluteTime(time, TimeFormat.utc24Hour)),
          findsOneWidget);
      await close(tester);
    });

    testWidgets('editing the description updates the list and is saved',
        (tester) async {
      await openDetails(tester, Event(time, 1, description: 'Aura'));

      await tester.enterText(find.byType(TextField), 'Migraine');
      await tester.pump();
      await tester.pageBack();
      await settle(tester);

      expect(inList(find.text('Migraine')), findsOneWidget);
      expect((await savedEvents()).single.description, 'Migraine');
      await unmountApp(tester);
    });

    testWidgets('clearing the description falls back to showing the time',
        (tester) async {
      await openDetails(tester, Event(time, 1, description: 'Aura'));

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.pageBack();
      await settle(tester);

      expect(inList(find.text(formatAbsoluteTime(time, TimeFormat.local24Hour))),
          findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('choosing a color is saved, default clears it', (tester) async {
      await openDetails(tester, Event(time, 1, description: 'Aura'));

      Finder swatch(Color color) => find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == color);

      await tester.tap(swatch(Colors.green));
      await tester.pump();
      expect((await savedEvents()).single.color, PredefinedColor.green);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byIcon(Icons.do_not_disturb_alt_outlined));
      await tester.pump();
      expect((await savedEvents()).single.color, PredefinedColor.defaultColor);
      expect(find.byIcon(Icons.check), findsNothing);
      await close(tester);
    });

    testWidgets('Set as Reference changes the reference and confirms',
        (tester) async {
      setDevice(tester, phone);
      final older = Event(time, 1, description: 'older');
      final newer =
          Event(time.add(const Duration(hours: 1)), 1, description: 'newer');
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: history([newer, older], reference: older));
      await tester.pump();

      await tester.tap(inList(find.text('newer')));
      await settle(tester);
      await tester.tap(find.text('Set as Reference'));
      await tester.pump();

      expect(eventsOf(tester).referenceEvent?.description, 'newer');
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Reference Event Set!'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      await unmountApp(tester);
      await relaunchApp(tester);
      await tester.pump();
      expect(eventsOf(tester).referenceEvent?.description, 'newer');
      await unmountApp(tester);
    });
  });

  group('layout options', () {
    testWidgets('buttons sit above the list by default', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1);
      expect(tester.getTopLeft(recordButton('Aura')).dy,
          lessThan(tester.getTopLeft(find.byType(ListView)).dy));
      await unmountApp(tester);
    });

    testWidgets('buttons can sit below the list', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1,
          extraPrefs: {buttonLocationKey: 'ButtonLocation.bottom'});
      expect(tester.getTopLeft(recordButton('Aura')).dy,
          greaterThan(tester.getTopLeft(find.byType(ListView)).dy));
      await unmountApp(tester);
    });

    testWidgets('buttons are spread over the configured rows', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['A', 'B', 'C', 'D'], rows: 2);

      double y(String label) => tester.getTopLeft(recordButton(label)).dy;
      expect(y('A'), y('B'));
      expect(y('C'), y('D'));
      expect(y('C'), greaterThan(y('A')));
      await unmountApp(tester);
    });
  });

  group('theme', () {
    for (final (saved, mode) in [
      ('ThemeMode.dark', ThemeMode.dark),
      ('ThemeMode.light', ThemeMode.light),
      ('ThemeMode.system', ThemeMode.system),
    ]) {
      testWidgets('$saved is applied at startup', (tester) async {
        setDevice(tester, phone);
        await pumpApp(tester, buttons: [], rows: 1,
            extraPrefs: {themeModeKey: saved});
        expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            mode);
        await unmountApp(tester);
      });
    }

    testWidgets('the main screen renders in dark mode', (tester) async {
      setDevice(tester, phone);
      await pumpApp(tester, buttons: ['Aura'], rows: 1,
          extraPrefs: {themeModeKey: 'ThemeMode.dark'});
      expect(tester.takeException(), isNull);
      expect(Theme.of(tester.element(recordButton('Aura'))).brightness,
          Brightness.dark);
      await unmountApp(tester);
    });
  });

  group('keeping the screen on', () {
    testWidgets('is on by default', (tester) async {
      final wakelock = installFakeWakelock();
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: {disableAutoLockKey: true});

      expect(wakelock.calls, contains(true));
      await unmountApp(tester);
    });

    testWidgets('is not requested when the setting is off', (tester) async {
      final wakelock = installFakeWakelock();
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1);

      expect(wakelock.calls, isNot(contains(true)));
      await unmountApp(tester);
    });

    testWidgets('is released when the screen goes away', (tester) async {
      final wakelock = installFakeWakelock();
      setDevice(tester, phone);
      await pumpApp(tester, buttons: [], rows: 1,
          extraPrefs: {disableAutoLockKey: true});

      await unmountApp(tester);
      expect(wakelock.calls.last, isFalse);
    });
  });
}
