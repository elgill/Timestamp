import 'dart:convert';
import 'package:flutter/material.dart';

class ButtonConfig {
  final String name;
  final Color color;

  ButtonConfig({
    required this.name,
    this.color = Colors.teal, // Default color matching the app's theme
  });

  // Convert to JSON string
  String toJson() {
    return jsonEncode({
      'name': name,
      'color': color.value,
    });
  }

  // Create from JSON string
  static ButtonConfig fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return ButtonConfig(
      name: data['name'],
      color: Color(data['color'] ?? Colors.teal.value),
    );
  }

  // Create a copy with modifications
  ButtonConfig copyWith({
    String? name,
    Color? color,
  }) {
    return ButtonConfig(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}