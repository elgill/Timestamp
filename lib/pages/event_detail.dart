import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';
import 'package:timestamp/utils/time_utils.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  final Event event;
  final Function(Event) onSetAsReference;
  final Function(Event) onEventUpdated;

  const EventDetailPage({
    Key? key,
    required this.event,
    required this.onSetAsReference,
    required this.onEventUpdated,
  }) : super(key: key);

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  late TextEditingController _descriptionController;
  late PredefinedColor _selectedColor;
  late Event _currentEvent; // Track the current state of the event

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _descriptionController = TextEditingController(text: _currentEvent.description);
    _selectedColor = _currentEvent.color;

    // Update the event whenever these values change
    _descriptionController.addListener(_updateEventData);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_updateEventData);
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateEventData() {
    // Update our local event copy
    _currentEvent.description = _descriptionController.text;
    _currentEvent.color = _selectedColor;

    // Call the callback to update the parent
    widget.onEventUpdated(_currentEvent);
  }

  @override
  Widget build(BuildContext context) {
    DateTime dateTime = _currentEvent.time;
    TimeFormat timeFormat = ref.watch(sharedUtilityProvider).getTimeFormat();
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(dateTime, timeFormat),
                style: const TextStyle(fontSize: 20)),
            Text(formatAbsoluteTime(dateTime, timeFormat),
                style: const TextStyle(fontSize: 20)),
            _currentEvent.precision >= 0 ?
            Text('Precision: ±${_currentEvent.precision}ms',
                style: const TextStyle(fontSize: 15)):
            const Text('Precision: Unknown',
                style: TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Event description'),
            ),
            const SizedBox(height: 16),
            const Text('Event Color', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: PredefinedColor.values.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _updateEventData(); // Update when color changes
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color == PredefinedColor.defaultColor
                          ? Colors.transparent
                          : color.getColor(themeMode, context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color
                            ? Colors.white
                            : color == PredefinedColor.defaultColor
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                            : Colors.transparent,
                        width: _selectedColor == color ? 2 : 1,
                      ),
                      boxShadow: _selectedColor == color
                          ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)]
                          : null,
                    ),
                    child: color == PredefinedColor.defaultColor
                        ? Icon(
                      Icons.do_not_disturb_alt_outlined,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      size: 30,
                    )
                        : _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  widget.onSetAsReference(_currentEvent);
                },
                child: const Text('Set as Reference'),
              ),
            )
          ],
        ),
      ),
    );
  }
}