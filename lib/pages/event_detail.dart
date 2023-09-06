import 'package:flutter/material.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/utils/time_utils.dart';

class EventDetailPage extends StatefulWidget {
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


class _EventDetailPageState extends State<EventDetailPage> {
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.event.description);
  }

  @override
  Widget build(BuildContext context) {
    Event event = widget.event;
    DateTime dateTime = event.time;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            event.description = _descriptionController.text;
            Navigator.pop(context, event); // Return the updated event
          },
        ),
      ),
      body: Column(
        children: [
          Text(formatDate(dateTime), style: const TextStyle(fontSize: 20)),
          Text(formatAbsoluteTime(dateTime, TimeFormat.local12Hour), style: const TextStyle(fontSize: 20)),
          widget.event.precision >= 0 ?
          Text('Precision: ±${widget.event.precision}ms', style: const TextStyle(fontSize: 15)):
          const Text('Precision: Unknown', style: TextStyle(fontSize: 15)),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Event description'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onSetAsReference(widget.event);
            },
            child: const Text('Set as Reference'),
          )
        ],
      ),
    );
  }

}



