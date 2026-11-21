import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(sharedUtilityProvider).getThemeMode();

  void setThemeMode(ThemeMode value) {
    ref.read(sharedUtilityProvider).setThemeMode(value);
    state = value;
  }
}
