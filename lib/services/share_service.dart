import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'package:timestamp/services/export_service.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/enums/time_format.dart';

import 'dart:io';

Future<void> exportAndShareEventsCsv(List<Event> events) async {
  String content;
  String fileName;

  content = convertEventsToCsv(events);
  fileName = 'events.csv';

  final directory = await getApplicationDocumentsDirectory();
  final File file = File('${directory.path}/$fileName');
  await file.writeAsString(content);

  Share.shareFiles([file.path], text: 'Here are the exported events.');
}


Future<void> exportAndShareEventsPlainText(List<Event> events, TimeFormat timeFormat) async {
  String plainText = convertEventsToPlainText(events, timeFormat);
  shareRawText(plainText, "Timestamp Event Log");
}

void shareRawText(String text, String subject) {
  Share.share(text, subject: subject);
}