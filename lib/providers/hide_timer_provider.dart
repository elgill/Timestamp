import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final hideTimerProvider = StateNotifierProvider<HideTimerNotifier, bool>((ref) {
  return HideTimerNotifier(ref: ref);
});

class HideTimerNotifier extends StateNotifier<bool> {
  HideTimerNotifier({required this.ref}) : super(false) {
    state = ref.watch(sharedUtilityProvider).getHideRunningTimer();
  }
  Ref ref;

  void setHideTimer(bool hide) {
    ref.watch(sharedUtilityProvider).setHideRunningTimer(hide);
    state = hide;
  }
}