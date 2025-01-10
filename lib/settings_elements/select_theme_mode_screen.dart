import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';

class SelectThemeModeScreen extends ConsumerWidget {
  const SelectThemeModeScreen({super.key});

  String getModeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeMode currentMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Theme')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: ThemeMode.values.map((mode) {
              return SettingsTile(
                title: Text(getModeDisplayName(mode)),
                trailing: trailingWidgetFor(mode, currentMode),
                onPressed: (context) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(ThemeMode mode, ThemeMode currentMode) {
    if (mode == currentMode) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}