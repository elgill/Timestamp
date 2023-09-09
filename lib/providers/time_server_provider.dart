import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final timeServerProvider = StateNotifierProvider<TimeServerNotifier, TimeServer>((ref) {
  return TimeServerNotifier(ref: ref);
});

class TimeServerNotifier extends StateNotifier<TimeServer> {
  TimeServerNotifier({required this.ref}) : super(TimeServer.timeGoogleCom) {
    state = ref.watch(sharedUtilityProvider).getTimeServer();
  }
  Ref ref;

  void setTimeServer(TimeServer value) {
    ref.watch(sharedUtilityProvider).setTimeServer(value);
    state = value;
  }
}