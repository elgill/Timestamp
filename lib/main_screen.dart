import 'package:flutter/material.dart';
import 'package:ntp/ntp.dart';
import 'package:timestamp/event.dart';
import 'dart:async';

import 'event_detail.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

enum DisplayMode { absolute, relative }

class _MainScreenState extends State<MainScreen> {
  List<Event> events = [];
  Event? referenceEvent;

  DateTime _currentTime = DateTime.now();
  late Timer _timer;
  Map<String, int>? _ntpData;
  int? _ntpOffset; //ms
  int? _ntpError; //ms
  DateTime? _lastSyncTime;

  DisplayMode _displayMode = DisplayMode.absolute;

  Future<void> _updateNtpOffset() async {
    if (_lastSyncTime == null || DateTime.now().difference(_lastSyncTime!).inMinutes >= 30) { // Every 30 minutes
      _ntpData = await NTP.getNtpOffset();
      _ntpOffset = _ntpData?['offset'] ?? 9999;
      _ntpError = _ntpData?['error'] ?? 9999;
      _lastSyncTime = DateTime.now();
    }
  }

  String formatEventTime(Event event) {
    return formatTime(event.time);
  }

  String formatTime(DateTime dateTime) {
    if (_displayMode == DisplayMode.absolute) {
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${(dateTime.millisecond ~/ 100).toString()}";
    } else {
      if (referenceEvent == null) {
        return "0s";
      }

      Duration difference = dateTime.isAfter(referenceEvent!.time)
          ? dateTime.difference(referenceEvent!.time)
          : referenceEvent!.time.difference(dateTime);

      String sign = dateTime.isAfter(referenceEvent!.time) ? "+" : "-";
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
  }



  void addEvent(Event evt) {
    if(referenceEvent == null){
      referenceEvent = evt;
    }
    events.insert(0, evt);
  }

  void toggleDisplayMode(){
    if (_displayMode == DisplayMode.absolute) {
      setState(() {
        _displayMode = DisplayMode.relative;
      });
    } else {
      setState(() {
        _displayMode = DisplayMode.absolute;
      });
    }
  }


  @override
  void initState() {
    super.initState();
    _updateNtpOffset();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _currentTime = DateTime.now().add(Duration(milliseconds: _ntpOffset ?? 0));
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timestamp'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '±${(_ntpError ?? 0)}ms',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: GestureDetector(  // Wrap with GestureDetector to toggle on tap
              onTap: () {
                toggleDisplayMode();
              },
              child: Text(
                "${formatTime(_currentTime)}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier New',
                ),
              ),

            )
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              DateTime now = _currentTime;
              setState(() {
                addEvent(Event(now, _ntpError ?? 0));
              });
            },

            child: const Icon(Icons.arrow_downward),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(formatEventTime(events[index])), // For simplicity, we're using ISO format.
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailPage(event: events[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
