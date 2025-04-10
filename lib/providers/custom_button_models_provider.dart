import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';

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

  void updateButtonColor(String name, PredefinedColor predefinedColor) {
    final updatedModels = [...state];
    final index = updatedModels.indexWhere((model) => model.name == name);

    if (index != -1) {
      updatedModels[index] = ButtonModel(name, predefinedColor);
    } else {
      updatedModels.add(ButtonModel(name, predefinedColor));
    }

    setCustomButtonModels(updatedModels);
  }

  Color getButtonColor(String name, BuildContext context) {
    final model = state.firstWhere(
          (model) => model.name == name,
      orElse: () => ButtonModel(name, PredefinedColor.defaultColor),
    );

    final themeMode = ref.watch(themeModeProvider);
    return model.predefinedColor.getColor(themeMode, context);
  }

  PredefinedColor getButtonPredefinedColor(String name) {
    final model = state.firstWhere(
          (model) => model.name == name,
      orElse: () => ButtonModel(name, PredefinedColor.defaultColor),
    );

    return model.predefinedColor;
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
          : ButtonModel(name, PredefinedColor.defaultColor);
    }).toList();

    setCustomButtonModels(updatedModels);
  }
}