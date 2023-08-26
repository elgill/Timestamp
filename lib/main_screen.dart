import 'package:flutter/material.dart';
import 'package:timestamp/event.dart';
import 'dart:async';

import 'event_detail.dart';
import 'event_manager.dart';
import 'ntp_service.dart';
import 'package:timestamp/time_utls.dart';

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

  String formatTime(DateTime dateTime) {
    if (_displayMode == DisplayMode.absolute) {
      return formatAbsoluteTime(dateTime);
    } else {
      DateTime timeToCompare = eventManager.referenceEvent == null ? ntpService.currentTime : eventManager.referenceEvent!.time;
      return formatRelativeTime(dateTime, timeToCompare);
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
                Text('Time Server: ${ntpService.timeServer}'),
                Text('NTP Stratum: ${ntpService.ntpStratum}'),
                Text('Last Sync Time: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal())}'),
                Text('Offset: ${ntpService.ntpOffset ?? "N/A"}ms'),
                Text('Round Trip Time(RTT): ${ntpService.roundTripTime}ms'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          !isInDeleteMode ? Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TextButton(
                onPressed: _showNtpDetailsDialog,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Last Sync: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal())}'),
                    Text('Offset: ${ntpService.ntpOffset ?? "N/A"}ms'),
                  ],
                ),
              ),
            ),
          ) : ElevatedButton(
                onPressed: selectedEvents.contains(true) ? deleteSelectedEvents : deleteAllEvents,
                child: Text(selectedEvents.contains(true) ? 'Delete Selected' : 'Delete All'),
          ),
          ElevatedButton(
            onPressed: toggleDeleteMode,
            child: Text(isInDeleteMode ? 'Cancel' : 'Edit'),
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
              '±${(ntpService.roundTripTime~/2)}ms',
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
                eventManager.addEvent(Event(now, ntpService.roundTripTime~/2));
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
                    formatTime(eventManager.events[index].time),
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
                        formatTime(eventManager.events[index].time),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isInDeleteMode) {
                      Event updatedEvent = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailPage(
                            event: eventManager.events[index],
                            onSetAsReference: (event) {
                              setState(() {
                                eventManager.referenceEvent = event;
                                eventManager.saveData();
                              });
                            },
                          ),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}
