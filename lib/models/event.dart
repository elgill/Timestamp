import 'dart:convert';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:uuid/uuid.dart';

class Event {
  /// Tells this event apart from any other, even one with the same time and
  /// description. The watch uses it to recognise an event it has already
  /// sent or received.
  final String id;
  final DateTime time;
  final int precision;
  String description = "";
  PredefinedColor color = PredefinedColor.defaultColor;

  Event(this.time, this.precision,
      {String? id,
      this.description = "",
      this.color = PredefinedColor.defaultColor})
      : id = id ?? newId();

  static String newId() => const Uuid().v4();

  // Convert Event object to JSON string
  String toJson() {
    return jsonEncode({
      'id': id,
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
      // Events saved before ids existed get a new one.
      id: hasId(data) ? data['id'] : null,
      description: data['description'] ?? "", // If null, assign empty string
      color: PredefinedColorExtension.fromIndex(data['color']),
    );
    return event;
  }

  /// Whether a decoded event has a usable id saved with it.
  static bool hasId(Map<String, dynamic> data) {
    final id = data['id'];
    return id is String && id.isNotEmpty;
  }

  // The id is left out on purpose: two events with the same time,
  // description and color are equal, whatever their ids.
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
