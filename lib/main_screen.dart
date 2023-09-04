import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;


// External package imports
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/pages/settings.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

// Local imports
import 'event_detail.dart';
import 'services/event_service.dart';
import 'services/ntp_service.dart';
import 'package:timestamp/utils/time_utils.dart';
import 'package:timestamp/models/event.dart';

bool isIOS = Platform.isIOS;

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

enum DisplayMode { absolute, relative }

class _MainScreenState extends ConsumerState<MainScreen> {
  late EventService eventManager = EventService();
  late NtpService ntpService = NtpService();

  DateTime displayTime = DateTime.now();
  late Timer _timer;

  DisplayMode _displayMode = DisplayMode.absolute;

  bool isInDeleteMode = false; // To track the delete mode
  List<bool> selectedEvents = []; // To track selected events for deletion

  void toggleDeleteMode() {
    setState(() {
      isInDeleteMode = !isInDeleteMode;
      selectedEvents =
          List.generate(eventManager.events.length, (index) => false);
    });
  }

  void showDeleteSelectedEventsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content:
              const Text('Are you sure you want to delete selected events?'),
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

  void showDeleteAllEventsDialog() {
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
      return formatAbsoluteTime(dateTime, !ref.watch(sharedUtilityProvider).is24HourTimeEnabled());
    } else {
      DateTime timeToCompare = eventManager.referenceEvent == null
          ? dateTime
          : eventManager.referenceEvent!.time;
      return formatRelativeTime(dateTime, timeToCompare);
    }
  }

  void toggleDisplayMode() {
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

    eventManager = ref.read(eventServiceProvider);
    ntpService = ref.read(ntpServiceProvider);

    eventManager.loadData();
    ntpService.updateNtpOffset();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        //displayTime = ntpService.currentTime;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Map<DateTime, List<Event>> get _groupedEvents {
    final grouped = groupBy<Event, DateTime>(
      eventManager.events,
      (event) => DateTime(event.time.year, event.time.month, event.time.day),
    );
    final sortedKeys = grouped.keys.toList()
      ..sort(
          (a, b) => b.compareTo(a)); // this sorts the dates in descending order
    return Map.fromEntries(
        sortedKeys.map((key) => MapEntry(key, grouped[key]!)));
  }

  Future<void> _showNtpDetailsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('NTP Details'),
          content: SingleChildScrollView(
            child: ntpService.isInfoRecieved ? ListBody(
              children: <Widget>[
                Text('Time Server: ${ntpService.timeServer}'),
                Text('NTP Stratum: ${ntpService.ntpStratum}'),
                Text('Last Sync Time: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal(), false)}'),
                Text('Offset: ${ntpService.ntpOffset}ms'),
                Text('Round Trip Time(RTT): ${ntpService.roundTripTime}ms'),
              ],
            ) : const Text('No Time Data Received'),
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
          !isInDeleteMode
              ? Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TextButton(
                        onPressed: _showNtpDetailsDialog,
                        child: ntpService.isInfoRecieved ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                'Last Sync: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal(), false)}'),
                            Text('Offset: ${ntpService.ntpOffset}ms'),
                            Text(
                                'Accuracy: ±${(ntpService.roundTripTime ~/ 2)}ms'),
                          ],
                        ): const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No Time Data Recieved'),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: selectedEvents.contains(true)
                        ? showDeleteSelectedEventsDialog
                        : showDeleteAllEventsDialog,
                    child: Text(selectedEvents.contains(true)
                        ? 'Delete Selected'
                        : 'Delete All'),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: toggleDeleteMode,
              child: Text(isInDeleteMode ? 'Cancel' : 'Edit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    final eventIndex = eventManager.events.indexOf(event);

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
          //leading: Icon(Icons.event), // As an example
          title: _buildEventTitle(event),
          onTap: () => _onEventTap(event, eventIndex),
          trailing: isInDeleteMode ? _buildEventCheckbox(eventIndex) : null,
        ),
        const Divider(height: 1.0),
      ],
    );
  }

  Widget _buildEventTitle(Event event) {
    if (event.description.isEmpty) {
      return Text(
        formatTime(event.time),
        style: const TextStyle(
          fontSize: 24,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.description,
            style: const TextStyle(
              fontSize: 20,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            formatTime(event.time),
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildEventCheckbox(int eventIndex) {
    return Checkbox(
      value: selectedEvents[eventIndex],
      onChanged: (bool? value) {
        setState(() {
          selectedEvents[eventIndex] = value!;
        });
      },
    );
  }

  _onEventTap(Event event, int eventIndex) async {
    if (!isInDeleteMode) {
      Event updatedEvent = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailPage(
            event: eventManager.events[eventIndex],
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
        eventManager.events[eventIndex] = updatedEvent;
        eventManager.saveData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timestamp'),
        actions: [
          IconButton(
            icon: isIOS ? const Icon(CupertinoIcons.settings) : const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody(){
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
            child: GestureDetector(
              // Wrap with GestureDetector to toggle on tap
              onTap: () {
                toggleDisplayMode();
              },
              child: Text(
                formatTime(ntpService.currentTime),
                style: const TextStyle(
                  fontSize: 35,
                  fontFamily: 'Courier New',
                ),
              ),
            )),
        const SizedBox(height: 5),
        ElevatedButton(
          onPressed: () async {
            DateTime now = ntpService.currentTime;
            int precision = -1;
            if(ntpService.isInfoRecieved){
              precision = ntpService.roundTripTime ~/ 2;
            }
            setState(() {
              eventManager
                  .addEvent(Event(now, precision));
              selectedEvents.insert(0, false);
            });
          },
          child: const Icon(Icons.arrow_downward),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _groupedEvents.entries.length,
            itemBuilder: (context, sectionIndex) {
              final sectionDate = _groupedEvents.keys.toList()[sectionIndex];
              final eventsOfThisDate = _groupedEvents[sectionDate]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Text(
                      formatDate(sectionDate),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Column(
                    children: eventsOfThisDate.map((event) {
                      return _buildEventTile(event);
                    }).toList(),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
