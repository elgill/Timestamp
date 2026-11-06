import 'package:flutter/material.dart';

/// A button label that uses the largest font size (between [minFontSize] and
/// [maxFontSize]) at which the text fits the available box in up to
/// [maxLines] lines, wrapping only between words.
///
/// If even [minFontSize] doesn't fit (e.g. one very long word), the text is
/// scaled down on a single line so it is never cut off.
class AutoSizeLabel extends StatefulWidget {
  const AutoSizeLabel(
    this.text, {
    super.key,
    this.style,
    this.maxFontSize = 20,
    this.minFontSize = 10,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle? style;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;

  /// Picks the font size for [text] in a [maxWidth] x [maxHeight] box, or
  /// null if nothing in range fits. Exposed for tests.
  static double? fitFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
    double maxFontSize = 20,
    double minFontSize = 10,
    int maxLines = 2,
    double step = 0.5,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    bool fits(double size) {
      final s = style.copyWith(fontSize: size);
      // No single word may be wider than the box, otherwise it would be
      // broken mid-word ("sensitivi-ty").
      for (final word in words) {
        final p = TextPainter(
          text: TextSpan(text: word, style: s),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        final tooWide = p.width > maxWidth;
        p.dispose();
        if (tooWide) return false;
      }
      final p = TextPainter(
        text: TextSpan(text: text, style: s),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);
      final ok = !p.didExceedMaxLines && p.height <= maxHeight;
      p.dispose();
      return ok;
    }

    // Binary search over discrete steps between min and max.
    int lo = 0;
    int hi = ((maxFontSize - minFontSize) / step).floor();
    if (!fits(minFontSize)) return null;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits(minFontSize + mid * step)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return minFontSize + lo * step;
  }

  @override
  State<AutoSizeLabel> createState() => _AutoSizeLabelState();
}

class _AutoSizeLabelState extends State<AutoSizeLabel> {
  // The main screen rebuilds very frequently (running clock), so remember
  // the last result instead of re-measuring text on every frame.
  Object? _cacheKey;
  double? _cachedSize;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final key = Object.hash(widget.text, style, textScaler, direction,
          constraints.maxWidth, constraints.maxHeight, widget.maxFontSize,
          widget.minFontSize, widget.maxLines);
      if (key != _cacheKey) {
        _cacheKey = key;
        _cachedSize = (constraints.hasBoundedWidth &&
                constraints.hasBoundedHeight)
            ? AutoSizeLabel.fitFontSize(
                text: widget.text,
                style: style,
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
                textScaler: textScaler,
                textDirection: direction,
                maxFontSize: widget.maxFontSize,
                minFontSize: widget.minFontSize,
                maxLines: widget.maxLines,
              )
            : widget.maxFontSize;
      }

      final size = _cachedSize;
      if (size == null) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.text,
            style: style.copyWith(fontSize: widget.minFontSize),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        );
      }
      return Text(
        widget.text,
        style: style.copyWith(fontSize: size),
        maxLines: widget.maxLines,
        textAlign: TextAlign.center,
      );
    });
  }
}
