import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final customButtonNamesProvider =
    NotifierProvider<CustomButtonNamesNotifier, List<String>>(
        CustomButtonNamesNotifier.new);

class CustomButtonNamesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.watch(sharedUtilityProvider).getCustomEventButtonList();

  void setCustomButtonNameList(List<String> value) {
    ref.read(sharedUtilityProvider).setCustomEventButtonList(value);
    // A copy: callers change the current list in place, and setting the
    // same list back wouldn't tell listeners (like the watch sync) anything.
    state = [...value];
  }
}
