import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final autoLockProvider = NotifierProvider<AutoLockNotifier, bool>(AutoLockNotifier.new);

class AutoLockNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getDisableAutoLock();

  void setAutoLock(bool value) {
    ref.read(sharedUtilityProvider).setDisableAutoLock(value);
    state = value;
  }
}
