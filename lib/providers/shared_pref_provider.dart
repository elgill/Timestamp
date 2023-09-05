import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/constants.dart';


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

}