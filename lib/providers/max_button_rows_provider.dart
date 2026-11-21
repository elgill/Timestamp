import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final maxButtonRowsProvider = NotifierProvider<MaxButtonRowNotifier, int>(MaxButtonRowNotifier.new);

class MaxButtonRowNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(sharedUtilityProvider).getMaxButtonRows();

  void setMaxButtonRows(int value) {
    ref.read(sharedUtilityProvider).setMaxButtonRows(value);
    state = value;
  }
}
