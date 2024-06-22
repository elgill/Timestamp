import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/providers/auto_lock_provider.dart';
import 'package:timestamp/providers/button_location_provider.dart';
import 'package:timestamp/providers/time_server_provider.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/services/share_service.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/time_format_provider.dart';
import 'select_time_format_screen.dart';
import 'select_time_server_screen.dart';
import 'select_button_location_screen.dart';
import 'manual_event_entry_screen.dart';
import 'manage_button_names_screen.dart';
import 'package:timestamp/app_providers.dart';

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
                  title: const Text('Time Server'),
                  leading: const Icon(Icons.cloud),
                  value: Text(ref.watch(timeServerProvider).displayName),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return const SelectTimeServerScreen();
                        }));
                  }),
              SettingsTile.navigation(
                  title: const Text('Time Format'),
                  leading: const Icon(Icons.access_time),
                  value: Text(ref.watch(is24HourTimeProvider).displayName),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return const SelectTimeFormatScreen();
                        }));
                  }),
              SettingsTile.navigation(
                  title: const Text('Button Location'),
                  leading: const Icon(Icons.access_time),
                  value: Text(ref.watch(buttonLocationProvider).displayName),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return const SelectButtonLocationScreen();
                        }));
                  }),
              SettingsTile.navigation(
                  title: const Text('Custom Button Names'),
                  leading: const Icon(Icons.text_fields),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return const ManageButtonNamesScreen();
                        }));
                  }),
              SettingsTile.switchTile(
                  title: const Text('Disable Auto Lock'),
                  leading: const Icon(Icons.lock),
                  initialValue: ref.watch(autoLockProvider),
                  onToggle: (bool value) {
                    ref.read(autoLockProvider.notifier).setAutoLock(value);
                  }),
            ],
          ),
          SettingsSection(
            title: const Text('Data'),
            tiles: [
              SettingsTile.navigation(
                  title: const Text('Manual Event Entry'),
                  leading: const Icon(Icons.event),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                          return const ManualEventEntryScreen();
                        }));
                  }),
              SettingsTile(
                  title: const Text('Share Event Log'),
                  leading: const Icon(Icons.share),
                  onPressed: (context) {
                    exportAndShareEventsPlainText(ref.watch(eventServiceProvider).events, ref.watch(is24HourTimeProvider));
                  }),
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
