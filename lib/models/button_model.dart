import 'package:flutter/material.dart';

class ButtonModel {
  final String name;
  final Color color;

  ButtonModel(this.name, this.color);

  // Convert ButtonModel object to JSON string
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color.value,
    };
  }

  // Convert JSON map to ButtonModel object
  static ButtonModel fromJson(Map<String, dynamic> json) {
    return ButtonModel(
      json['name'] as String,
      Color(json['color'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ButtonModel &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              color.value == other.color.value;

  @override
  int get hashCode => name.hashCode ^ color.value.hashCode;
}