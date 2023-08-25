import 'package:flutter/material.dart';
import 'package:timestamp/event.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.event.description = _descriptionController.text;
            Navigator.pop(context, widget.event); // Return the updated event
          },
        ),
      ),
      body: Column(
        children: [
          Text('Time: ${widget.event.time}'),
          Text('Precision: ±${widget.event.precision}ms', style: const TextStyle(fontSize: 20)),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Event description'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onSetAsReference(widget.event);
            },
            child: Text('Set as Reference'),
          )
        ],
      ),
    );
  }
}
