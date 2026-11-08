import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A button label that uses the largest font size (between [minFontSize] and
/// [maxFontSize]) at which the text fits the available box in up to
/// [maxLines] lines, wrapping only between words.
///
/// If even [minFontSize] doesn't fit (e.g. one very long word), a
/// multi-word label still wraps between words, shrunk just enough for its
/// widest word to fit; a single word is scaled down on one line. Either way
/// the text is never cut off.
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

  /// For a multi-word [text] that doesn't fit at [minFontSize]: the largest
  /// size below [minFontSize] at which it still wraps between words into
  /// [maxLines] lines within the box. That is usually the size at which its
  /// widest word just fits [maxWidth], or smaller if the words then need
  /// more than [maxLines] lines (e.g. "Return of spontaneous circulation").
  ///
  /// Null for single words, or if wrapping wouldn't beat scaling the whole
  /// text down onto one line. Exposed for tests.
  static double? wrappedFallbackFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
    double minFontSize = 10,
    int maxLines = 2,
    double step = 0.1,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 2 || maxWidth <= 0 || maxHeight <= 0) return null;

    Size measure(String s, double fontSize, {double? width, int? lines}) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style.copyWith(fontSize: fontSize)),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: lines,
      )..layout(maxWidth: width ?? double.infinity);
      final size = p.didExceedMaxLines ? Size.infinite : p.size;
      p.dispose();
      return size;
    }

    // Text size scales linearly with font size, so measuring once at
    // minFontSize gives the size at which something just fits.
    final widest = words
        .map((w) => measure(w, minFontSize, lines: 1).width)
        .reduce(math.max);
    final oneLine = measure(text, minFontSize, lines: 1);
    if (widest <= 0 || oneLine.isEmpty) return null;

    // What the single-line scale-down would show; wrapping must beat it.
    final singleLine = minFontSize *
        math.min(maxWidth / oneLine.width, maxHeight / oneLine.height);
    // Largest size at which the widest word fits, rounded down to a step.
    final steps = (minFontSize * maxWidth / widest / step).floor();

    bool fits(int n) {
      final size = measure(text, n * step, width: maxWidth, lines: maxLines);
      return size.height <= maxHeight;
    }

    int lo = (singleLine / step).ceil();
    int hi = math.min(steps, ((minFontSize - step) / step).floor());
    if (hi < lo || !fits(lo)) return null;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo * step;
  }

  @override
  State<AutoSizeLabel> createState() => _AutoSizeLabelState();
}

class _AutoSizeLabelState extends State<AutoSizeLabel> {
  // The main screen rebuilds very frequently (running clock), so remember
  // the last result instead of re-measuring text on every frame.
  Object? _cacheKey;
  double? _cachedSize;
  double? _cachedFallbackSize;

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
        _cachedFallbackSize = _cachedSize == null
            ? AutoSizeLabel.wrappedFallbackFontSize(
                text: widget.text,
                style: style,
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
                textScaler: textScaler,
                textDirection: direction,
                minFontSize: widget.minFontSize,
                maxLines: widget.maxLines,
              )
            : null;
      }

      final size = _cachedSize ?? _cachedFallbackSize;
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
