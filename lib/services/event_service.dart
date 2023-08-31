import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/models/event.dart';

final eventServiceProvider = Provider<EventService>((ref) => EventService());

class EventService {
  List<Event> events = [];
  Event? referenceEvent;

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = events.map((e) => e.toJson()).toList();
    await prefs.setStringList('events', eventsStringList);

    if (referenceEvent != null) {
      await prefs.setString('referenceEvent', referenceEvent!.toJson());
    }
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = prefs.getStringList('events') ?? [];
    events = eventsStringList.map((e) => Event.fromJson(e)).toList();

    final referenceEventString = prefs.getString('referenceEvent');
    if (referenceEventString != null) {
      referenceEvent = Event.fromJson(referenceEventString);
    }
  }

  void addEvent(Event evt) {
    referenceEvent ??= evt;
    events.insert(0, evt);
    saveData();
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
