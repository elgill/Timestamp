import 'package:flutter/material.dart';

enum PredefinedColor {
  defaultColor,
  red,
  green,
  orange,
  purple,
}

extension PredefinedColorExtension on PredefinedColor {
  String get displayName {
    switch (this) {
      case PredefinedColor.defaultColor:
        return 'Default';
      case PredefinedColor.red:
        return 'Red';
      case PredefinedColor.green:
        return 'Green';
      case PredefinedColor.orange:
        return 'Orange';
      case PredefinedColor.purple:
        return 'Purple';
      default:
        throw Exception('Unknown PredefinedColor: $this');
    }
  }

  Color getColor(ThemeMode themeMode, BuildContext context) {
    bool isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    switch (this) {
      case PredefinedColor.defaultColor:
        return isDark
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary;
      case PredefinedColor.red:
        return Colors.red;
      case PredefinedColor.green:
        return Colors.green;
      case PredefinedColor.orange:
        return Colors.orange;
      case PredefinedColor.purple:
        return Colors.purple;
      default:
        throw Exception('Unknown PredefinedColor: $this');
    }
  }

  static PredefinedColor fromColor(Color color) {
    if (color == Colors.red) return PredefinedColor.red;
    if (color == Colors.green) return PredefinedColor.green;
    if (color == Colors.orange) return PredefinedColor.orange;
    if (color == Colors.purple) return PredefinedColor.purple;
    return PredefinedColor.defaultColor;
  }
}