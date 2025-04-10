import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/providers/max_button_rows_provider.dart';


class SelectMaxButtonRowsScreen extends ConsumerWidget {
  const SelectMaxButtonRowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int currentNumber = ref.watch(maxButtonRowsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Max Button Rows')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: List.generate(5, (index) {
              int number = index + 1;
              return SettingsTile(
                title: Text(number.toString()),
                trailing: trailingWidgetFor(number, currentNumber),
                onPressed: (context) {
                  ref.read(maxButtonRowsProvider.notifier).setMaxButtonRows(number);
                  Navigator.of(context).pop();
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(int number, int currentNumber) {
    if (number == currentNumber) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}