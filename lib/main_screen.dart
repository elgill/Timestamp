import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;

// External package imports
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/enums/button_location.dart';
import 'package:timestamp/enums/predefined_colors.dart';
import 'package:timestamp/enums/time_format.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';
import 'package:timestamp/providers/max_button_rows_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';
import 'package:timestamp/settings_elements/settings_screen.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Local imports
import 'pages/event_detail.dart';
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
  late NtpService ntpService = ref.watch(ntpServiceProvider);

  double buttonPadding = 4.0;

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
        return PlatformAlertDialog(
          title: const Text('Confirm Deletion'),
          content:
              const Text('Are you sure you want to delete selected events?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        return PlatformAlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete all events?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      return formatAbsoluteTime(
          dateTime, ref.watch(sharedUtilityProvider).getTimeFormat());
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

    WakelockPlus.disable();
  }

  Map<DateTime, List<Event>> get _groupedEvents {
    final grouped = groupBy<Event, DateTime>(
      eventManager.events,
      (event) {
        DateTime dateTime = event.time;
        if (ref.watch(sharedUtilityProvider).getTimeFormat() ==
            TimeFormat.utc24Hour) {
          dateTime = dateTime.toUtc();
        }
        return DateTime(dateTime.year, dateTime.month, dateTime.day);
      },
    );
    final sortedKeys = grouped.keys.toList()
      ..sort(
          (a, b) => b.compareTo(a)); // this sorts the dates in descending order
    return Map.fromEntries(
        sortedKeys.map((key) => MapEntry(key, grouped[key]!)));
  }

  Future<void> _showNtpDetailsDialog() async {
    return showPlatformDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PlatformAlertDialog(
          title: const Text('NTP Details'),
          content: ntpService.isInfoRecieved
              ? Column(
            mainAxisSize: MainAxisSize.min, // Make it fit content
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('Time Server: ${ntpService.timeServer}'),
              Text('NTP Stratum: ${ntpService.ntpStratum}'),
              Text(
                  'Last Sync Time: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal(), TimeFormat.local24Hour)}'),
              Text('Offset: ${ntpService.ntpOffset}ms'),
              Text(
                  'Round Trip Time(RTT): ${ntpService.roundTripTime}ms'),
            ],
          )
              : const Text('No Time Data Received'),
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
                Navigator.of(context).pop();
                await ntpService
                    .updateNtpOffset(); // Await the fetching response
                _showNtpDetailsDialog(); // Reopen the dialog
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
                        child: ntpService.isInfoRecieved
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Last Sync: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal(), TimeFormat.local24Hour)}'),
                                  Text('Offset: ${ntpService.ntpOffset}ms'),
                                  Text(
                                      'Accuracy: ±${(ntpService.roundTripTime ~/ 2)}ms'),
                                ],
                              )
                            : const Column(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red, // This is the background color
                    ),
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
        InkWell(
          onTap: () => _onEventTap(event, eventIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 8), // Left padding
                // Checkbox or color indicator
                isInDeleteMode
                    ? _buildEventCheckbox(eventIndex)
                    : _buildColorIndicator(event),
                const SizedBox(width: 12), // Space between indicator and content
                // Event content
                Expanded(
                  child: _buildEventTitle(event),
                ),
                const SizedBox(width: 8), // Right padding
              ],
            ),
          ),
        ),
        const Divider(height: 1.0),
      ],
    );
  }

  Widget _buildColorIndicator(Event event) {
    // Only show color indicator if it's not the default color
    if (event.color != PredefinedColor.defaultColor) {
      return Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
          color: event.color.getColor(
              ref.watch(themeModeProvider),
              context
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    // Return an invisible spacer if no color is set
    return const SizedBox(width: 4);
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailPage(
            event: eventManager.events[eventIndex],
            onSetAsReference: (event) {
              setState(() {
                eventManager.referenceEvent = event;
                eventManager.saveData();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Reference Event Set!'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              );
            },
            onEventUpdated: (updatedEvent) {
              // Update the event in the events list immediately
              setState(() {
                eventManager.events[eventIndex] = updatedEvent;
                eventManager.saveData();
              });
            },
          ),
        ),
      );
    } else {
      setState(() {
        // Toggle the selection state for the corresponding event
        selectedEvents[eventIndex] = !selectedEvents[eventIndex];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sharedUtilityProvider).getDisableAutoLock()) {
      WakelockPlus.enable();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timestamp'),
        actions: [
          IconButton(
            icon: isIOS
                ? const Icon(CupertinoIcons.settings)
                : const Icon(Icons.settings),
            onPressed: () {
              isInDeleteMode = false;
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

  Widget _buildBody() {
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
        ref.watch(sharedUtilityProvider).getButtonLocation() ==
                ButtonLocation.top
            ? _buildEventButtonSection(true, true)
            : const Divider(thickness: 0),
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
                      formatDate(sectionDate,
                          ref.watch(sharedUtilityProvider).getTimeFormat()),
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
        ref.watch(sharedUtilityProvider).getButtonLocation() ==
                ButtonLocation.bottom
            ? _buildEventButtonSection(true, true)
            : Container(),
      ],
    );
  }

  Widget _buildEventButtonSection(bool topDivider, bool bottomDivider) {
    final Color color = Theme.of(context).colorScheme.onInverseSurface;

    return Container(
      color: color,
      child: Column(
        children: [
          topDivider
              ? SizedBox(
                  height: 8,
                  child: Center(
                    child: Container(
                      height: 0,
                    ),
                  ),
                )
              : Container(),
          _buildRecordEventButtons(ref.watch(customButtonNamesProvider)),
          bottomDivider
              ? SizedBox(
                  height: 8,
                  child: Center(
                    child: Container(
                      height: 0,
                    ),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }

  Widget _buildRecordEventButtons(List<String> buttonNames) {
    int numberOfButtonRows = ref.watch(maxButtonRowsProvider);

    if (buttonNames.isEmpty) {
      return Row(
        children: [_buildRecordEventButton(null)],
      );
    }

    int totalButtons = buttonNames.length;
    List<List<String>> rows = [];

    for (int i = 0; i < numberOfButtonRows; i++) {
      int startIndex = (i * totalButtons / numberOfButtonRows).floor();
      int endIndex = ((i + 1) * totalButtons / numberOfButtonRows).floor();
      if (startIndex < totalButtons) {
        rows.add(buttonNames.sublist(startIndex, endIndex));
      }
    }

    return Column(
      children: rows.map((rowButtons) {
        return Row(
          children: rowButtons.map((name) => _buildRecordEventButton(name)).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildRecordEventButton(String? name) {
    Color buttonColor = Theme.of(context).colorScheme.primary; // Default color
    PredefinedColor predefinedColor = PredefinedColor.defaultColor;

    if (name != null) {
      // Get button color from provider, passing the context
      predefinedColor = ref.watch(customButtonModelsProvider.notifier).getButtonPredefinedColor(name);
      buttonColor = predefinedColor.getColor(ref.watch(themeModeProvider), context);
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: SizedBox(
          height: 60, // Reduced height to accommodate multiple rows
          child: ElevatedButton(
            onPressed: () async {
              DateTime now = ntpService.currentTime;
              int precision = -1;
              if (ntpService.isInfoRecieved) {
                precision = ntpService.roundTripTime ~/ 2;
              }
              setState(() {
                eventManager.addEvent(
                    Event(
                      now,
                      precision,
                      description: name ?? '',
                      color: predefinedColor, // Save the button's color with the event
                    )
                );
                selectedEvents.insert(0, false);
                SystemSound.play(SystemSoundType.click);
                HapticFeedback.lightImpact();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: name == null
                ? const Icon(Icons.arrow_downward, size: 24) // Slightly smaller icon
                : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: const TextStyle(fontSize: 14), // Slightly smaller font
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
