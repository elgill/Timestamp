import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final customButtonNamesProvider = StateNotifierProvider<CustomButtonNamesNotifier, List<String>>((ref) {
  return CustomButtonNamesNotifier(ref: ref);
});

class CustomButtonNamesNotifier extends StateNotifier<List<String>> {
  CustomButtonNamesNotifier({required this.ref}) : super([]) {
    state = ref.watch(sharedUtilityProvider).getCustomEventButtonList();
  }
  Ref ref;

  void setCustomButtonNameList(List<String> value) {
    ref.watch(sharedUtilityProvider).setCustomEventButtonList(value);
    // A copy: callers change the current list in place, and setting the
    // same list back wouldn't tell listeners (like the watch sync) anything.
    state = [...value];
  }
}