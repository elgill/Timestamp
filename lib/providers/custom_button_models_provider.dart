import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final customButtonModelsProvider = StateNotifierProvider<CustomButtonModelsNotifier, List<ButtonModel>>((ref) {
  return CustomButtonModelsNotifier(ref: ref);
});

class CustomButtonModelsNotifier extends StateNotifier<List<ButtonModel>> {
  CustomButtonModelsNotifier({required this.ref}) : super([]) {
    state = ref.watch(sharedUtilityProvider).getCustomButtonModels();
  }
  Ref ref;

  void setCustomButtonModels(List<ButtonModel> models) {
    ref.watch(sharedUtilityProvider).setCustomButtonModels(models);
    state = models;
  }

  void updateButtonColor(String name, Color color) {
    final updatedModels = [...state];
    final index = updatedModels.indexWhere((model) => model.name == name);

    if (index != -1) {
      updatedModels[index] = ButtonModel(name, color);
    } else {
      updatedModels.add(ButtonModel(name, color));
    }

    setCustomButtonModels(updatedModels);
  }

  Color getButtonColor(String name) {
    final model = state.firstWhere(
          (model) => model.name == name,
      orElse: () => ButtonModel(name, Colors.teal), // Default color
    );

    return model.color;
  }

  void removeButtonModel(String name) {
    final updatedModels = state.where((model) => model.name != name).toList();
    setCustomButtonModels(updatedModels);
  }

  // When button names are updated, ensure our models stay in sync
  void syncWithButtonNames(List<String> buttonNames) {
    // Create a map of current models by name
    final Map<String, ButtonModel> modelMap = {
      for (var model in state) model.name: model
    };

    // Create new list of models based on button names
    final List<ButtonModel> updatedModels = buttonNames.map((name) {
      // Reuse existing model if available, otherwise create new one with default color
      return modelMap.containsKey(name)
          ? modelMap[name]!
          : ButtonModel(name, Colors.teal);
    }).toList();

    setCustomButtonModels(updatedModels);
  }
}