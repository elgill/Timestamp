import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/providers/auto_lock_provider.dart';
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
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('General'),
            tiles: [
              SettingsTile.navigation(
                title: const Text('Time Format'),
                leading: const Icon(Icons.access_time),
                value: Text(ref.watch(is24HourTimeProvider).displayName),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return _SelectTimeFormatScreen();
                        }));
                  }
              ),
              SettingsTile.switchTile(
                  title: const Text('Disable Auto Lock'),
                  leading: const Icon(Icons.lock),
                  initialValue: ref.watch(autoLockProvider),
                  onToggle: (bool value) {
                    ref.read(autoLockProvider.notifier).setAutoLock(value);
                  }
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Links'),
            tiles: [
              SettingsTile(
                title: const Text('Privacy Policy'),
                leading: const Icon(Icons.privacy_tip),
                onPressed: (BuildContext context) {
                  _launchURL('https://gillin.dev/privacy');
                },
              ),
              SettingsTile(
                title: const Text('Feedback & Support'),
                leading: const Icon(Icons.feedback),
                onPressed: (BuildContext context) {
                  _launchURL('https://gillin.dev/#contact');
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('App Details'),
            tiles: [
              SettingsTile(
                title: packageInfoAsyncValue.when(
                  data: (packageInfo) =>
                      Text('Version: ${packageInfo.version}'),
                  loading: () => const Text('Version: Fetching...'),
                  error: (err, stack) => const Text('Version: Error fetching'),
                ),
                leading: const Icon(Icons.info),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/*class _TimeFormat extends StatefulWidget {
  const _TimeFormat({super.key});

  @override
  State<_TimeFormat> createState() => __TimeFormat();
}*/


class _SelectTimeFormatScreen extends ConsumerWidget {
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

