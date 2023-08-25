String formatAbsoluteTime(DateTime dateTime){
  return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${(dateTime.millisecond ~/ 100).toString()}";
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
