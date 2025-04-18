// settings_elements/select_button_color_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';

class SelectButtonColorScreen extends ConsumerWidget {
  final String buttonName;
  final PredefinedColor? initialColor;
  final Function(PredefinedColor)? onColorSelected;

  const SelectButtonColorScreen({
    Key? key,
    required this.buttonName,
    this.initialColor,
    this.onColorSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If initialColor is provided, use it (for manual events)
    // Otherwise get from provider (for button configuration)
    final currentPredefinedColor = initialColor ??
        ref.watch(customButtonModelsProvider.notifier)
            .getButtonPredefinedColor(buttonName);

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Color')),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Colors'),
            tiles: PredefinedColor.values.map((predefinedColor) {
              return SettingsTile(
                title: Text(predefinedColor.displayName),
                leading: CircleAvatar(
                  backgroundColor: predefinedColor.getColor(themeMode, context),
                  radius: 16,
                ),
                trailing: _buildTrailingWidget(predefinedColor, currentPredefinedColor),
                onPressed: (context) {
                  // Handle color selection based on context
                  if (onColorSelected != null) {
                    // For manual events, directly call the callback
                    onColorSelected!(predefinedColor);
                  } else {
                    // For button configuration, update the provider
                    ref.read(customButtonModelsProvider.notifier).updateButtonColor(
                        buttonName, predefinedColor);
                    // This forces a rebuild of the customButtonModelsProvider
                    ref.invalidate(customButtonModelsProvider);
                  }
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingWidget(PredefinedColor color, PredefinedColor currentColor) {
    if (color == currentColor) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}