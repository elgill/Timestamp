import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/providers/time_server_provider.dart';

class SelectTimeServerScreen extends ConsumerWidget {
  const SelectTimeServerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TimeServer currentServer = ref.watch(timeServerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Time Server')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: TimeServer.values.map((server) {
              return SettingsTile(
                title: Text(server.displayName),
                trailing: trailingWidgetFor(server, currentServer),
                onPressed: (context) {
                  ref.read(timeServerProvider.notifier).setTimeServer(server);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(TimeServer server, TimeServer currentServer) {
    if (server == currentServer) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}
