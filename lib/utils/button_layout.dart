import 'dart:math' as math;

/// Splits [names] into at most [maxRows] rows of roughly equal length,
/// preserving order and never producing empty rows.
List<List<String>> splitIntoRows(List<String> names, int maxRows) {
  if (names.isEmpty || maxRows < 1) return [];
  final rowCount = math.min(maxRows, names.length);
  final rows = <List<String>>[];
  for (int i = 0; i < rowCount; i++) {
    final start = (i * names.length / rowCount).floor();
    final end = ((i + 1) * names.length / rowCount).floor();
    rows.add(names.sublist(start, end));
  }
  return rows;
}

/// Decides how tall the record-button section and its buttons should be for
/// the space that is actually available, so every row stays on screen
/// (e.g. 5 rows on a phone in landscape).
class ButtonSectionLayout {
  /// Button height when there is plenty of room (the historical size).
  static const double preferredButtonHeight = 60;

  /// Smallest button we shrink to before resorting to scrolling. Together
  /// with [rowPadding] this keeps rows at Apple's 44pt minimum touch target.
  static const double minButtonHeight = 40;

  /// Vertical padding around each button (2pt above + 2pt below).
  static const double rowPadding = 4;

  /// Default spacing above and below the whole section (8pt each side).
  static const double defaultSectionPadding = 16;

  /// Space we try to leave for the event list when shrinking buttons.
  static const double minListHeight = 48;

  const ButtonSectionLayout({
    required this.buttonHeight,
    required this.sectionHeight,
    required this.scrollable,
    this.sectionPadding = defaultSectionPadding,
  });

  final double buttonHeight;

  /// Total height of the section including [sectionPadding].
  final double sectionHeight;

  /// Total vertical spacing around the rows (split above and below).
  final double sectionPadding;

  /// True only if even [minButtonHeight] buttons don't fit; the rows then
  /// scroll inside [sectionHeight].
  final bool scrollable;

  static double contentHeight(int rows, double buttonHeight,
          [double sectionPadding = defaultSectionPadding]) =>
      rows * (buttonHeight + rowPadding) + sectionPadding;

  /// [availableHeight] is the space shared by the button section and the
  /// event list.
  factory ButtonSectionLayout.fit({
    required int rows,
    required double availableHeight,
    double sectionPadding = defaultSectionPadding,
  }) {
    rows = math.max(rows, 1);
    double content(double buttonHeight) =>
        contentHeight(rows, buttonHeight, sectionPadding);
    ButtonSectionLayout make(double button, double section, bool scroll) =>
        ButtonSectionLayout(
            buttonHeight: button,
            sectionHeight: section,
            scrollable: scroll,
            sectionPadding: sectionPadding);
    final preferred = content(preferredButtonHeight);

    if (!availableHeight.isFinite) {
      return make(preferredButtonHeight, preferred, false);
    }

    // 1. Full size buttons, with room left for the list.
    final budget = availableHeight - minListHeight;
    if (preferred <= budget) {
      return make(preferredButtonHeight, preferred, false);
    }

    // 2. Shrink buttons evenly to share the budget.
    final shrunk = (budget - sectionPadding) / rows - rowPadding;
    if (shrunk >= minButtonHeight) {
      return make(shrunk, content(shrunk), false);
    }

    // 3. Minimum size buttons; let them use the list's space too, since
    //    reaching every button matters more than seeing past events.
    final minimum = content(minButtonHeight);
    if (minimum <= availableHeight) {
      return make(minButtonHeight, minimum, false);
    }

    // 4. Truly no room: scroll the rows rather than hiding them.
    return make(minButtonHeight, math.max(availableHeight, 0), true);
  }

  @override
  String toString() => 'ButtonSectionLayout(button: $buttonHeight, '
      'section: $sectionHeight, scrollable: $scrollable)';
}
