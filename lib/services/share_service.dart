import 'package:share_plus/share_plus.dart';
import 'package:timestamp/services/export_service.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/enums/time_format.dart';

Future<void> exportAndShareEventsPlainText(List<Event> events, TimeFormat timeFormat) async {
  String plainText = convertEventsToPlainText(events, timeFormat);
  shareRawText(plainText, "Timestamp Event Log");
}

void shareRawText(String text, String subject) {
  Share.share(text, subject: subject);
}