import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final maxButtonRowsProvider = StateNotifierProvider<MaxButtonRowNotifier, int>((ref) {
  return MaxButtonRowNotifier(ref: ref);
});

class MaxButtonRowNotifier extends StateNotifier<int> {
  MaxButtonRowNotifier({required this.ref}) : super(1) {
    state = ref.watch(sharedUtilityProvider).getMaxButtonRows();
  }
  Ref ref;

  void setMaxButtonRows(int rows) {
    ref.watch(sharedUtilityProvider).setMaxButtonRows(rows);
    state = rows;
  }
}