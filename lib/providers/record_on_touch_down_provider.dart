import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final recordOnTouchDownProvider = StateNotifierProvider<RecordOnTouchDownNotifier, bool>((ref) {
  return RecordOnTouchDownNotifier(ref: ref);
});

class RecordOnTouchDownNotifier extends StateNotifier<bool> {
  RecordOnTouchDownNotifier({required this.ref}) : super(false) {
    state = ref.watch(sharedUtilityProvider).getRecordOnTouchDown();
  }
  Ref ref;

  void setRecordOnTouchDown(bool value) {
    ref.watch(sharedUtilityProvider).setRecordOnTouchDown(value);
    state = value;
  }
}
