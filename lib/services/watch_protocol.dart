import 'dart:convert';

import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/models/button_model.dart';
import 'package:timestamp/models/event.dart';

/// What the phone and the watch app send each other, as JSON. The watch side
/// is ios/TimestampWatch/PhoneLink.swift, and test/fixtures/watch holds an
/// example of each message that both sides are tested against.
///
/// Times are milliseconds since 1970, which reads the same in any time zone.
class WatchProtocol {
  /// How many of the newest events the watch gets. It's a wrist; enough to
  /// see what just happened, and small enough to send often.
  static const recentEventCount = 100;

  static Map<String, dynamic> eventToMap(Event event) => {
        'id': event.id,
        'time': event.time.microsecondsSinceEpoch / 1000,
        'precision': event.precision,
        'description': event.description,
        'color': event.color.index,
      };

  /// The event in [map], in local time like events recorded on the phone.
  static Event eventFromMap(Map<String, dynamic> map) {
    final millis = map['time'] as num;
    return Event(
      DateTime.fromMicrosecondsSinceEpoch((millis * 1000).round()),
      (map['precision'] as num).toInt(),
      id: Event.hasId(map) ? map['id'] : null,
      description: map['description'] as String? ?? '',
      color: PredefinedColorExtension.fromIndex(map['color']),
    );
  }

  /// What the watch is sent: the buttons and settings it shares with the
  /// phone, and the newest events.
  ///
  /// [importedIds] are the watch's events the phone has taken in, so the
  /// watch can stop holding them even if they've since been deleted here.
  static String context({
    required List<Event> events,
    required Event? reference,
    required List<ButtonModel> buttons,
    required TimeFormat timeFormat,
    required List<String> importedIds,
  }) {
    return jsonEncode({
      'buttons': [
        for (final button in buttons)
          {'name': button.name, 'color': button.predefinedColor.index}
      ],
      'timeFormat': timeFormat.index,
      'events': [
        for (final event in events.take(recentEventCount)) eventToMap(event)
      ],
      'reference': reference == null ? null : eventToMap(reference),
      'importedIds': importedIds,
    });
  }
}

/// Events the watch recorded and events it deleted, in one delivery.
class WatchChanges {
  WatchChanges({this.added = const [], this.deletedIds = const []});

  final List<Event> added;
  final List<String> deletedIds;

  /// Reads a delivery from the watch. One unreadable event is skipped
  /// rather than losing the rest.
  static WatchChanges parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final added = <Event>[];
    for (final map in data['added'] as List? ?? const []) {
      try {
        added.add(WatchProtocol.eventFromMap(map as Map<String, dynamic>));
      } catch (_) {}
    }
    return WatchChanges(
      added: added,
      deletedIds: [
        for (final id in data['deleted'] as List? ?? const [])
          if (id is String) id
      ],
    );
  }
}
