import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final recordOnTouchDownProvider = NotifierProvider<RecordOnTouchDownNotifier, bool>(RecordOnTouchDownNotifier.new);

class RecordOnTouchDownNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getRecordOnTouchDown();

  void setRecordOnTouchDown(bool value) {
    ref.read(sharedUtilityProvider).setRecordOnTouchDown(value);
    state = value;
  }
}
