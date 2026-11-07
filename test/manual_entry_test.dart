import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/settings_elements/custom_time_picker_dialog.dart';
import 'package:timestamp/utils/time_utils.dart';

import 'helpers/test_app.dart';

Future<void> openManualEntry(WidgetTester tester) async {
  setDevice(tester, tallScreen);
  await pumpApp(tester, buttons: [], rows: 1);
  await tester.tap(find.byIcon(Icons.settings));
  await settle(tester);
  await tester.tap(find.text('Manual Event Entry'));
  await settle(tester);
}

EventService events(WidgetTester tester) =>
    appContainer(tester).read(eventServiceProvider);

Future<void> saveEvent(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
}

/// Sets the wheels (hour, minute, second, tenth) in the time picker.
void spinWheels(WidgetTester tester, List<int> values) {
  final wheels = find.byType(CupertinoPicker);
  for (var i = 0; i < values.length; i++) {
    tester.widget<CupertinoPicker>(wheels.at(i)).onSelectedItemChanged!(values[i]);
  }
}

void main() {
  group('manual entry screen', () {
    testWidgets('adds an event for now, with unknown accuracy', (tester) async {
      await openManualEntry(tester);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      final before = DateTime.now();
      await saveEvent(tester);

      final event = events(tester).events.single;
      expect(event.precision, -1, reason: 'typed in, so accuracy is unknown');
      expect(event.description, '');
      expect(event.color, PredefinedColor.defaultColor);
      expect(event.time.difference(before).inMinutes.abs(), 0);
      expect((await savedEvents()).single, event);

      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Event added successfully!'), findsOneWidget);
      await settle(tester);
      expect(find.text('Manual Event Entry'), findsOneWidget,
          reason: 'returns to settings');
      await unmountApp(tester);
    });

    testWidgets('description: Save keeps it', (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Took medication');
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.text('Took medication'), findsOneWidget);
      await saveEvent(tester);
      expect(events(tester).events.single.description, 'Took medication');
      await unmountApp(tester);
    });

    testWidgets('description: Cancel discards the typing', (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'typo');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(find.text('None'), findsOneWidget);
      await saveEvent(tester);
      expect(events(tester).events.single.description, '');
      await settle(tester);
      await unmountApp(tester);
    });

    testWidgets('description: Cancel keeps what was saved before',
        (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'keep');
      await tester.tap(find.text('Save'));
      await settle(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'discard');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      await saveEvent(tester);
      expect(events(tester).events.single.description, 'keep');
      await settle(tester);
      await unmountApp(tester);
    });

    testWidgets('description: tapping outside the dialog discards the typing',
        (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Description'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'typo');
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);

      await saveEvent(tester);
      expect(events(tester).events.single.description, '');
      await settle(tester);
      await unmountApp(tester);
    });

    testWidgets('color', (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Color'));
      await settle(tester);
      expect(find.text('Select Color'), findsOneWidget);
      await tester.tap(find.text('Orange'));
      await settle(tester);

      expect(find.text('Orange'), findsOneWidget);
      await saveEvent(tester);
      expect(events(tester).events.single.color, PredefinedColor.orange);
      await unmountApp(tester);
    });

    testWidgets('choosing a color does not create a button', (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Event Color'));
      await settle(tester);
      await tester.tap(find.text('Red'));
      await settle(tester);
      await saveEvent(tester);
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('time picker sets the time and keeps the date', (tester) async {
      await openManualEntry(tester);
      final today = DateTime.now();

      await tester.tap(find.text('Select Time'));
      await settle(tester);
      spinWheels(tester, [13, 45, 30, 7]);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);

      final expected =
          DateTime(today.year, today.month, today.day, 13, 45, 30, 700);
      expect(find.text(formatAbsoluteTime(expected, TimeFormat.local24Hour)),
          findsOneWidget);
      await saveEvent(tester);
      expect(events(tester).events.single.time, expected);
      await unmountApp(tester);
    });

    testWidgets('date picker sets the date and keeps the time', (tester) async {
      await openManualEntry(tester);

      await tester.tap(find.text('Select Time'));
      await settle(tester);
      spinWheels(tester, [8, 15, 0, 0]);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);

      await tester.tap(find.text('Select Date'));
      await settle(tester);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit));
      await settle(tester);
      await tester.enterText(
          find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextField)),
          '03/05/2020');
      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(find.text('Thu Mar 05, 2020'), findsOneWidget);
      await saveEvent(tester);
      final time = events(tester).events.single.time;
      expect(time, DateTime(2020, 3, 5, 8, 15));
      await unmountApp(tester);
    });

    testWidgets('canceling the date picker changes nothing', (tester) async {
      await openManualEntry(tester);
      final shown = formatDate(DateTime.now(), TimeFormat.local24Hour);

      await tester.tap(find.text('Select Date'));
      await settle(tester);
      await tester.tap(find.text('CANCEL'));
      await settle(tester);

      expect(find.text(shown), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('leaving without saving adds nothing', (tester) async {
      await openManualEntry(tester);

      await tester.pageBack();
      await settle(tester);

      expect(events(tester).events, isEmpty);
      await unmountApp(tester);
    });

    testWidgets('a past event lands in order on the main screen',
        (tester) async {
      setDevice(tester, tallScreen);
      await pumpApp(tester, buttons: ['Now'], rows: 1);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Now'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester);
      await tester.tap(find.text('Manual Event Entry'));
      await settle(tester);
      await tester.tap(find.text('Select Date'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await settle(tester);
      await tester.enterText(
          find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextField)),
          '03/05/2020');
      await tester.tap(find.text('OK'));
      await settle(tester);
      await saveEvent(tester);
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      expect(events(tester).events.last.time.year, 2020);
      expect(find.text('Thu Mar 05, 2020'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('CustomTimePickerDialog', () {
    Future<List<DateTime>> pumpDialog(WidgetTester tester, DateTime initial) async {
      final results = <DateTime>[];
      await tester.pumpWidget(MaterialApp(
        home: CustomTimePickerDialog(
            initialDateTime: initial, onDateTimeChanged: results.add),
      ));
      return results;
    }

    int selectedItem(WidgetTester tester, int wheel) =>
        tester
            .widget<CupertinoPicker>(find.byType(CupertinoPicker).at(wheel))
            .scrollController!
            .initialItem;

    testWidgets('starts on the given time, tenths rounded down', (tester) async {
      await pumpDialog(tester, DateTime(2026, 3, 2, 21, 5, 59, 999));
      expect(selectedItem(tester, 0), 21);
      expect(selectedItem(tester, 1), 5);
      expect(selectedItem(tester, 2), 59);
      expect(selectedItem(tester, 3), 9);
    });

    testWidgets('OK without changes returns the same time to the tenth',
        (tester) async {
      final results =
          await pumpDialog(tester, DateTime(2026, 3, 2, 21, 5, 59, 999));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 3, 2, 21, 5, 59, 900)]);
    });

    testWidgets('dragging a wheel changes that field', (tester) async {
      final results = await pumpDialog(tester, DateTime(2026, 3, 2, 10, 0, 0));
      await tester.drag(find.byType(CupertinoPicker).at(0), const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(results.single.hour, 12);
      expect(results.single.minute, 0);
    });

    testWidgets('wheels cover the whole range', (tester) async {
      await pumpDialog(tester, DateTime(2026));
      final sizes = [
        for (var i = 0; i < 4; i++)
          (tester.widget<CupertinoPicker>(find.byType(CupertinoPicker).at(i))
                  .childDelegate as ListWheelChildLoopingListDelegate)
              .children
              .length,
      ];
      expect(sizes, [24, 60, 60, 10]);
    });
  });
}
