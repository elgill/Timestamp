// models/event.dart
import 'dart:convert';
import 'package:timestamp/enums/predefined_colors.dart';

class Event {
  final DateTime time;
  final int precision;
  String description = "";
  PredefinedColor color = PredefinedColor.defaultColor;

  Event(this.time, this.precision, {this.description = "", this.color = PredefinedColor.defaultColor});

  // Convert Event object to JSON string
  String toJson() {
    return jsonEncode({
      'time': time.toIso8601String(),
      'precision': precision,
      'description': description,
      'color': color.index,
    });
  }

  // Convert JSON string to Event object
  static Event fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    Event event = Event(
      DateTime.parse(data['time']),
      data['precision'],
      description: data['description'] ?? "", // If null, assign empty string
      color: data.containsKey('color')
          ? PredefinedColor.values[data['color']]
          : PredefinedColor.defaultColor,
    );
    return event;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Event &&
              runtimeType == other.runtimeType &&
              time == other.time &&
              precision == other.precision &&
              description == other.description &&
              color == other.color;

  @override
  int get hashCode => time.hashCode ^ precision.hashCode ^ description.hashCode ^ color.hashCode;
}