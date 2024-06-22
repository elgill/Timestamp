import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/utils/time_utils.dart';
import 'dart:io' show Platform;
import '../enums/time_format.dart';
import '../services/event_service.dart';
import 'custom_time_picker_dialog.dart';

class ManualEventEntryScreen extends ConsumerStatefulWidget {
  const ManualEventEntryScreen({super.key});

  @override
  _ManualEventEntryScreenState createState() => _ManualEventEntryScreenState();
}

class _ManualEventEntryScreenState
    extends ConsumerState<ManualEventEntryScreen> {
  DateTime selectedDate = DateTime.now();

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
    ref.read(eventServiceProvider).manualAddEvent(Event(finalDate, -1));

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
