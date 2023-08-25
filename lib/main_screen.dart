import 'package:flutter/material.dart';
import 'package:ntp/ntp.dart';
import 'package:timestamp/event.dart';
import 'dart:async';

import 'event_detail.dart';

import 'package:shared_preferences/shared_preferences.dart';




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

  bool isInDeleteMode = false; // To track the delete mode
  List<bool> selectedEvents = []; // To track selected events for deletion

  void toggleDeleteMode() {
    setState(() {
      isInDeleteMode = !isInDeleteMode;
      selectedEvents = List.filled(events.length, false);
    });
  }

  void deleteSelectedEvents() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete selected events?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                setState(() {
                  for (int i = selectedEvents.length - 1; i >= 0; i--) {
                    if (selectedEvents[i]) {
                      Event removedEvent = events[i];
                      events.removeAt(i);
                      if (removedEvent == referenceEvent) {
                        referenceEvent = null;
                        referenceEvent = events.last;
                      }
                    }
                  }
                  saveData();
                  toggleDeleteMode();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void deleteAllEvents() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete all events?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                setState(() {
                  referenceEvent = null;
                  events.clear();
                  saveData();
                  toggleDeleteMode();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = events.map((e) => e.toJson()).toList();
    await prefs.setStringList('events', eventsStringList);

    if (referenceEvent != null) {
      await prefs.setString('referenceEvent', referenceEvent!.toJson());
    }
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsStringList = prefs.getStringList('events') ?? [];
    events = eventsStringList.map((e) => Event.fromJson(e)).toList();

    final referenceEventString = prefs.getString('referenceEvent');
    if (referenceEventString != null) {
      referenceEvent = Event.fromJson(referenceEventString);
    }
  }

  Future<void> _updateNtpOffset() async {
    try {
      if (_lastSyncTime == null || DateTime.now().difference(_lastSyncTime!).inMinutes >= 30) {
        _ntpData = await NTP.getNtpOffset(/*lookUpAddress: 'pool.ntp.org'*/);
        _ntpOffset = _ntpData?['offset'] ?? 0;
        _ntpError = _ntpData?['error'] ?? 9999;
        _lastSyncTime = DateTime.now();
        saveNtpData();
      }
    } catch (error) {
      // Here, handle the exception and notify the user.
      loadNtpData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update time from the NTP server. Please check your internet connection.'),
          duration: Duration(seconds: 5),
        ),
      );
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


  String formatEventTime(Event event) {
    return formatTime(event.time);
  }

  String formatTime(DateTime dateTime) {
    if (_displayMode == DisplayMode.absolute) {
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${(dateTime.millisecond ~/ 100).toString()}";
    } else {
      DateTime timeToCompare = referenceEvent == null ? _currentTime : referenceEvent!.time;

      Duration difference = dateTime.isAfter(timeToCompare)
          ? dateTime.difference(timeToCompare)
          : timeToCompare.difference(dateTime);

      String sign = dateTime.isAfter(timeToCompare) ? "+" : "-";
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
    referenceEvent ??= evt;
    events.insert(0, evt);
    saveData();
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
    loadData();
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

  Future<void> _showNtpDetailsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('NTP Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                //Text('Time Server: $_ntpServer'),
                //Text('Received NTP Time: ${_ntpTime?.toLocal().toString() ?? "N/A"}'),
                Text('Offset: ${_ntpOffset ?? "N/A"}ms'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Get Time'),
              onPressed: () async {
                await _updateNtpOffset();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TextButton(
                    onPressed: _showNtpDetailsDialog,
                    child: Text('Last Sync: ${_lastSyncTime?.toLocal().toString() ?? "N/A"}'),
                  ),
                ),
              ),
            ],
          ),

          // Second row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TextButton(
                    onPressed: _showNtpDetailsDialog,
                    child: Text('Offset: ${_ntpOffset ?? "N/A"}ms'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              '±${(_ntpError ?? 9999)}ms',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ElevatedButton(
            onPressed: toggleDeleteMode,
            child: Text(isInDeleteMode ? 'Cancel' : 'Edit'),
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
                formatTime(_currentTime),
                style: const TextStyle(
                  fontSize: 40,
                  //fontWeight: FontWeight.bold,
                  fontFamily: 'Courier New',
                ),
              ),

            )
          ),
          const SizedBox(height: 5),
          ElevatedButton(
            onPressed: () async {
              DateTime now = _currentTime;
              setState(() {
                addEvent(Event(now, _ntpError ?? 9999));
              });
            },

            child: const Icon(Icons.arrow_downward),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.5),
                  title: events[index].description.isEmpty ? Text(
                    formatEventTime(events[index]),
                    style: const TextStyle(fontSize: 24),  // Adjust this size to make the time as big as you want it to be.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ) :
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        events[index].description,
                        style: TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formatEventTime(events[index]),
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isInDeleteMode) {
                      Event updatedEvent = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailPage(event: events[index]),
                        ),
                      ) as Event;
                      setState(() {
                        events[index] = updatedEvent;
                        saveData();
                      });
                    }
                  },
                  trailing: isInDeleteMode ? Checkbox(
                    value: selectedEvents[index],
                    onChanged: (bool? value) {
                      setState(() {
                        selectedEvents[index] = value!;
                      });
                    },
                  ) : null,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isInDeleteMode ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: selectedEvents.contains(true) ? deleteSelectedEvents : deleteAllEvents,
            child: Text(selectedEvents.contains(true) ? 'Delete Selected' : 'Delete All'),
          ),
        ),
      ) : _buildBottomBar(),
    );
  }
}
