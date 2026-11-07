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

  /// The color stored as [index]. One this version doesn't know becomes the
  /// default, since it must not cost the user what it's attached to.
  static PredefinedColor fromIndex(Object? index) {
    const colors = PredefinedColor.values;
    return index is int && index >= 0 && index < colors.length
        ? colors[index]
        : PredefinedColor.defaultColor;
  }

  static PredefinedColor fromColor(Color color) {
    // Compare values: a plain Color never equals a MaterialColor like
    // Colors.red, even with the same value.
    final value = color.toARGB32();
    if (value == Colors.red.toARGB32()) return PredefinedColor.red;
    if (value == Colors.green.toARGB32()) return PredefinedColor.green;
    if (value == Colors.orange.toARGB32()) return PredefinedColor.orange;
    if (value == Colors.purple.toARGB32()) return PredefinedColor.purple;
    return PredefinedColor.defaultColor;
  }
}