import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final timeServerProvider = NotifierProvider<TimeServerNotifier, TimeServer>(TimeServerNotifier.new);

class TimeServerNotifier extends Notifier<TimeServer> {
  @override
  TimeServer build() => ref.watch(sharedUtilityProvider).getTimeServer();

  void setTimeServer(TimeServer value) {
    ref.read(sharedUtilityProvider).setTimeServer(value);
    state = value;
  }
}
