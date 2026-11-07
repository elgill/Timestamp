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
      color: _colorFromIndex(data['color']),
    );
    return event;
  }

  // A color this version doesn't know must not cost the user the event.
  static PredefinedColor _colorFromIndex(Object? index) {
    const colors = PredefinedColor.values;
    return index is int && index >= 0 && index < colors.length
        ? colors[index]
        : PredefinedColor.defaultColor;
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