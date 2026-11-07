import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';

import 'helpers/test_app.dart';

Future<void> openManageScreen(WidgetTester tester, List<String> buttons,
    {int rows = 1, Map<String, Object> prefs = const {}}) async {
  setDevice(tester, tallScreen);
  await pumpApp(tester, buttons: buttons, rows: rows, extraPrefs: prefs);
  await tester.tap(find.byIcon(Icons.settings));
  await settle(tester);
  await tester.tap(find.text('Custom Button Names'));
  await settle(tester);
}

Future<void> addButton(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
}

Future<void> backToMain(WidgetTester tester) async {
  await tester.pageBack();
  await settle(tester);
  await tester.pageBack();
  await settle(tester);
}

List<String> names(WidgetTester tester) =>
    appContainer(tester).read(customButtonNamesProvider);

Finder listRow(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ListTile));

void main() {
  testWidgets('adding a button shows it, clears the field and saves it',
      (tester) async {
    await openManageScreen(tester, []);

    await addButton(tester, 'Aura');

    expect(listRow('Aura'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(customEventNamesKey), ['Aura']);
    await unmountApp(tester);
  });

  testWidgets('an empty name is ignored', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, '');

    expect(names(tester), ['Aura']);
    await unmountApp(tester);
  });

  testWidgets('a blank name is ignored', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, '   ');

    expect(names(tester), ['Aura']);
    await unmountApp(tester);
  });

  testWidgets('surrounding spaces are removed from a name', (tester) async {
    await openManageScreen(tester, []);

    await addButton(tester, '  Aura ');

    expect(names(tester), ['Aura']);
    await unmountApp(tester);
  });

  testWidgets('a duplicate name is refused with an explanation',
      (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, 'Aura');
    await tester.pump(const Duration(milliseconds: 750));

    expect(tester.takeException(), isNull);
    expect(names(tester), ['Aura']);
    expect(find.text('"Aura" already exists'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Aura',
        reason: 'keeps the text so it can be corrected');
    await unmountApp(tester);
  });

  testWidgets('repeated refusals do not queue up messages', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, 'Aura');
    await addButton(tester, 'Aura');
    await addButton(tester, 'Aura');
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('"Aura" already exists'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('"Aura" already exists'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('a corrected name clears the refusal', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, 'Aura');
    await tester.pump(const Duration(milliseconds: 750));
    await addButton(tester, 'Nausea');
    await tester.pump(const Duration(milliseconds: 750));

    expect(names(tester), ['Aura', 'Nausea']);
    expect(find.text('"Aura" already exists'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('a name differing only by spaces is a duplicate', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, 'Aura ');

    expect(names(tester), ['Aura']);
    await unmountApp(tester);
  });

  testWidgets('duplicates saved by older versions no longer crash the screen',
      (tester) async {
    await openManageScreen(tester, ['Aura', 'Nausea', 'Aura']);

    expect(tester.takeException(), isNull);
    expect(names(tester), ['Aura', 'Nausea']);
    await unmountApp(tester);
  });

  testWidgets('a new button appears on the main screen', (tester) async {
    await openManageScreen(tester, ['Aura']);

    await addButton(tester, 'Nausea');
    await backToMain(tester);

    expect(find.widgetWithText(ElevatedButton, 'Nausea'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('deleting removes the right button everywhere', (tester) async {
    await openManageScreen(tester, ['Aura', 'Nausea', 'Dizzy']);

    await tester.tap(find.descendant(
        of: listRow('Nausea'), matching: find.byIcon(Icons.delete)));
    await tester.pump();

    expect(names(tester), ['Aura', 'Dizzy']);
    expect(listRow('Nausea'), findsNothing);
    expect(
        appContainer(tester).read(customButtonModelsProvider).map((m) => m.name),
        ['Aura', 'Dizzy']);

    await backToMain(tester);
    expect(find.widgetWithText(ElevatedButton, 'Nausea'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('deleting the last button brings back the unnamed button',
      (tester) async {
    await openManageScreen(tester, ['Aura']);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await backToMain(tester);

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    await unmountApp(tester);
  });

  group('reordering', () {
    void reorder(WidgetTester tester, int from, int to) {
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorder!(from, to);
    }

    testWidgets('moving down', (tester) async {
      await openManageScreen(tester, ['A', 'B', 'C']);
      reorder(tester, 0, 3); // ReorderableListView reports the gap index.
      await tester.pump();
      expect(names(tester), ['B', 'C', 'A']);
      await unmountApp(tester);
    });

    testWidgets('moving up', (tester) async {
      await openManageScreen(tester, ['A', 'B', 'C']);
      reorder(tester, 2, 0);
      await tester.pump();
      expect(names(tester), ['C', 'A', 'B']);
      await unmountApp(tester);
    });

    testWidgets('dragging a row', (tester) async {
      await openManageScreen(tester, ['A', 'B', 'C']);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(seconds: 1)); // Long press to pick up.
      await gesture.moveBy(const Offset(0, 90));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 90));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await settle(tester);

      expect(names(tester).first, isNot('A'));
      expect(names(tester).toSet(), {'A', 'B', 'C'});
      await unmountApp(tester);
    });

    testWidgets('the new order is used on the main screen and saved',
        (tester) async {
      await openManageScreen(tester, ['A', 'B']);
      reorder(tester, 1, 0);
      await tester.pump();
      await backToMain(tester);

      expect(
          tester.getTopLeft(find.widgetWithText(ElevatedButton, 'B')).dx,
          lessThan(tester.getTopLeft(find.widgetWithText(ElevatedButton, 'A')).dx));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(customEventNamesKey), ['B', 'A']);
      await unmountApp(tester);
    });

    testWidgets('buttons keep their colors', (tester) async {
      await openManageScreen(tester, ['A', 'B'], prefs: {
        customButtonModelsKey: [
          jsonEncode(ButtonModel('A', PredefinedColor.red).toJson()),
          jsonEncode(ButtonModel('B', PredefinedColor.green).toJson()),
        ],
      });
      reorder(tester, 1, 0);
      await tester.pump();

      final models = appContainer(tester).read(customButtonModelsProvider.notifier);
      expect(models.getButtonPredefinedColor('A'), PredefinedColor.red);
      expect(models.getButtonPredefinedColor('B'), PredefinedColor.green);
      await unmountApp(tester);
    });
  });

  group('button colors', () {
    Future<void> pickColor(WidgetTester tester, String button, String color) async {
      await tester.tap(find.descendant(
          of: listRow(button), matching: find.byType(CircleAvatar)));
      await settle(tester);
      expect(find.text('Select Color'), findsOneWidget);
      await tester.tap(find.text(color));
      await settle(tester);
    }

    Color circleColor(WidgetTester tester, String button) => tester
        .widget<CircleAvatar>(find.descendant(
            of: listRow(button), matching: find.byType(CircleAvatar)))
        .backgroundColor!;

    testWidgets('choosing a color updates the list and the record button',
        (tester) async {
      await openManageScreen(tester, ['Aura', 'Nausea']);

      await pickColor(tester, 'Aura', 'Purple');
      expect(circleColor(tester, 'Aura'), Colors.purple);

      await backToMain(tester);
      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Aura'));
      expect(button.style!.backgroundColor!.resolve({}), Colors.purple);
      await unmountApp(tester);
    });

    testWidgets('the color picker checks the current color', (tester) async {
      await openManageScreen(tester, ['Aura'], prefs: {
        customButtonModelsKey: [
          jsonEncode(ButtonModel('Aura', PredefinedColor.orange).toJson()),
        ],
      });

      await tester.tap(find.byType(CircleAvatar));
      await settle(tester);

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(tester.getCenter(find.byIcon(Icons.check)).dy,
          closeTo(tester.getCenter(find.text('Orange')).dy, 12));
      await tester.pageBack();
      await settle(tester);
      await unmountApp(tester);
    });

    testWidgets('a color set on a duplicate from an older version sticks',
        (tester) async {
      final model = jsonEncode(
          ButtonModel('Aura', PredefinedColor.defaultColor).toJson());
      final other = jsonEncode(
          ButtonModel('Nausea', PredefinedColor.defaultColor).toJson());
      await openManageScreen(tester, ['Aura', 'Nausea', 'Aura'],
          prefs: {customButtonModelsKey: [model, other, model]});

      await pickColor(tester, 'Aura', 'Red');
      await addButton(tester, 'Dizzy');

      expect(circleColor(tester, 'Aura'), Colors.red);
      await unmountApp(tester);
    });

    testWidgets('colors survive deleting another button', (tester) async {
      await openManageScreen(tester, ['Aura', 'Nausea']);

      await pickColor(tester, 'Nausea', 'Red');
      await tester.tap(find.descendant(
          of: listRow('Aura'), matching: find.byIcon(Icons.delete)));
      await tester.pump();

      expect(circleColor(tester, 'Nausea'), Colors.red);
      await unmountApp(tester);
    });

    testWidgets('colors survive a relaunch', (tester) async {
      await openManageScreen(tester, ['Aura']);
      await pickColor(tester, 'Aura', 'Green');
      await backToMain(tester);
      await unmountApp(tester);

      await relaunchApp(tester);
      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Aura'));
      expect(button.style!.backgroundColor!.resolve({}), Colors.green);
      await unmountApp(tester);
    });
  });
}
