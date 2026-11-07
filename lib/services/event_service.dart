import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/constants.dart';

final eventServiceProvider = Provider<EventService>((ref) => EventService());

class EventService {
  List<Event> events = [];
  Event? referenceEvent;

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = events.map((e) => e.toJson()).toList();
    await prefs.setStringList('events', eventsStringList);

    if (referenceEvent != null) {
      await prefs.setString(referenceEventKey, referenceEvent!.toJson());
    } else {
      await prefs.remove(referenceEventKey);
    }
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
  /// Matches on what can't be edited, since older versions could save a
  /// reference that had drifted from its event. Falls back to the oldest
  /// event, as deleting the reference does.
  Event? _findReference(Event? saved) {
    for (final event in events) {
      if (event.time == saved?.time && event.precision == saved?.precision) {
        return event;
      }
    }
    return events.lastOrNull;
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

  void deleteSelectedEvents(List<bool> selectedEvents) {
    for (int i = selectedEvents.length - 1; i >= 0; i--) {
      if (selectedEvents[i]) {
        Event removedEvent = events[i];
        events.removeAt(i);
        if (removedEvent == referenceEvent) {
          referenceEvent = null;
          if(events.isNotEmpty) {
            referenceEvent = events.last;
          }
        }
      }
    }
    saveData();
  }

  void deleteAllEvents() {
    referenceEvent = null;
    events.clear();
    saveData();
  }
}
