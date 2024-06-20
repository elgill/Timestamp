import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final buttonLocationProvider = StateNotifierProvider<ButtonLocationNotifier, ButtonLocation>((ref) {
  return ButtonLocationNotifier(ref: ref);
});

class ButtonLocationNotifier extends StateNotifier<ButtonLocation> {
  ButtonLocationNotifier({required this.ref}) : super(ButtonLocation.top) {
    state = ref.watch(sharedUtilityProvider).getButtonLocation();
  }
  Ref ref;

  void setButtonLocation(ButtonLocation value) {
    ref.watch(sharedUtilityProvider).setButtonLocation(value);
    state = value;
  }
}