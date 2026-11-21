import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final hideTimerProvider = NotifierProvider<HideTimerNotifier, bool>(HideTimerNotifier.new);

class HideTimerNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getHideRunningTimer();

  void setHideTimer(bool value) {
    ref.read(sharedUtilityProvider).setHideRunningTimer(value);
    state = value;
  }
}
