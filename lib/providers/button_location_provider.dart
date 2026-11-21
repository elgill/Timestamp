import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final buttonLocationProvider = NotifierProvider<ButtonLocationNotifier, ButtonLocation>(ButtonLocationNotifier.new);

class ButtonLocationNotifier extends Notifier<ButtonLocation> {
  @override
  ButtonLocation build() => ref.watch(sharedUtilityProvider).getButtonLocation();

  void setButtonLocation(ButtonLocation value) {
    ref.read(sharedUtilityProvider).setButtonLocation(value);
    state = value;
  }
}
