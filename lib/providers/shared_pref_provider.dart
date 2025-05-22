import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/models/button_model.dart';

import '../enums/predefined_colors.dart';


final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // This is overwritten in main.dart
  throw UnimplementedError();
});

final sharedUtilityProvider = Provider<SharedUtility>((ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  return SharedUtility(sharedPreferences: sharedPrefs);
});

class SharedUtility {
  SharedUtility({
    required this.sharedPreferences,
  });

  final SharedPreferences sharedPreferences;

  TimeFormat getTimeFormat() {
    final format = sharedPreferences.getString(sharedTimeFormatKey);
    if (format == null) return TimeFormat.local24Hour;
    return TimeFormat.values.firstWhere((e) => e.toString() == format);
  }

  void setTimeFormat(TimeFormat format) {
    sharedPreferences.setString(sharedTimeFormatKey, format.toString());
  }

  TimeServer getTimeServer() {
    final value = sharedPreferences.getString(sharedTimeServerKey);
    if (value == null) return TimeServer.timeGoogleCom;
    return TimeServer.values.firstWhere((e) => e.toString() == value);
  }

  void setTimeServer(TimeServer value) {
    sharedPreferences.setString(sharedTimeServerKey, value.toString());
  }

  ButtonLocation getButtonLocation() {
    final format = sharedPreferences.getString(buttonLocationKey);
    if (format == null) return ButtonLocation.top;
    return ButtonLocation.values.firstWhere((e) => e.toString() == format);
  }

  void setButtonLocation(ButtonLocation location) {
    sharedPreferences.setString(buttonLocationKey, location.toString());
  }

  bool getDisableAutoLock() {
    final status = sharedPreferences.getBool(disableAutoLockKey);
    if (status == null) return true;
    return status;
  }

  void setDisableAutoLock(bool value) {
    sharedPreferences.setBool(disableAutoLockKey, value);
  }

  List<String> getCustomEventButtonList() {
    final status = sharedPreferences.getStringList(customEventNamesKey);
    if (status == null) return [];
    return status;
  }

  void setCustomEventButtonList(List<String> value) {
    sharedPreferences.setStringList(customEventNamesKey, value);
  }

  List<ButtonModel> getCustomButtonModels() {
    final modelStrings = sharedPreferences.getStringList(customButtonModelsKey);
    if (modelStrings == null || modelStrings.isEmpty) {
      // Convert existing button names to models with default color if available
      final buttonNames = getCustomEventButtonList();
      return buttonNames.map((name) => ButtonModel(name, PredefinedColor.defaultColor)).toList();
    }

    try {
      return modelStrings
          .map((str) => ButtonModel.fromJson(jsonDecode(str)))
          .toList();
    } catch (e) {
      // If there's an error, try to migrate from the old format
      try {
        return _migrateFromOldButtonModelFormat(modelStrings);
      } catch (e) {
        // Fallback to default if there's an error
        return [];
      }
    }
  }

// Helper method to migrate from old format (with raw Color values) to new format (with PredefinedColor)
  List<ButtonModel> _migrateFromOldButtonModelFormat(List<String> modelStrings) {
    return modelStrings.map((str) {
      final data = jsonDecode(str);
      final name = data['name'] as String;
      final colorValue = data['color'] as int;
      final color = Color(colorValue);

      // Try to map the old color to a predefined color
      final predefinedColor = PredefinedColorExtension.fromColor(color);
      return ButtonModel(name, predefinedColor);
    }).toList();
  }

  void setCustomButtonModels(List<ButtonModel> models) {
    final modelStrings = models
        .map((model) => jsonEncode(model.toJson()))
        .toList();
    sharedPreferences.setStringList(customButtonModelsKey, modelStrings);
  }

  int getMaxButtonRows() {
    final status = sharedPreferences.getInt(maxButtonRowsKey);
    if (status == null) return 1;
    return status;
  }

  void setMaxButtonRows(int value) {
    sharedPreferences.setInt(maxButtonRowsKey, value);
  }

  ThemeMode getThemeMode() {
    final mode = sharedPreferences.getString(themeModeKey);
    if (mode == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
          (e) => e.toString() == mode,
      orElse: () => ThemeMode.system,
    );
  }

  void setThemeMode(ThemeMode mode) {
    sharedPreferences.setString(themeModeKey, mode.toString());
  }

  bool getHideRunningTimer() {
    final status = sharedPreferences.getBool(hideRunningTimerKey);
    if (status == null) return false; // Default to showing timer
    return status;
  }

  void setHideRunningTimer(bool value) {
    sharedPreferences.setBool(hideRunningTimerKey, value);
  }
}