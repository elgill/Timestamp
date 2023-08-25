import 'dart:developer';

import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NtpService {
  Map<String, int>? _ntpData;
  int? _ntpOffset; //ms
  int? _ntpError; //ms
  DateTime? _lastSyncTime;

  DateTime get currentTime => DateTime.now().add(Duration(milliseconds: _ntpOffset ?? 0));
  int get ntpOffset => _ntpOffset ?? 0;
  int get ntpError => _ntpError ?? 9999;
  DateTime get lastSyncTime => _lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);

  NtpService() {
    updateNtpOffset();
  }

  Future<void> updateNtpOffset() async {
    try {
      log("Getting ntp offset");
      _ntpData = await NTP.getNtpOffset(/*lookUpAddress: 'pool.ntp.org'*/);
      _ntpOffset = _ntpData?['offset'] ?? 0;
      _ntpError = _ntpData?['error'] ?? 9999;
      _lastSyncTime = DateTime.now();
      log("ntp error: $_ntpError");

      saveNtpData();

    } catch (error) {
      log("Failed to update ntp offset");
      loadNtpData();
      // TODO: Handle exception here, perhaps through a callback or stream.
    }
  }

  Future<void> saveNtpData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_ntpOffset != null) {
      prefs.setInt('ntpOffset', _ntpOffset!);
    }
    if (_lastSyncTime != null) {
      prefs.setString('lastSyncTime', _lastSyncTime!.toIso8601String());
    }
  }

  Future<void> loadNtpData() async {
    final prefs = await SharedPreferences.getInstance();
    _ntpOffset ??= prefs.getInt('ntpOffset');
    String? lastSyncTimeString = prefs.getString('lastSyncTime');
    if (lastSyncTimeString != null) {
      _lastSyncTime ??= DateTime.tryParse(lastSyncTimeString);
    }
  }

}
