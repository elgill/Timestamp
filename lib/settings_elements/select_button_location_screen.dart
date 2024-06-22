import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/providers/button_location_provider.dart';

class SelectButtonLocationScreen extends ConsumerWidget {
  const SelectButtonLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ButtonLocation currentLocation = ref.watch(buttonLocationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Button Location')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: ButtonLocation.values.map((location) {
              return SettingsTile(
                title: Text(location.displayName),
                trailing: trailingWidgetFor(location, currentLocation),
                onPressed: (context) {
                  ref.read(buttonLocationProvider.notifier).setButtonLocation(location);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(ButtonLocation location, ButtonLocation currentLocation) {
    if (location == currentLocation) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}
