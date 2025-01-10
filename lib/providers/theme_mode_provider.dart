import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref: ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier({required this.ref}) : super(ThemeMode.system) {
    state = ref.watch(sharedUtilityProvider).getThemeMode();
  }
  Ref ref;

  void setThemeMode(ThemeMode mode) {
    ref.watch(sharedUtilityProvider).setThemeMode(mode);
    state = mode;
  }
}