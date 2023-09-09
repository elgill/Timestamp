import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/time_server.dart';


final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
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

  bool getDisableAutoLock() {
    final status = sharedPreferences.getBool(disableAutoLockKey);
    if (status == null) return true;
    return status;
  }

  void setDisableAutoLock(bool value) {
    sharedPreferences.setBool(disableAutoLockKey, value);
  }

}