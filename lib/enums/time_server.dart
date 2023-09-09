enum TimeServer {
  timeGoogleCom,
  timeNistGov,
  // Add more servers as needed
}

extension TimeServerExtension on TimeServer {
  String get displayName {
    switch (this) {
      case TimeServer.timeGoogleCom:
        return 'time.google.com';
      case TimeServer.timeNistGov:
        return 'time.nist.gov';

      default:
        return 'Unknown';
    }
  }
}
