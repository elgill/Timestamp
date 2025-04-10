import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';

class SelectButtonColorScreen extends ConsumerWidget {
  final String buttonName;

  const SelectButtonColorScreen({
    Key? key,
    required this.buttonName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(customButtonModelsProvider.notifier).getButtonColor(buttonName);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Select Color for "$buttonName"')),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Colors'),
            tiles: PredefinedColor.values.map((color) {
              return SettingsTile(
                title: Text(color.displayName),
                leading: CircleAvatar(
                  backgroundColor: color.getColor(themeMode, context),
                  radius: 16,
                ),
                trailing: _buildTrailingWidget(color.getColor(themeMode, context), currentColor),
                onPressed: (context) {
                  ref.read(customButtonModelsProvider.notifier).updateButtonColor(
                      buttonName, color.getColor(themeMode, context));
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingWidget(Color color, Color currentColor) {
    if (color.value == currentColor.value) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}