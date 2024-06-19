import 'dart:convert';

class Event {
  final DateTime time;
  final int precision;
  String description = "";

  Event(this.time, this.precision, {this.description = ""});

  // Convert Event object to JSON string
  String toJson() {
    return jsonEncode({
      'time': time.toIso8601String(),
      'precision': precision,
      'description': description,
    });
  }

  // Convert JSON string to Event object
  static Event fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    Event event = Event(DateTime.parse(data['time']), data['precision']);
    event.description = data['description'] ?? ""; // If null, assign empty string
    return event;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          precision == other.precision &&
          description == other.description;

  @override
  int get hashCode => time.hashCode ^ precision.hashCode ^ description.hashCode;
}
