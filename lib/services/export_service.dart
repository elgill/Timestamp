import 'package:timestamp/models/event.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/utils/time_utils.dart';


String convertEventsToCsv(List<Event> events) {
  StringBuffer buffer = StringBuffer();
  buffer.writeln("Date,Description");
  for (var event in events) {
    buffer.writeln('"${event.time.toIso8601String()}","${event.description}"');
  }
  return buffer.toString();
}

String convertEventsToPlainText(List<Event> events, TimeFormat timeFormat) {
  // Group events by day
  Map<DateTime, List<Event>> groupedEvents = {};

  for (var event in events) {
    DateTime time = event.time;
    if (timeFormat == TimeFormat.utc24Hour) {
      time = time.toUtc();
    }

    DateTime day = DateTime(time.year, time.month, time.day); // This strips off the hours, minutes, and seconds.
    if (!groupedEvents.containsKey(day)) {
      groupedEvents[day] = [];
    }

    groupedEvents[day]!.add(event); // Using "!" because we're sure the key exists at this point.
  }

  // Convert grouped events to plain text
  StringBuffer buffer = StringBuffer();

  for (var day in groupedEvents.keys) {
    buffer.writeln("------------------------");

    // Print the day (formatted)
    buffer.writeln(day.toString().split(' ')[0]); // Print the day in YYYY-MM-DD format

    for (var event in groupedEvents[day]!) {
      buffer.writeln();
      if (event.description.isNotEmpty) {
        buffer.writeln(event.description);
      }
      String time = formatAbsoluteTime(event.time, timeFormat);
      buffer.writeln(time);
    }
  }

  buffer.writeln("------------------------");
  return buffer.toString();
}


