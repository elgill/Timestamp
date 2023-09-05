import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final autoLockProvider = StateNotifierProvider<AutoLockNotifier, bool>((ref) {
  return AutoLockNotifier(ref: ref);
});

class AutoLockNotifier extends StateNotifier<bool> {
  AutoLockNotifier({required this.ref}) : super(true) {
    state = ref.watch(sharedUtilityProvider).getDisableAutoLock();
  }
  Ref ref;

  void setAutoLock(bool enable) {
    ref.watch(sharedUtilityProvider).setDisableAutoLock(enable);
    state = enable;
  }
}