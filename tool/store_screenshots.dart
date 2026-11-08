// Produces App Store screenshots from the real app on iOS simulators.
//
//   dart run tool/store_screenshots.dart              # every device
//   dart run tool/store_screenshots.dart duo-inner    # just these
//
// Images land in build/store_screenshots/<device>/, ready to upload. Scenes
// and demo data live in test_driver/store_screenshots.dart.
//
// Runs on its own simulators, created on first use, so your usual simulators
// and their data are left alone.
//
// The iPhone Duo's inner display needs duoctl to unfold the simulator:
//   brew install skarol/tap/duoctl
//
// Sizes follow Apple's specifications, last checked November 2026:
// https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _outDir = 'build/store_screenshots';
const _simulatorPrefix = 'Store Screenshots';

class Target {
  const Target(this.id, this.deviceType, this.sizes,
      {this.cutout, this.display, this.unfolded = false});

  final String id;

  /// Suffix of a com.apple.CoreSimulator.SimDeviceType identifier.
  final String deviceType;

  /// Sizes Apple accepts for this display class, as width x height in either
  /// orientation.
  final List<(int, int)> sizes;

  /// A point inside the camera cutout. The simulator sometimes draws the
  /// cutout into a capture, and the app never draws pure black there.
  final (int, int)? cutout;

  /// Which screen to capture, on devices with more than one.
  final String? display;

  /// Needs the simulator unfolded before capturing.
  final bool unfolded;
}

const targets = [
  // Apple's summary requires the medium class while its table requires the
  // large one, so provide both.
  Target('iphone-69', 'iPhone-18-Pro-Max',
      [(1320, 2868), (1290, 2796), (1260, 2736)], cutout: (660, 90)),
  Target('iphone-63', 'iPhone-18-Pro', [(1206, 2622), (1179, 2556)],
      cutout: (603, 90)),
  Target('ipad-13', 'iPad-Pro-13-inch-M5-12GB',
      [(2064, 2752), (2048, 2732)]),
  Target('duo-outer', 'iPhone-Duo', [(1398, 2034)],
      cutout: (1252, 142), display: 'primary'),
  Target('duo-inner', 'iPhone-Duo', [(2007, 2853)],
      display: 'primary-1', unfolded: true),
];

Future<String> run(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) {
    throw Exception('$executable ${args.join(' ')}\n${result.stderr}');
  }
  return result.stdout as String;
}

Future<String> simctl(List<String> args) => run('xcrun', ['simctl', ...args]);

/// The UDID of this target's simulator, creating it if needed.
Future<String> simulatorFor(Target target) async {
  final name = '$_simulatorPrefix ${target.id}';
  final listing = jsonDecode(await simctl(['list', 'devices', '-j']));
  for (final devices in (listing['devices'] as Map).values) {
    for (final device in devices as List) {
      if (device['name'] == name && device['isAvailable'] == true) {
        return device['udid'] as String;
      }
    }
  }
  final type = 'com.apple.CoreSimulator.SimDeviceType.${target.deviceType}';
  return (await simctl(['create', name, type])).trim();
}

bool hasCutout(img.Image image, (int, int) point) {
  final pixel = image.getPixel(point.$1, point.$2);
  return pixel.r == 0 && pixel.g == 0 && pixel.b == 0;
}

/// A display that's switched off still captures, as solid black.
bool isBlank(img.Image image) {
  final first = image.getPixel(0, 0);
  return image.every((pixel) => pixel == first);
}

/// The Duo boots closed and simctl can't open it.
// TODO: Replace duoctl once Apple ships a way to fold the simulator, such as a
// simctl command or an XCTest API. duoctl relies on private interfaces, so an
// Xcode update can break it. Check each major Xcode release.
Future<void> unfold(Target target, String udid) async {
  // duoctl fails until the displays settle, about 30 seconds after boot. Too
  // early and the hinge opens but the screen doesn't switch, so close it again
  // before each try.
  late ProcessResult result;
  for (var attempt = 0; attempt < 12; attempt++) {
    await Process.run('duoctl', ['-d', udid, 'close']);
    result = await Process.run('duoctl', ['-d', udid, 'open']);
    if (result.exitCode == 0) return;
    await Future.delayed(const Duration(seconds: 3));
  }
  throw Exception('${target.id} did not unfold: ${result.stderr}');
}

Future<void> capture(Target target, String udid, Directory dir) async {
  final process = await Process.start('flutter', [
    'drive',
    '--driver=test_driver/store_screenshots_test.dart',
    '--target=test_driver/store_screenshots.dart',
    '-d', udid,
  ], environment: {
    'SCREENSHOT_UDID': udid,
    'SCREENSHOT_DIR': dir.path,
    if (target.display != null) 'SCREENSHOT_DISPLAY': target.display!,
    if (target.cutout case (final x, final y)) 'SCREENSHOT_CUTOUT': '$x,$y',
  }, mode: ProcessStartMode.inheritStdio);
  if (await process.exitCode != 0) {
    throw Exception('flutter drive failed for ${target.id}');
  }
}

/// Apple rejects images with an alpha channel, which simctl always writes.
/// Returns what's wrong with the image, if anything.
String? finish(File file, Target target) {
  final image = img.decodePng(file.readAsBytesSync())!;
  file.writeAsBytesSync(img.encodePng(image.convert(numChannels: 3)));

  final (w, h) = (image.width, image.height);
  final accepted = target.sizes
      .any((size) => size == (w, h) || size == (h, w));
  if (!accepted) return '$w x $h is not an accepted ${target.id} size';

  if (isBlank(image)) return 'blank image; is this display active?';

  final cutout = target.cutout;
  if (cutout != null && hasCutout(image, cutout)) {
    return 'camera cutout in the image; capture it again';
  }
  return null;
}

Future<void> main(List<String> args) async {
  final ids = targets.map((target) => target.id);
  if (!args.every(ids.contains)) {
    stderr.writeln('Devices: ${ids.join(', ')}');
    exit(64);
  }
  final selected = targets
      .where((target) => args.isEmpty || args.contains(target.id));

  final problems = <String>[];
  for (final target in selected) {
    stdout.writeln('\n== ${target.id} ==');
    final dir = Directory('$_outDir/${target.id}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final udid = await simulatorFor(target);
    await simctl(['bootstatus', udid, '-b']);
    try {
      if (target.unfolded) await unfold(target, udid);
      await capture(target, udid, dir);
    } finally {
      await simctl(['shutdown', udid]);
    }

    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) problems.add('${target.id}: no screenshots');
    for (final file in files) {
      final problem = finish(file, target);
      if (problem != null) problems.add('${file.path}: $problem');
      stdout.writeln('  ${file.path}');
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('\nProblems:\n  ${problems.join('\n  ')}');
    exit(1);
  }
  stdout.writeln('\nDone. Upload from $_outDir/');
}
