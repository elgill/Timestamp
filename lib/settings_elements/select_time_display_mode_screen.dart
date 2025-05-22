import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';

import '../providers/display_mode_provider.dart'; // Contains DisplayMode enum

class SelectTimeDisplayModeScreen extends ConsumerWidget {
  const SelectTimeDisplayModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DisplayMode currentMode = ref.watch(displayModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Time Display Mode')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile(
                title: const Text('Absolute Time'),
                description: const Text('Show actual time of day (e.g., 2:45:30 PM)'),
                trailing: trailingWidgetFor(DisplayMode.absolute, currentMode),
                onPressed: (context) {
                  ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.absolute);
                  Navigator.of(context).pop();
                },
              ),
              SettingsTile(
                title: const Text('Relative Time'),
                description: const Text('Show time relative to reference event (e.g., +0:02:15)'),
                trailing: trailingWidgetFor(DisplayMode.relative, currentMode),
                onPressed: (context) {
                  ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.relative);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(DisplayMode mode, DisplayMode currentMode) {
    if (mode == currentMode) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}