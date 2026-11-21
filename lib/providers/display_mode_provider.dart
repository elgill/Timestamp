import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

enum DisplayMode { absolute, relative }

final displayModeProvider =
    NotifierProvider<DisplayModeNotifier, DisplayMode>(DisplayModeNotifier.new);

class DisplayModeNotifier extends Notifier<DisplayMode> {
  @override
  DisplayMode build() {
    final savedMode = ref.watch(sharedUtilityProvider).getDisplayMode();
    return savedMode == 'DisplayMode.relative'
        ? DisplayMode.relative
        : DisplayMode.absolute;
  }

  void setDisplayMode(DisplayMode mode) {
    ref.read(sharedUtilityProvider).setDisplayMode(mode.toString());
    state = mode;
  }

  void toggleDisplayMode() {
    setDisplayMode(state == DisplayMode.absolute
        ? DisplayMode.relative
        : DisplayMode.absolute);
  }
}
