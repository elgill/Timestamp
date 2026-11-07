import 'dart:async';

import 'package:advanced_ntp/ntp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timestamp/constants.dart';
import 'package:timestamp/enums/time_server.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/services/ntp_service.dart';

final _syncTime = DateTime.utc(2026, 3, 5, 12);

NTPResponse response({int offset = 250}) => NTPResponse(
      dateTime: _syncTime,
      offset: offset,
      roundTripDelay: 44,
      lookupServer: '216.239.35.0',
      stratum: 1,
    );

/// Scripted NTP results, one per query. An Exception entry fails the query.
class ScriptedNtp {
  ScriptedNtp(this.results);

  final List<Object> results;
  final queried = <String>[];
  final timeouts = <Duration?>[];

  Future<NTPResponse> call({String lookUpAddress = '', Duration? timeout}) async {
    queried.add(lookUpAddress);
    timeouts.add(timeout);
    final result = results.length > 1 ? results.removeAt(0) : results.first;
    if (result is Exception) throw result;
    return result as NTPResponse;
  }
}

Future<NtpService> createService(ScriptedNtp ntp,
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ntpServiceProvider
        .overrideWith((ref) => NtpService(ref, fetchNtpData: ntp.call)),
  ]);
  addTearDown(container.dispose);
  final service = container.read(ntpServiceProvider);
  await pumpEventQueue();
  return service;
}

void main() {
  test('values before any sync finished', () async {
    final ntp = ScriptedNtp([response()]);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ntpServiceProvider
          .overrideWith((ref) => NtpService(ref, fetchNtpData: ntp.call)),
    ]);
    addTearDown(container.dispose);

    final service = container.read(ntpServiceProvider);
    expect(service.isInfoRecieved, isFalse);
    expect(service.timeServer, 'N/A');
    expect(service.ntpOffset, 0);
    expect(service.roundTripTime, 9999);
    expect(service.ntpStratum, 9999);
    expect(service.lastSyncTime, DateTime.fromMillisecondsSinceEpoch(0));
    await pumpEventQueue();
  });

  test('a successful sync exposes the response', () async {
    final service = await createService(ScriptedNtp([response()]));
    expect(service.isInfoRecieved, isTrue);
    expect(service.timeServer, '216.239.35.0');
    expect(service.ntpOffset, 250);
    expect(service.roundTripTime, 44);
    expect(service.ntpStratum, 1);
    expect(service.lastSyncTime, _syncTime);
  });

  test('currentTime applies the offset', () async {
    final service = await createService(ScriptedNtp([response(offset: 3600000)]));
    final expected = DateTime.now().add(const Duration(hours: 1));
    expect(service.currentTime.difference(expected).inSeconds.abs(),
        lessThanOrEqualTo(1));
  });

  test('a negative offset moves the clock back', () async {
    final service = await createService(ScriptedNtp([response(offset: -3600000)]));
    final expected = DateTime.now().subtract(const Duration(hours: 1));
    expect(service.currentTime.difference(expected).inSeconds.abs(),
        lessThanOrEqualTo(1));
  });

  test('queries the default server', () async {
    final ntp = ScriptedNtp([response()]);
    await createService(ntp);
    expect(ntp.queried.first, 'time.google.com');
  });

  test('queries the configured server', () async {
    final ntp = ScriptedNtp([response()]);
    await createService(ntp,
        prefs: {sharedTimeServerKey: TimeServer.timeNistGov.toString()});
    expect(ntp.queried.first, 'time.nist.gov');
  });

  test('a later sync uses a newly selected server', () async {
    final ntp = ScriptedNtp([response()]);
    final service = await createService(ntp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        sharedTimeServerKey, TimeServer.timeAppleCom.toString());
    await service.updateNtpOffset();
    expect(ntp.queried.last, 'time.apple.com');
  });

  test('every query has a time limit', () async {
    final ntp = ScriptedNtp([Exception('offline')]);
    await createService(ntp);
    expect(ntp.timeouts, [ntpQueryTimeout, ntpQueryTimeout]);
  });

  test('a successful sync sends one query', () async {
    final ntp = ScriptedNtp([response()]);
    await createService(ntp);
    expect(ntp.queried.length, 1);
  });

  test('a lost response is retried once', () async {
    final ntp = ScriptedNtp([TimeoutException('lost'), response(offset: 5)]);
    final service = await createService(ntp);
    expect(ntp.queried.length, 2);
    expect(service.isInfoRecieved, isTrue);
    expect(service.ntpOffset, 5);
  });

  test('a sync is saved for use when offline', () async {
    await createService(ScriptedNtp([response()]));
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ntpOffset'), 250);
    expect(prefs.getString('lastSyncTime'), _syncTime.toIso8601String());
  });

  group('when the server cannot be reached', () {
    test('falls back to the saved offset but reports no fresh data', () async {
      final service = await createService(ScriptedNtp([Exception('offline')]),
          prefs: {
            'ntpOffset': 77,
            'lastSyncTime': _syncTime.toIso8601String(),
          });
      expect(service.isInfoRecieved, isFalse);
      expect(service.ntpOffset, 77);
      expect(service.lastSyncTime, _syncTime);
      // Events recorded offline must not claim an accuracy.
      expect(service.roundTripTime, 9999);
    });

    test('stops after one retry', () async {
      final ntp = ScriptedNtp([TimeoutException('lost')]);
      await createService(ntp);
      expect(ntp.queried.length, 2);
    });

    test('nothing saved leaves the defaults', () async {
      final service = await createService(ScriptedNtp([Exception('offline')]));
      expect(service.ntpOffset, 0);
      expect(service.lastSyncTime, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('an unreadable saved sync time is ignored', () async {
      final service = await createService(ScriptedNtp([Exception('offline')]),
          prefs: {'lastSyncTime': 'not a date'});
      expect(service.lastSyncTime, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('a failed resync keeps the last good values', () async {
      final ntp = ScriptedNtp([response(), Exception('offline')]);
      final service = await createService(ntp);
      // Startup used the first result; this sync and its retry fail.
      await service.updateNtpOffset();
      await pumpEventQueue();
      expect(ntp.queried.length, 3);
      expect(service.isInfoRecieved, isTrue);
      expect(service.ntpOffset, 250);
    });

    test('recovers on the next successful sync', () async {
      final ntp = ScriptedNtp(
          [Exception('offline'), Exception('offline'), response(offset: 5)]);
      final service = await createService(ntp, prefs: {'ntpOffset': 77});
      expect(service.isInfoRecieved, isFalse);
      await service.updateNtpOffset();
      expect(service.isInfoRecieved, isTrue);
      expect(service.ntpOffset, 5);
    });
  });
}
