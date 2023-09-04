import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/enums/time_format.dart';

final is24HourTimeProvider = StateNotifierProvider<TimeFormatNotifier, TimeFormat>((ref) {
  return TimeFormatNotifier(ref: ref);
});

class TimeFormatNotifier extends StateNotifier<TimeFormat> {
  TimeFormatNotifier({required this.ref}) : super(TimeFormat.local24Hour) {
    state = ref.watch(sharedUtilityProvider).getTimeFormat();
  }
  Ref ref;

  void setTimeFormat(TimeFormat format) {
    ref.watch(sharedUtilityProvider).setTimeFormat(format);
    state = format;
  }
}