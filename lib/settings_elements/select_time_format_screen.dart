import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/providers/time_format_provider.dart';

class SelectTimeFormatScreen extends ConsumerWidget {
  const SelectTimeFormatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TimeFormat currentFormat = ref.watch(is24HourTimeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Time Format')),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: TimeFormat.values.map((format) {
              return SettingsTile(
                title: Text(format.displayName),
                trailing: trailingWidgetFor(format, currentFormat),
                onPressed: (context) {
                  ref.read(is24HourTimeProvider.notifier).setTimeFormat(format);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget trailingWidgetFor(TimeFormat format, TimeFormat currentFormat) {
    if (format == currentFormat) {
      return const Icon(Icons.check, color: Colors.blue);
    } else {
      return Container();
    }
  }
}
