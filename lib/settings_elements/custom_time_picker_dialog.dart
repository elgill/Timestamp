import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomTimePickerDialog extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;

  const CustomTimePickerDialog({
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
