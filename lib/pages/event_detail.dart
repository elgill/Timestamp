// pages/event_detail.dart
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

  const EventDetailPage({
    Key? key,
    required this.event,
    required this.onSetAsReference,
  }) : super(key: key);

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}


class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  late TextEditingController _descriptionController;
  late PredefinedColor _selectedColor;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.event.description);
    _selectedColor = widget.event.color;
  }

  @override
  Widget build(BuildContext context) {
    Event event = widget.event;
    DateTime dateTime = event.time;
    TimeFormat timeFormat = ref.watch(sharedUtilityProvider).getTimeFormat();
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            event.description = _descriptionController.text;
            event.color = _selectedColor;
            Navigator.pop(context, event); // Return the updated event
          },
        ),
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
            widget.event.precision >= 0 ?
            Text('Precision: ±${widget.event.precision}ms',
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
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color == PredefinedColor.defaultColor
                          ? Colors.transparent  // Make default color transparent
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
                    // Show a slash symbol for default/no color
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
                  widget.onSetAsReference(widget.event);
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