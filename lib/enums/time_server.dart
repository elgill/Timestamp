enum TimeServer {
  poolNtpOrg,
  timeGoogleCom,
  timeAppleCom,
  timeCloudflareCom,
  timeNistGov
}

extension TimeServerExtension on TimeServer {
  String get displayName {
    switch (this) {
      case TimeServer.poolNtpOrg:
        return 'pool.ntp.org';
      case TimeServer.timeAppleCom:
        return 'time.apple.com';
      case TimeServer.timeCloudflareCom:
        return 'time.cloudflare.com';
      case TimeServer.timeGoogleCom:
        return 'time.google.com';
      case TimeServer.timeNistGov:
        return 'time.nist.gov';

      default:
        return 'Unknown';
    }
  }
}
