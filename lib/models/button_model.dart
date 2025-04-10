import 'package:flutter/material.dart';
import 'package:timestamp/enums/predefined_colors.dart';

class ButtonModel {
  final String name;
  final PredefinedColor predefinedColor;

  ButtonModel(this.name, this.predefinedColor);

  // Get the actual color based on current theme
  Color getColor(ThemeMode themeMode, BuildContext context) {
    return predefinedColor.getColor(themeMode, context);
  }

  // Convert ButtonModel object to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'predefinedColor': predefinedColor.index,
    };
  }

  // Convert JSON map to ButtonModel object
  static ButtonModel fromJson(Map<String, dynamic> json) {
    return ButtonModel(
      json['name'] as String,
      PredefinedColor.values[json['predefinedColor'] as int],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ButtonModel &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              predefinedColor == other.predefinedColor;

  @override
  int get hashCode => name.hashCode ^ predefinedColor.hashCode;
}