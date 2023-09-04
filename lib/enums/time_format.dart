enum TimeFormat {
  local12Hour,
  local24Hour,
  utc24Hour,
}

extension TimeFormatExtension on TimeFormat {
  String get displayName {
    switch (this) {
      case TimeFormat.local12Hour:
        return 'Local 12 Hour';
      case TimeFormat.local24Hour:
        return 'Local 24 Hour';
      case TimeFormat.utc24Hour:
        return 'UTC 24 Hour';
      default:
        throw Exception('Unknown TimeFormat: $this');
    }
  }
}
