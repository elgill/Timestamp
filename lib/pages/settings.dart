import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/providers/auto_lock_provider.dart';
import 'package:timestamp/providers/time_server_provider.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/utils/time_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timestamp/app_providers.dart';
import 'package:timestamp/enums/time_format.dart';

import 'package:timestamp/providers/time_format_provider.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/models/event.dart';
import 'dart:io' show Platform;


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
                      return _SelectTimeServerScreen();
                    }));
                  }),
              SettingsTile.navigation(
                  title: const Text('Time Format'),
                  leading: const Icon(Icons.access_time),
                  value: Text(ref.watch(is24HourTimeProvider).displayName),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return _SelectTimeFormatScreen();
                    }));
                  }),
              SettingsTile.switchTile(
                  title: const Text('Disable Auto Lock'),
                  leading: const Icon(Icons.lock),
                  initialValue: ref.watch(autoLockProvider),
                  onToggle: (bool value) {
                    ref.read(autoLockProvider.notifier).setAutoLock(value);
                  }),
              SettingsTile.navigation(
                  title: const Text('Manual Event Entry'),
                  leading: const Icon(Icons.event),
                  onPressed: (context) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return _ManualEventEntryScreen();
                    }));
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

class _SelectTimeServerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TimeServer currentServer =
        ref.watch(timeServerProvider); // Assuming you have a timeServerProvider
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

class _ManualEventEntryScreen extends ConsumerStatefulWidget {
  @override
  _ManualEventEntryScreenState createState() => _ManualEventEntryScreenState();
}

class _ManualEventEntryScreenState
    extends ConsumerState<_ManualEventEntryScreen> {
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Event Entry'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addEvent,
          ),
        ],
      ),
      body: SettingsList(sections: [
        SettingsSection(tiles: [
          SettingsTile(
              title: const Text('Select Date'),
              trailing: Text(formatDate(selectedDate, TimeFormat.local24Hour)),
              onPressed: (context) {
                _showPlatformDatePicker();
              }),
          SettingsTile(
              title: const Text('Select Time'),
              trailing: Text(formatAbsoluteTime(selectedDate, TimeFormat.local24Hour)),
              onPressed: (context) {
                _showCustomTimePicker();
              }),
        ]),
      ]),
    );
  }

  _selectDate(DateTime picked) async {
    setState(() {
      selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDate.hour,
        selectedDate.minute,
        selectedDate.second,
        selectedDate.millisecond,
      );
    });
  }

  void _showPlatformDatePicker() {
    if (Platform.isIOS) {
      showModalBottomSheet(
          context: context,
          builder: (BuildContext builder) {
            return SizedBox(
              height: MediaQuery.of(context).copyWith().size.height / 3,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: _selectDate,
                initialDateTime: selectedDate,
                minimumYear: 1900,
                maximumYear: 2100,
              ),
            );
          });
    } else {
      showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100)
      ).then((pickedDate) {
        if (pickedDate != null && pickedDate != selectedDate) {
          _selectDate(pickedDate);
        }
      });
    }
  }

  void _showCustomTimePicker() {
    showDialog(
      context: context,
      builder: (context) => CustomTimePickerDialog(
        initialDateTime: selectedDate,
        onDateTimeChanged: (newDate) {
          setState(() {
            selectedDate = newDate;
          });
        },
      ),
    );
  }

  _addEvent() {
    DateTime finalDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedDate.hour,
      selectedDate.minute,
      selectedDate.second,
      selectedDate.millisecond,
    );
    ref.watch(eventServiceProvider).manualAddEvent(Event(finalDate, -1));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Event added successfully!'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,  // Setting the background to green
        behavior: SnackBarBehavior.floating,  // Optional: This makes the snackbar appear as a floating box
        shape: RoundedRectangleBorder(  // Optional: Gives rounded corners
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class CustomTimePickerDialog extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;

  CustomTimePickerDialog({
    required this.initialDateTime,
    required this.onDateTimeChanged,
  });

  @override
  _CustomTimePickerDialogState createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedSecond;
  late int _selectedDecisecond;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialDateTime.hour;
    _selectedMinute = widget.initialDateTime.minute;
    _selectedSecond = widget.initialDateTime.second;
    _selectedDecisecond = (widget.initialDateTime.millisecond / 100).floor();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Time"),
      content: SizedBox(
        height: 200.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPicker(_selectedHour, 24, 2, (value) {
              setState(() {
                _selectedHour = value;
              });
            }),
            const Text(":"),
            _buildPicker(_selectedMinute, 60, 2, (value) {
              setState(() {
                _selectedMinute = value;
              });
            }),
            const Text(":"),
            _buildPicker(_selectedSecond, 60, 2, (value) {
              setState(() {
                _selectedSecond = value;
              });
            }),
            const Text("."),
            _buildPicker(_selectedDecisecond, 10, 1, (value) {
              setState(() {
                _selectedDecisecond = value;
              });
            }),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          child: const Text("OK"),
          onPressed: () {
            DateTime newDateTime = DateTime(
              widget.initialDateTime.year,
              widget.initialDateTime.month,
              widget.initialDateTime.day,
              _selectedHour,
              _selectedMinute,
              _selectedSecond,
              _selectedDecisecond * 100,
            );
            widget.onDateTimeChanged(newDateTime);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }

  Widget _buildPicker(int initialItem, int numItems, int numDigits,
      ValueChanged<int> onChanged) {
    return Container(
      width: 50,
      child: CupertinoPicker(
        looping: true,
        diameterRatio: 1.2,
        itemExtent: 30.0,
        onSelectedItemChanged: onChanged,
        scrollController: FixedExtentScrollController(initialItem: initialItem),
        children: List<Widget>.generate(
          numItems,
          (index) =>
              Center(child: Text(index.toString().padLeft(numDigits, '0'))),
        ),
      ),
    );
  }
}
