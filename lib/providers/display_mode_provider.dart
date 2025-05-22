import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

enum DisplayMode { absolute, relative }

final displayModeProvider = StateNotifierProvider<DisplayModeNotifier, DisplayMode>((ref) {
  return DisplayModeNotifier(ref: ref);
});

class DisplayModeNotifier extends StateNotifier<DisplayMode> {
  DisplayModeNotifier({required this.ref}) : super(DisplayMode.absolute) {
    // Load saved display mode
    final savedMode = ref.watch(sharedUtilityProvider).getDisplayMode();
    state = savedMode == 'DisplayMode.relative' ? DisplayMode.relative : DisplayMode.absolute;
  }
  Ref ref;

  void setDisplayMode(DisplayMode mode) {
    ref.watch(sharedUtilityProvider).setDisplayMode(mode.toString());
    state = mode;
  }

  void toggleDisplayMode() {
    final newMode = state == DisplayMode.absolute ? DisplayMode.relative : DisplayMode.absolute;
    setDisplayMode(newMode);
  }
}