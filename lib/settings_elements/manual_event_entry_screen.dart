import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/utils/time_utils.dart';
import 'dart:io' show Platform;
import '../enums/time_format.dart';
import '../services/event_service.dart';
import 'custom_time_picker_dialog.dart';
import 'select_button_color_screen.dart'; // For reusing the color selection screen

class ManualEventEntryScreen extends ConsumerStatefulWidget {
  const ManualEventEntryScreen({super.key});

  @override
  _ManualEventEntryScreenState createState() => _ManualEventEntryScreenState();
}

class _ManualEventEntryScreenState
    extends ConsumerState<ManualEventEntryScreen> {
  DateTime selectedDate = DateTime.now();
  final TextEditingController _descriptionController = TextEditingController();
  PredefinedColor selectedColor = PredefinedColor.defaultColor;

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
        SettingsSection(
          title: const Text('Event Details'),
          tiles: [
            SettingsTile(
                title: const Text('Select Date'),
                trailing: Text(formatDate(selectedDate, TimeFormat.local24Hour)),
                onPressed: (context) {
                  _showPlatformDatePicker();
                }
            ),
            SettingsTile(
                title: const Text('Select Time'),
                trailing: Text(formatAbsoluteTime(selectedDate, TimeFormat.local24Hour)),
                onPressed: (context) {
                  _showCustomTimePicker();
                }
            ),
            SettingsTile.navigation(
              title: const Text('Event Description'),
              value: Text(_descriptionController.text.isEmpty ? 'None' : _descriptionController.text),
              onPressed: (context) {
                _showDescriptionDialog();
              },
            ),
            SettingsTile.navigation(
              title: const Text('Event Color'),
              value: Text(selectedColor.displayName),
              onPressed: (context) {
                _showColorSelectionScreen();
              },
            ),
          ],
        ),
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

  void _showDescriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Event Description'),
          content: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'Enter event description',
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                setState(() {
                  // No need to set anything, as the controller is already updated
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showColorSelectionScreen() {
    // We'll create a temporary string key for the color selection
    // This allows us to reuse the existing SelectButtonColorScreen
    const String tempKey = '_manualEventColor';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectButtonColorScreen(
          buttonName: tempKey,
          initialColor: selectedColor,
          onColorSelected: (PredefinedColor color) {
            setState(() {
              selectedColor = color;
            });
          },
        ),
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

    // Create event with description and color
    Event newEvent = Event(
      finalDate,
      -1,
      description: _descriptionController.text,
      color: selectedColor,
    );

    ref.read(eventServiceProvider).manualAddEvent(newEvent);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Event added successfully!'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}