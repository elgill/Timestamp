import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/time_server.dart';

import '../models/button_config.dart';


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

  List<ButtonConfig> getButtonConfigs() {
    final List<String>? jsonList = sharedPreferences.getStringList(buttonConfigsKey);
    if (jsonList == null) {
      // Convert existing button names to ButtonConfig objects
      final List<String> legacyNames = getCustomEventButtonList();
      return legacyNames.map((name) => ButtonConfig(name: name)).toList();
    }
    return jsonList.map((json) => ButtonConfig.fromJson(json)).toList();
  }

  void setButtonConfigs(List<ButtonConfig> configs) {
    final List<String> jsonList = configs.map((config) => config.toJson()).toList();
    sharedPreferences.setStringList(buttonConfigsKey, jsonList);

    // Also update the legacy custom event names for backward compatibility
    setCustomEventButtonList(configs.map((config) => config.name).toList());
  }

}