import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/providers/auto_lock_provider.dart';
import 'package:timestamp/providers/button_location_provider.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';
import 'package:timestamp/providers/display_mode_provider.dart';
import 'package:timestamp/providers/export_accuracy_provider.dart';
import 'package:timestamp/providers/hide_timer_provider.dart';
import 'package:timestamp/providers/max_button_rows_provider.dart';
import 'package:timestamp/providers/record_on_touch_down_provider.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';
import 'package:timestamp/providers/time_format_provider.dart';
import 'package:timestamp/providers/time_server_provider.dart';

Future<SharedUtility> utilityWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedUtility(sharedPreferences: await SharedPreferences.getInstance());
}

/// A provider container on the given saved settings.
Future<ProviderContainer> containerWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

/// Same container setup on the current prefs, like relaunching the app.
Future<ProviderContainer> relaunched() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sharedPreferencesProvider must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(sharedPreferencesProvider), throwsA(anything));
  });

  group('defaults on a fresh install', () {
    late SharedUtility utility;
    setUp(() async => utility = await utilityWith({}));

    test('all settings', () {
      expect(utility.getTimeFormat(), TimeFormat.local24Hour);
      expect(utility.getTimeServer(), TimeServer.timeGoogleCom);
      expect(utility.getButtonLocation(), ButtonLocation.top);
      expect(utility.getDisableAutoLock(), isTrue);
      expect(utility.getCustomEventButtonList(), isEmpty);
      expect(utility.getCustomButtonModels(), isEmpty);
      expect(utility.getMaxButtonRows(), 1);
      expect(utility.getThemeMode(), ThemeMode.system);
      expect(utility.getHideRunningTimer(), isFalse);
      expect(utility.getDisplayMode(), 'DisplayMode.absolute');
      expect(utility.getExportAccuracy(), isFalse);
      expect(utility.getRecordOnTouchDown(), isFalse);
    });
  });

  test('stored setting keys never change', () {
    // Renaming a key silently resets that setting for existing users.
    expect({
      sharedTimeFormatKey,
      sharedTimeServerKey,
      disableAutoLockKey,
      referenceEventKey,
      buttonLocationKey,
      customEventNamesKey,
      customButtonModelsKey,
      maxButtonRowsKey,
      themeModeKey,
      hideRunningTimerKey,
      displayModeKey,
      exportAccuracyKey,
      recordOnTouchDownKey,
    }, {
      'timeFormat',
      'timeServer',
      'autoLockEnable',
      'referenceEvent',
      'buttonSectionLocation',
      'customEventNames',
      'customButtonModels',
      'maxButtonRows',
      'themeMode',
      'hideRunningTimer',
      'displayMode',
      'exportAccuracy',
      'recordOnTouchDown',
    });
  });

  group('values written by existing installs still load', () {
    test('enum settings', () async {
      final utility = await utilityWith({
        sharedTimeFormatKey: 'TimeFormat.utc24Hour',
        sharedTimeServerKey: 'TimeServer.timeCloudflareCom',
        buttonLocationKey: 'ButtonLocation.bottom',
        themeModeKey: 'ThemeMode.dark',
      });
      expect(utility.getTimeFormat(), TimeFormat.utc24Hour);
      expect(utility.getTimeServer(), TimeServer.timeCloudflareCom);
      expect(utility.getButtonLocation(), ButtonLocation.bottom);
      expect(utility.getThemeMode(), ThemeMode.dark);
    });

    test('an unknown theme falls back to system', () async {
      final utility = await utilityWith({themeModeKey: 'ThemeMode.sepia'});
      expect(utility.getThemeMode(), ThemeMode.system);
    });
  });

  group('button models', () {
    test('built from plain names when no models were saved yet', () async {
      final utility = await utilityWith({
        customEventNamesKey: ['Aura', 'Nausea']
      });
      expect(utility.getCustomButtonModels(), [
        ButtonModel('Aura', PredefinedColor.defaultColor),
        ButtonModel('Nausea', PredefinedColor.defaultColor),
      ]);
    });

    test('an empty saved list also falls back to names', () async {
      final utility = await utilityWith({
        customEventNamesKey: ['Aura'],
        customButtonModelsKey: <String>[],
      });
      expect(utility.getCustomButtonModels().single.name, 'Aura');
    });

    test('save and load', () async {
      final utility = await utilityWith({});
      final models = [
        ButtonModel('Aura', PredefinedColor.purple),
        ButtonModel('Nausea', PredefinedColor.defaultColor),
      ];
      utility.setCustomButtonModels(models);
      expect(utility.getCustomButtonModels(), models);
    });

    test('the old raw-color format still loads its button names', () async {
      final utility = await utilityWith({
        customButtonModelsKey: [
          jsonEncode({'name': 'Aura', 'color': 0xFF123456}),
        ]
      });
      expect(utility.getCustomButtonModels(),
          [ButtonModel('Aura', PredefinedColor.defaultColor)]);
    });

    test('the old raw-color format keeps palette colors', () async {
      final utility = await utilityWith({
        customButtonModelsKey: [
          jsonEncode({'name': 'Aura', 'color': Colors.red.toARGB32()}),
          jsonEncode({'name': 'Dizzy', 'color': Colors.green.toARGB32()}),
          jsonEncode({'name': 'Fog', 'color': Colors.orange.toARGB32()}),
          jsonEncode({'name': 'Rest', 'color': Colors.purple.toARGB32()}),
        ]
      });
      expect(utility.getCustomButtonModels(), [
        ButtonModel('Aura', PredefinedColor.red),
        ButtonModel('Dizzy', PredefinedColor.green),
        ButtonModel('Fog', PredefinedColor.orange),
        ButtonModel('Rest', PredefinedColor.purple),
      ]);
    });

    test('unreadable data gives no models rather than a crash', () async {
      final utility = await utilityWith({
        customButtonModelsKey: ['{not json']
      });
      expect(utility.getCustomButtonModels(), isEmpty);
    });
  });

  // Every setting: the notifier loads the saved value, changing it updates
  // state immediately, and the change survives a relaunch.
  group('settings notifiers', () {
    test('auto lock', () async {
      final c = await containerWith({disableAutoLockKey: false});
      expect(c.read(autoLockProvider), isFalse);
      c.read(autoLockProvider.notifier).setAutoLock(true);
      expect(c.read(autoLockProvider), isTrue);
      expect((await relaunched()).read(autoLockProvider), isTrue);
    });

    test('button location', () async {
      final c = await containerWith({});
      expect(c.read(buttonLocationProvider), ButtonLocation.top);
      c.read(buttonLocationProvider.notifier)
          .setButtonLocation(ButtonLocation.bottom);
      expect(c.read(buttonLocationProvider), ButtonLocation.bottom);
      expect((await relaunched()).read(buttonLocationProvider),
          ButtonLocation.bottom);
    });

    test('button names', () async {
      final c = await containerWith({});
      expect(c.read(customButtonNamesProvider), isEmpty);
      c.read(customButtonNamesProvider.notifier)
          .setCustomButtonNameList(['Aura']);
      expect(c.read(customButtonNamesProvider), ['Aura']);
      expect((await relaunched()).read(customButtonNamesProvider), ['Aura']);
    });

    test('export accuracy', () async {
      final c = await containerWith({});
      expect(c.read(exportAccuracyProvider), isFalse);
      c.read(exportAccuracyProvider.notifier).setExportAccuracy(true);
      expect(c.read(exportAccuracyProvider), isTrue);
      expect((await relaunched()).read(exportAccuracyProvider), isTrue);
    });

    test('hide timer', () async {
      final c = await containerWith({});
      expect(c.read(hideTimerProvider), isFalse);
      c.read(hideTimerProvider.notifier).setHideTimer(true);
      expect(c.read(hideTimerProvider), isTrue);
      expect((await relaunched()).read(hideTimerProvider), isTrue);
    });

    test('max button rows', () async {
      final c = await containerWith({});
      expect(c.read(maxButtonRowsProvider), 1);
      c.read(maxButtonRowsProvider.notifier).setMaxButtonRows(4);
      expect(c.read(maxButtonRowsProvider), 4);
      expect((await relaunched()).read(maxButtonRowsProvider), 4);
    });

    test('record on touch down', () async {
      final c = await containerWith({});
      expect(c.read(recordOnTouchDownProvider), isFalse);
      c.read(recordOnTouchDownProvider.notifier).setRecordOnTouchDown(true);
      expect(c.read(recordOnTouchDownProvider), isTrue);
      expect((await relaunched()).read(recordOnTouchDownProvider), isTrue);
    });

    test('theme mode', () async {
      final c = await containerWith({});
      expect(c.read(themeModeProvider), ThemeMode.system);
      c.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(c.read(themeModeProvider), ThemeMode.dark);
      expect((await relaunched()).read(themeModeProvider), ThemeMode.dark);
    });

    test('time format', () async {
      final c = await containerWith({});
      expect(c.read(is24HourTimeProvider), TimeFormat.local24Hour);
      c.read(is24HourTimeProvider.notifier).setTimeFormat(TimeFormat.utc24Hour);
      expect(c.read(is24HourTimeProvider), TimeFormat.utc24Hour);
      expect((await relaunched()).read(is24HourTimeProvider),
          TimeFormat.utc24Hour);
    });

    test('time server', () async {
      final c = await containerWith({});
      expect(c.read(timeServerProvider), TimeServer.timeGoogleCom);
      c.read(timeServerProvider.notifier).setTimeServer(TimeServer.poolNtpOrg);
      expect(c.read(timeServerProvider), TimeServer.poolNtpOrg);
      expect((await relaunched()).read(timeServerProvider),
          TimeServer.poolNtpOrg);
    });

    test('display mode', () async {
      final c = await containerWith({});
      expect(c.read(displayModeProvider), DisplayMode.absolute);
      c.read(displayModeProvider.notifier).toggleDisplayMode();
      expect(c.read(displayModeProvider), DisplayMode.relative);
      expect(
          (await relaunched()).read(displayModeProvider), DisplayMode.relative);
      c.read(displayModeProvider.notifier).toggleDisplayMode();
      expect(c.read(displayModeProvider), DisplayMode.absolute);
      c.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.relative);
      expect(c.read(displayModeProvider), DisplayMode.relative);
    });
  });

  group('CustomButtonModelsNotifier', () {
    late ProviderContainer c;
    CustomButtonModelsNotifier notifier() =>
        c.read(customButtonModelsProvider.notifier);
    List<ButtonModel> models() => c.read(customButtonModelsProvider);

    setUp(() async {
      c = await containerWith({
        customEventNamesKey: ['Aura', 'Nausea']
      });
    });

    test('changes the color of an existing button in place', () {
      notifier().updateButtonColor('Nausea', PredefinedColor.red);
      expect(models(), [
        ButtonModel('Aura', PredefinedColor.defaultColor),
        ButtonModel('Nausea', PredefinedColor.red),
      ]);
    });

    test('adds a model for a button it did not know', () {
      notifier().updateButtonColor('Dizzy', PredefinedColor.green);
      expect(models().last, ButtonModel('Dizzy', PredefinedColor.green));
      expect(models(), hasLength(3));
    });

    test('color changes survive a relaunch', () async {
      notifier().updateButtonColor('Aura', PredefinedColor.orange);
      final restored = await relaunched();
      expect(
          restored
              .read(customButtonModelsProvider.notifier)
              .getButtonPredefinedColor('Aura'),
          PredefinedColor.orange);
    });

    test('unknown buttons report the default color', () {
      expect(notifier().getButtonPredefinedColor('nope'),
          PredefinedColor.defaultColor);
    });

    test('removes a model by name', () {
      notifier().removeButtonModel('Aura');
      expect(models().map((m) => m.name), ['Nausea']);
    });

    test('syncing keeps colors, follows the new names and order', () {
      notifier().updateButtonColor('Nausea', PredefinedColor.red);
      notifier().syncWithButtonNames(['Dizzy', 'Nausea']);
      expect(models(), [
        ButtonModel('Dizzy', PredefinedColor.defaultColor),
        ButtonModel('Nausea', PredefinedColor.red),
      ]);
    });

    testWidgets('getButtonColor resolves through the current theme',
        (tester) async {
      notifier().updateButtonColor('Aura', PredefinedColor.purple);
      late Color named, unknown, primary;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        named = notifier().getButtonColor('Aura', context);
        unknown = notifier().getButtonColor('nope', context);
        primary = Theme.of(context).colorScheme.primary;
        return const SizedBox();
      })));
      expect(named, Colors.purple);
      expect(unknown, primary);
    });
  });
}
