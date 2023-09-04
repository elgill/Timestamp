import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timestamp/app_providers.dart';
import 'package:timestamp/enums/time_format.dart';

import 'package:timestamp/providers/time_format_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsyncValue = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Time Format'),
            trailing: _timeFormatDropdown(ref),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              _launchURL('https://gillin.dev/privacy');
            },
          ),
          ListTile(
            title: const Text('Feedback & Support'),
            onTap: () {
              _launchURL('https://gillin.dev/#contact');
            },
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: packageInfoAsyncValue.when(
              data: (packageInfo) => Text(packageInfo.version),
              loading: () => const Text('Fetching version...'),
              error: (err, stack) => const Text('Error fetching version'),
            ),
          )
        ],
      ),
    );
  }

  DropdownButton<TimeFormat> _timeFormatDropdown(WidgetRef ref) {
    return DropdownButton<TimeFormat>(
      value: ref.watch(is24HourTimeProvider),
      onChanged: (newValue) {
        if (newValue != null) {
          ref.read(is24HourTimeProvider.notifier).setTimeFormat(newValue);
        }
      },
      items: TimeFormat.values.map((TimeFormat format) {
        return DropdownMenuItem<TimeFormat>(
          value: format,
          child: Text(format.displayName),
        );
      }).toList(),
    );
  }

}
