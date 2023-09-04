import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String sharedDarkModeKey = 'isDarkModeEnabled';
const String shareCameraResolutionKey = 'cameraResolution';

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

  bool is24HourTimeEnabled() {
    return sharedPreferences.getBool(sharedDarkModeKey) ?? false;
  }

  void set24HourTimeEnabled({required bool value}) {
    sharedPreferences.setBool(sharedDarkModeKey, value);
  }
}