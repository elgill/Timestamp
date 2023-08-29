import 'package:intl/intl.dart';

String formatAbsoluteTime(DateTime dateTime, bool useTwelveHourTime){

  String hour = dateTime.hour.toString().padLeft(2, '0');
  String minute = dateTime.minute.toString().padLeft(2, '0');
  String second = dateTime.second.toString().padLeft(2, '0');
  String deciSeconds = (dateTime.millisecond ~/ 100).toString();
  String amPM ="";

  if(useTwelveHourTime){
    if(dateTime.hour > 12){
      amPM = "PM ";
      hour = (dateTime.hour-12).toString().padLeft(2, '0');
    }
    else {
      amPM = "AM ";
    }
  }

  return "$hour:$minute:$second.$deciSeconds $amPM${dateTime.timeZoneName}";
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

String formatDate(DateTime dateTime){
  return DateFormat('EEE MMM dd, y').format(dateTime);
}
