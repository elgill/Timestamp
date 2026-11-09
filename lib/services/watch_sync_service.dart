import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/time_format_provider.dart';
import 'package:timestamp/services/event_service.dart';
import 'package:timestamp/services/ntp_service.dart';
import 'package:timestamp/services/watch_protocol.dart';

const watchChannel = MethodChannel('dev.gillin.timestamp/watch');

/// Only iOS has a watch app. Overridden in tests.
final watchSyncEnabledProvider = Provider<bool>((ref) => Platform.isIOS);

final watchSyncProvider = Provider<WatchSyncService>((ref) {
  final service = WatchSyncService(
    events: ref.read(eventServiceProvider),
    ntp: ref.read(ntpServiceProvider),
    prefs: ref.read(sharedPreferencesProvider),
    buttons: () => watchButtons(ref.read(customButtonNamesProvider),
        ref.read(customButtonModelsProvider)),
    timeFormat: () => ref.read(sharedUtilityProvider).getTimeFormat(),
    enabled: ref.read(watchSyncEnabledProvider),
  );
  ref.listen(customButtonNamesProvider, (_, __) => service.pushContext());
  ref.listen(customButtonModelsProvider, (_, __) => service.pushContext());
  ref.listen(is24HourTimeProvider, (_, __) => service.pushContext());
  ref.onDispose(service.dispose);
  return service;
});

/// The buttons as the phone shows them: the names in their order, each with
/// its color. The names list is what the main screen draws; the models only
/// hold colors, and aren't reordered with the names.
List<ButtonModel> watchButtons(List<String> names, List<ButtonModel> models) {
  final colors = {
    for (final model in models) model.name: model.predefinedColor
  };
  return [
    for (final name in names)
      ButtonModel(name, colors[name] ?? PredefinedColor.defaultColor)
  ];
}

/// Keeps the watch app and the phone's events in step, through the iOS side
/// (ios/Runner/WatchBridge.swift).
///
/// The watch's changes wait in an inbox on the iOS side until they are saved
/// here, so none are lost if the app closes part way through.
class WatchSyncService {
  WatchSyncService({
    required EventService events,
    NtpService? ntp,
    required SharedPreferences prefs,
    required List<ButtonModel> Function() buttons,
    required TimeFormat Function() timeFormat,
    this.enabled = true,
    MethodChannel channel = watchChannel,
  })  : _events = events,
        _ntp = ntp,
        _prefs = prefs,
        _buttons = buttons,
        _timeFormat = timeFormat,
        _channel = channel;

  /// Only iOS has a watch app.
  final bool enabled;
  final EventService _events;
  final NtpService? _ntp;
  final SharedPreferences _prefs;
  final List<ButtonModel> Function() _buttons;
  final TimeFormat Function() _timeFormat;
  final MethodChannel _channel;
  AppLifecycleListener? _lifecycleListener;

  /// Imports run one at a time, so a delivery is never applied twice at once.
  Future<void> _imports = Future.value();

  static const importedIdsKey = 'watchImportedIds';

  /// Enough to cover what a watch could have waiting.
  static const importedIdsKept = 500;

  /// Call once the events have loaded.
  Future<void> start() async {
    if (!enabled) return;
    _events.onSaved = pushContext;
    _ntp?.onSynced = pushContext;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'inboxChanged') await importInbox();
    });
    _lifecycleListener = AppLifecycleListener(onResume: importInbox);
    await importInbox();
    await pushContext();
  }

  void dispose() {
    _lifecycleListener?.dispose();
    if (_events.onSaved == pushContext) _events.onSaved = null;
    if (_ntp?.onSynced == pushContext) _ntp?.onSynced = null;
  }

  Future<void> importInbox() {
    if (!enabled) return Future.value();
    return _imports = _imports.then((_) => _import());
  }

  Future<void> _import() async {
    final List<Map<Object?, Object?>> inbox;
    try {
      inbox = await _channel.invokeListMethod('readInbox') ?? [];
    } on PlatformException catch (error) {
      debugPrint('Reading the watch inbox failed: $error');
      return;
    } on MissingPluginException {
      return;
    }
    if (inbox.isEmpty) return;

    var upTo = 0;
    final changes = <WatchChanges>[];
    // The watch sends each change twice, a fast copy and a sure one, and
    // either can come first. An event is only ever taken in once, so the
    // late copy can't bring back an event deleted in between.
    final seen = importedIds.toSet();
    for (final item in inbox) {
      upTo = max(upTo, item['sequence'] as int? ?? 0);
      try {
        final change = WatchChanges.parse(item['json'] as String);
        changes.add(WatchChanges(
          added: change.added.where((event) => seen.add(event.id)).toList(),
          deletedIds: change.deletedIds,
        ));
      } catch (error) {
        // Unreadable; cleared with the rest so it can't block what follows.
        debugPrint('Skipping an unreadable watch delivery: $error');
      }
    }

    // Saved before the inbox is cleared. If the app stops in between, the
    // same deliveries are read again next time and skipped as known.
    await _events.applyWatchChanges(changes);
    // Only once saved: the watch lets go of an event when it sees its id here.
    await _rememberImported(
        [for (final change in changes) ...change.added.map((e) => e.id)]);
    try {
      await _channel.invokeMethod('clearInbox', {'upTo': upTo});
    } on PlatformException catch (error) {
      debugPrint('Clearing the watch inbox failed: $error');
    }
    await pushContext();
  }

  Future<void> _rememberImported(List<String> ids) async {
    if (ids.isEmpty) return;
    final all = [...importedIds, ...ids];
    await _prefs.setStringList(
        importedIdsKey, all.sublist(max(0, all.length - importedIdsKept)));
  }

  List<String> get importedIds => _prefs.getStringList(importedIdsKey) ?? [];

  /// As the phone's own events get it: half the time server's round trip,
  /// once this run of the app has synced. A saved offset isn't measured.
  ({int precision, DateTime syncedAt})? get _accuracy {
    final ntp = _ntp;
    if (ntp == null || !ntp.isInfoRecieved) return null;
    return (precision: ntp.roundTripTime ~/ 2, syncedAt: ntp.lastSyncTime);
  }

  /// Sends the watch the newest events, the buttons, the time format and
  /// the phone's accuracy.
  Future<void> pushContext() async {
    if (!enabled) return;
    final json = WatchProtocol.context(
      events: _events.events,
      reference: _events.referenceEvent,
      buttons: _buttons(),
      timeFormat: _timeFormat(),
      importedIds: importedIds,
      accuracy: _accuracy,
    );
    try {
      await _channel.invokeMethod('updateContext', {'json': json});
    } on PlatformException catch (error) {
      debugPrint('Updating the watch failed: $error');
    } on MissingPluginException {
      // No watch support in this build.
    }
  }
}
