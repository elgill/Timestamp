import 'package:flutter/material.dart';
import 'package:timestamp/event.dart';

class EventDetailPage extends StatelessWidget {
  final Event event;

  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: Column(
        children: [
          Text('Time: ${event.time}'),
          Text(
            'Precision: ±${event.precision}ms',
            style: const TextStyle(fontSize: 20),
          ),
          TextField(
            onChanged: (value) {
              event.description = value;
            },
            decoration: const InputDecoration(labelText: 'Event description'),
          ),

          // More details and functionalities to be added here.
        ],
      ),
    );
  }
}
