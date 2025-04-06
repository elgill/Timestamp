import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/models/button_config.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final buttonConfigsProvider = StateNotifierProvider<ButtonConfigsNotifier, List<ButtonConfig>>((ref) {
  return ButtonConfigsNotifier(ref: ref);
});

class ButtonConfigsNotifier extends StateNotifier<List<ButtonConfig>> {
  ButtonConfigsNotifier({required this.ref}) : super([]) {
    state = ref.watch(sharedUtilityProvider).getButtonConfigs();
  }
  Ref ref;

  void setButtonConfigs(List<ButtonConfig> configs) {
    ref.watch(sharedUtilityProvider).setButtonConfigs(configs);
    state = configs;
  }

  void updateButtonColor(int index, Color color) {
    List<ButtonConfig> updatedConfigs = List.from(state);
    updatedConfigs[index] = updatedConfigs[index].copyWith(color: color);
    setButtonConfigs(updatedConfigs);
  }

  void addButton(String name, [Color? color]) {
    List<ButtonConfig> updatedConfigs = List.from(state);
    updatedConfigs.add(ButtonConfig(
      name: name,
      color: color ?? Colors.teal,
    ));
    setButtonConfigs(updatedConfigs);
  }

  void removeButton(int index) {
    List<ButtonConfig> updatedConfigs = List.from(state);
    updatedConfigs.removeAt(index);
    setButtonConfigs(updatedConfigs);
  }

  void reorderButtons(int oldIndex, int newIndex) {
    List<ButtonConfig> updatedConfigs = List.from(state);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = updatedConfigs.removeAt(oldIndex);
    updatedConfigs.insert(newIndex, item);
    setButtonConfigs(updatedConfigs);
  }
}