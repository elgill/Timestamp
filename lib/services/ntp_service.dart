import 'package:advanced_ntp/ntp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final ntpServiceProvider = Provider<NtpService>((ref) => NtpService(ref));

class NtpService {
  final ProviderRef _ref;
  bool _isInfoRecieved = false;
  int? _ntpOffset; //ms
  int? _roundTripTime; //ms
  int? _ntpStratum;
  String? _timeServer;
  DateTime? _lastSyncTime;

  DateTime get currentTime =>
      DateTime.now().add(Duration(milliseconds: _ntpOffset ?? 0));

  bool get isInfoRecieved => _isInfoRecieved;
  String get timeServer => _timeServer ?? "N/A";
  int get ntpOffset => _ntpOffset ?? 0;
  int get roundTripTime => _roundTripTime ?? 9999;
  int get ntpStratum => _ntpStratum ?? 9999;
  DateTime get lastSyncTime =>
      _lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);

  NtpService(this._ref) {
    updateNtpOffset();
  }

  Future<void> updateNtpOffset() async {
    try {
      NTPResponse ntpResponse = await getNtpData(
          lookUpAddress:
              _ref.watch(sharedUtilityProvider).getTimeServer().displayName);
      _timeServer = ntpResponse.lookupServer;
      _ntpOffset = ntpResponse.offset;
      _ntpStratum = ntpResponse.stratum;
      _roundTripTime = ntpResponse.roundTripDelay.toInt();
      _lastSyncTime = ntpResponse.dateTime;
      _isInfoRecieved = true;
      saveNtpData();
    } catch (error) {
      if (!_isInfoRecieved) {
        loadNtpData();
      }
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
