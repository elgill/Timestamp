enum ButtonLocation {
  top,
  bottom
}

extension ButtonLocationExtension on ButtonLocation {
  String get displayName {
    switch (this) {
      case ButtonLocation.top:
        return 'Top';
      case ButtonLocation.bottom:
        return 'Bottom';
      default:
        throw Exception('Unknown Button Location: $this');
    }
  }
}
