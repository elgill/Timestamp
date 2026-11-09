import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/services/watch_protocol.dart';

final eventServiceProvider = Provider<EventService>((ref) => EventService());

class EventService {
  List<Event> events = [];
  Event? referenceEvent;

  /// Called after every save, which follows every change.
  void Function()? onSaved;

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = events.map((e) => e.toJson()).toList();
    await prefs.setStringList('events', eventsStringList);

    if (referenceEvent != null) {
      await prefs.setString(referenceEventKey, referenceEvent!.toJson());
    } else {
      await prefs.remove(referenceEventKey);
    }
    onSaved?.call();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = prefs.getStringList('events') ?? [];
    // One unreadable entry must not cost the user the rest of the log.
    events = eventsStringList.map(_tryParse).nonNulls.toList();

    final referenceEventString = prefs.getString(referenceEventKey);
    if (referenceEventString != null) {
      referenceEvent = _findReference(_tryParse(referenceEventString));
    }

    // Events saved before ids existed were just given one. Save them, so
    // each keeps that id instead of getting a new one on every launch.
    if (eventsStringList.any(_savedWithoutId)) {
      await saveData();
    }
  }

  static bool _savedWithoutId(String json) {
    try {
      final data = jsonDecode(json);
      return data is Map<String, dynamic> && !Event.hasId(data);
    } catch (_) {
      return false;
    }
  }

  static Event? _tryParse(String json) {
    try {
      return Event.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// The entry in [events] that [saved] refers to. The reference has to be
  /// that same object so edits to the event also apply to the reference.
  ///
  /// Prefers the same id, then an exact match, since events can share a
  /// time and older versions saved no ids. Then matches on
  /// what can't be edited, since older versions could save a reference that
  /// had drifted from its event. Falls back to the oldest event, as deleting
  /// the reference does.
  Event? _findReference(Event? saved) {
    return events.firstWhereOrNull((event) => event.id == saved?.id) ??
        events.firstWhereOrNull((event) => event == saved) ??
        events.firstWhereOrNull((event) =>
            event.time == saved?.time && event.precision == saved?.precision) ??
        events.lastOrNull;
  }

  void addEvent(Event evt) {
    referenceEvent ??= evt;
    events.add(evt);
    events.sort((a, b) => b.time.compareTo(a.time));
    saveData();
  }

  void manualAddEvent(Event evt){
    addEvent(evt);
  }

  /// Deletes exactly these objects, leaving any equal copies of them alone.
  void deleteSelectedEvents(Iterable<Event> selectedEvents) {
    final selected = Set<Event>.identity()..addAll(selectedEvents);
    events.removeWhere(selected.contains);
    if (selected.contains(referenceEvent)) {
      referenceEvent = events.lastOrNull;
    }
    saveData();
  }

  /// Adds the events the watch recorded and deletes the ones it deleted, in
  /// the order the watch made the changes. An event that is already here is
  /// skipped, so a delivery that arrives twice changes nothing the second
  /// time.
  Future<void> applyWatchChanges(Iterable<WatchChanges> changes) async {
    var changed = false;
    for (final change in changes) {
      final known = {for (final event in events) event.id};
      final added =
          change.added.where((event) => known.add(event.id)).toList();
      if (added.isNotEmpty) {
        events.addAll(added);
        changed = true;
      }

      final deleted = change.deletedIds.toSet();
      final before = events.length;
      events.removeWhere((event) => deleted.contains(event.id));
      changed |= events.length != before;
      if (referenceEvent != null && deleted.contains(referenceEvent!.id)) {
        referenceEvent = null;
      }
    }
    if (!changed) return;

    events.sort((a, b) => b.time.compareTo(a.time));
    // Without a reference, the oldest event becomes it, as when deleting.
    referenceEvent ??= events.lastOrNull;
    await saveData();
  }

  void deleteAllEvents() {
    referenceEvent = null;
    events.clear();
    saveData();
  }
}
