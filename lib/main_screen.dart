import 'package:flutter/material.dart';
import 'package:timestamp/event.dart';
import 'dart:async';

import 'event_detail.dart';
import 'event_manager.dart';
import 'ntp_service.dart';




class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

enum DisplayMode { absolute, relative }

class _MainScreenState extends State<MainScreen> {
  final EventManager eventManager = EventManager();
  final NtpService ntpService = NtpService();

  DateTime displayTime = DateTime.now();
  late Timer _timer;

  DisplayMode _displayMode = DisplayMode.absolute;

  bool isInDeleteMode = false; // To track the delete mode
  List<bool> selectedEvents = []; // To track selected events for deletion

  void toggleDeleteMode() {
    setState(() {
      isInDeleteMode = !isInDeleteMode;
      selectedEvents = List.filled(eventManager.events.length, false);
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
                  eventManager.deleteSelectedEvents(selectedEvents);
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
                  eventManager.deleteAllEvents();
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

  String formatEventTime(Event event) {
    return formatTime(event.time);
  }

  String formatTime(DateTime dateTime) {
    if (_displayMode == DisplayMode.absolute) {
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${(dateTime.millisecond ~/ 100).toString()}";
    } else {
      DateTime timeToCompare = eventManager.referenceEvent == null ? ntpService.currentTime : eventManager.referenceEvent!.time;

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
    eventManager.loadData();
    ntpService.updateNtpOffset();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        displayTime = ntpService.currentTime;
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
          title: const Text('NTP Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                //Text('Time Server: $_ntpServer'),
                //Text('Received NTP Time: ${_ntpTime?.toLocal().toString() ?? "N/A"}'),
                Text('Offset: ${ntpService.ntpOffset ?? "N/A"}ms'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Get Time'),
              onPressed: () async {
                ntpService.updateNtpOffset();
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
                    child: Text('Last Sync: ${ntpService.lastSyncTime.toLocal().toString() ?? "N/A"}'),
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
                    child: Text('Offset: ${ntpService.ntpOffset ?? "N/A"}ms'),
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
              '±${(ntpService.ntpError ?? 9999)}ms',
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
                formatTime(ntpService.currentTime),
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
              DateTime now = ntpService.currentTime;
              setState(() {
                eventManager.addEvent(Event(now, ntpService.ntpError ?? 9999));
              });
            },

            child: const Icon(Icons.arrow_downward),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: eventManager.events.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.5),
                  title: eventManager.events[index].description.isEmpty ? Text(
                    formatEventTime(eventManager.events[index]),
                    style: const TextStyle(fontSize: 24),  // Adjust this size to make the time as big as you want it to be.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ) :
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eventManager.events[index].description,
                        style: const TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formatEventTime(eventManager.events[index]),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isInDeleteMode) {
                      Event updatedEvent = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailPage(event: eventManager.events[index]),
                        ),
                      ) as Event;
                      setState(() {
                        eventManager.events[index] = updatedEvent;
                        eventManager.saveData();
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
