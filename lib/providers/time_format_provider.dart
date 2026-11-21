import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final is24HourTimeProvider = NotifierProvider<TimeFormatNotifier, TimeFormat>(TimeFormatNotifier.new);

class TimeFormatNotifier extends Notifier<TimeFormat> {
  @override
  TimeFormat build() => ref.watch(sharedUtilityProvider).getTimeFormat();

  void setTimeFormat(TimeFormat value) {
    ref.read(sharedUtilityProvider).setTimeFormat(value);
    state = value;
  }
}
