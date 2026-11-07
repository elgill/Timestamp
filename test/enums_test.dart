import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/models/button_model.dart';

/// Runs [body] with a BuildContext whose theme and platform brightness are set.
Future<void> withContext(WidgetTester tester, Brightness platformBrightness,
    void Function(BuildContext) body) async {
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(platformBrightness: platformBrightness),
    child: MaterialApp(
      theme: ThemeData(useMaterial3: false, primarySwatch: Colors.teal),
      home: Builder(builder: (context) {
        body(context);
        return const SizedBox();
      }),
    ),
  ));
}

void main() {
  test('display names', () {
    expect(ButtonLocation.values.map((e) => e.displayName), ['Top', 'Bottom']);
    expect(TimeFormat.values.map((e) => e.displayName),
        ['Local 12 Hour', 'Local 24 Hour', 'UTC 24 Hour']);
    expect(PredefinedColor.values.map((e) => e.displayName),
        ['Default', 'Red', 'Green', 'Orange', 'Purple']);
  });

  test('time server display names are the hostnames that get queried', () {
    expect(TimeServer.values.map((e) => e.displayName), [
      'pool.ntp.org',
      'time.google.com',
      'time.apple.com',
      'time.cloudflare.com',
      'time.nist.gov',
    ]);
  });

  group('PredefinedColor.getColor', () {
    testWidgets('named colors are the same in every theme', (tester) async {
      await withContext(tester, Brightness.light, (context) {
        for (final mode in ThemeMode.values) {
          expect(PredefinedColor.red.getColor(mode, context), Colors.red);
          expect(PredefinedColor.green.getColor(mode, context), Colors.green);
          expect(PredefinedColor.orange.getColor(mode, context), Colors.orange);
          expect(PredefinedColor.purple.getColor(mode, context), Colors.purple);
        }
      });
    });

    testWidgets('default follows the theme primary color', (tester) async {
      await withContext(tester, Brightness.dark, (context) {
        expect(PredefinedColor.defaultColor.getColor(ThemeMode.system, context),
            Theme.of(context).colorScheme.primary);
      });
    });

    testWidgets('ButtonModel delegates to its color', (tester) async {
      await withContext(tester, Brightness.light, (context) {
        expect(
            ButtonModel('a', PredefinedColor.red)
                .getColor(ThemeMode.light, context),
            Colors.red);
      });
    });
  });

  group('PredefinedColorExtension.fromColor', () {
    test('recognises the palette constants', () {
      expect(PredefinedColorExtension.fromColor(Colors.red), PredefinedColor.red);
      expect(PredefinedColorExtension.fromColor(Colors.green),
          PredefinedColor.green);
      expect(PredefinedColorExtension.fromColor(Colors.orange),
          PredefinedColor.orange);
      expect(PredefinedColorExtension.fromColor(Colors.purple),
          PredefinedColor.purple);
    });

    test('recognises plain colors with the same value', () {
      expect(PredefinedColorExtension.fromColor(Color(Colors.red.toARGB32())),
          PredefinedColor.red);
    });

    test('anything else is the default', () {
      expect(PredefinedColorExtension.fromColor(Colors.teal),
          PredefinedColor.defaultColor);
    });
  });
}
