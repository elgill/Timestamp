import 'package:intl/intl.dart';
import 'package:timestamp/enums/time_format.dart';


String formatAbsoluteTime(DateTime dateTime, TimeFormat timeFormat) {
  switch (timeFormat) {
    case TimeFormat.local12Hour:
      return _formatLocal12Hour(dateTime);
    case TimeFormat.local24Hour:
      return _formatLocal24Hour(dateTime);
    case TimeFormat.utc24Hour:
      return _formatUTC24Hour(dateTime);
    default:
      throw Exception('Unknown TimeFormat: $timeFormat');
  }
}

String _formatLocal12Hour(DateTime dateTime) {
  String baseTime = DateFormat('h:mm:ss').format(dateTime);
  String deciSeconds = (dateTime.millisecond ~/ 100).toString();
  String period = DateFormat('a').format(dateTime); // AM or PM
  String timeZone = dateTime.timeZoneName;

  return '$baseTime.$deciSeconds $period $timeZone';
}

String _formatLocal24Hour(DateTime dateTime) {
  String baseTime = DateFormat('HH:mm:ss').format(dateTime);
  String deciSeconds = (dateTime.millisecond ~/ 100).toString();
  String timeZone = dateTime.timeZoneName;

  return '$baseTime.$deciSeconds $timeZone';
}

String _formatUTC24Hour(DateTime dateTime) {
  // Convert local time to UTC before formatting
  DateTime utcTime = dateTime.toUtc();

  return _formatLocal24Hour(utcTime);
}

String formatRelativeTime(DateTime time, DateTime timeToCompare){
  Duration difference = time.isAfter(timeToCompare)
      ? time.difference(timeToCompare)
      : timeToCompare.difference(time);

  String sign = time.isAfter(timeToCompare) ? "+" : "-";
  if (difference == Duration.zero) {
    sign = "";
  }

  int years = (difference.inDays / 365).floor();
  int days = difference.inDays % 365;
  int hours = difference.inHours.remainder(24);
  int minutes = difference.inMinutes.remainder(60);
  int seconds = difference.inSeconds.remainder(60);
  int tenthsOfSeconds = (difference.inMilliseconds.remainder(1000) / 100).floor();

  List<String> timeComponents = [];

  if (years > 0) {
    timeComponents.add("${years}y");
  }
  if (days > 0) {
    timeComponents.add("${days}d");
  }
  timeComponents.add("${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${tenthsOfSeconds}");

  return "$sign${timeComponents.join(' ')}";
}

String formatDate(DateTime dateTime, TimeFormat timeFormat){
  if(timeFormat == TimeFormat.utc24Hour){
    dateTime = dateTime.toUtc();
  }
  return DateFormat('EEE MMM dd, y').format(dateTime);
}
