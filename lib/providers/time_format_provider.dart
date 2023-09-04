import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final is24HourTimeProvider = StateNotifierProvider<TimeFormatNotifier, bool>((ref) {
  return TimeFormatNotifier(ref: ref);
});

class TimeFormatNotifier extends StateNotifier<bool> {
  TimeFormatNotifier({required this.ref}) : super(true) {
    state = ref.watch(sharedUtilityProvider).is24HourTimeEnabled();
  }
  Ref ref;

  void toggleSetting() {
    ref.watch(sharedUtilityProvider).set24HourTimeEnabled(
      value: !ref.watch(sharedUtilityProvider).is24HourTimeEnabled(),
    );
    state = ref.watch(sharedUtilityProvider).is24HourTimeEnabled();
  }
}