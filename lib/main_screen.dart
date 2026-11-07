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
import 'package:timestamp/providers/auto_lock_provider.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';
import 'package:timestamp/providers/custom_button_names_provider.dart';
import 'package:timestamp/providers/display_mode_provider.dart';
import 'package:timestamp/providers/max_button_rows_provider.dart';
import 'package:timestamp/providers/theme_mode_provider.dart';
import 'package:timestamp/settings_elements/settings_screen.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';
import 'package:timestamp/providers/hide_timer_provider.dart';
import 'package:timestamp/providers/record_on_touch_down_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Local imports
import 'pages/event_detail.dart';
import 'services/event_service.dart';
import 'services/ntp_service.dart';
import 'package:timestamp/utils/time_utils.dart';
import 'package:timestamp/models/event.dart';
import 'package:timestamp/utils/button_layout.dart';
import 'package:timestamp/widgets/auto_size_label.dart';

bool isIOS = Platform.isIOS;

/// Short screens (phones in landscape) get compact chrome so there is more
/// room for the record buttons.
bool isCompactHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 500;

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late EventService eventManager = EventService();
  late NtpService ntpService = ref.watch(ntpServiceProvider);

  double buttonPadding = 4.0;
  final ScrollController _buttonScrollController = ScrollController();

  DateTime displayTime = DateTime.now();
  late Timer _timer;
  late final AppLifecycleListener _lifecycleListener;

  bool isInDeleteMode = false; // To track the delete mode
  // Events selected for deletion. Held by identity: positions change when the
  // list re-sorts, and two events can be equal.
  final Set<Event> selectedEvents = Set.identity();

  void toggleDeleteMode() {
    setState(() {
      isInDeleteMode = !isInDeleteMode;
      selectedEvents.clear();
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
    final displayMode = ref.watch(displayModeProvider);
    if (displayMode == DisplayMode.absolute) {
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
    ref.read(displayModeProvider.notifier).toggleDisplayMode();
  }

  @override
  void initState() {
    super.initState();

    eventManager = ref.read(eventServiceProvider);
    ntpService = ref.read(ntpServiceProvider);

    eventManager.loadData();
    ntpService.updateNtpOffset();

    _applyAutoLockSetting();
    ref.listenManual(autoLockProvider, (_, keepAwake) {
      WakelockPlus.toggle(enable: keepAwake);
    });
    // The OS may drop the wakelock while the app is in the background.
    _lifecycleListener = AppLifecycleListener(onResume: _applyAutoLockSetting);

    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        //displayTime = ntpService.currentTime;
      });
    });
  }

  void _applyAutoLockSetting() {
    if (ref.read(autoLockProvider)) WakelockPlus.enable();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _timer.cancel();
    _buttonScrollController.dispose();
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
                        child: ntpService.isInfoRecieved &&
                                isCompactHeight(context)
                            ? Text(
                                'Last Sync: ${formatAbsoluteTime(ntpService.lastSyncTime.toLocal(), TimeFormat.local24Hour)}'
                                '  ·  Offset: ${ntpService.ntpOffset}ms'
                                '  ·  Accuracy: ±${(ntpService.roundTripTime ~/ 2)}ms')
                            : ntpService.isInfoRecieved
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
                                  Text('No Time Data Received'),
                                ],
                              ),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: selectedEvents.isNotEmpty
                        ? showDeleteSelectedEventsDialog
                        : showDeleteAllEventsDialog,
                    child: Text(selectedEvents.isNotEmpty
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
    return Column(
      children: [
        InkWell(
          onTap: () => _onEventTap(event),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 8), // Left padding
                // Checkbox or color indicator
                isInDeleteMode
                    ? _buildEventCheckbox(event)
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

  Widget _buildEventCheckbox(Event event) {
    return Checkbox(
      value: selectedEvents.contains(event),
      onChanged: (_) => _toggleSelected(event),
    );
  }

  void _toggleSelected(Event event) {
    setState(() {
      if (!selectedEvents.remove(event)) selectedEvents.add(event);
    });
  }

  _onEventTap(Event event) async {
    if (!isInDeleteMode) {
      // Not List.indexOf: it compares by value, which would confuse two
      // identical events.
      final eventIndex =
          eventManager.events.indexWhere((e) => identical(e, event));
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
      _toggleSelected(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    // On short screens the clock moves into the app bar to free up room
    // for the record buttons.
    final clockInAppBar =
        isCompactHeight(context) && !ref.watch(hideTimerProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompactHeight(context) ? 44 : null,
        centerTitle: clockInAppBar ? true : null,
        title: clockInAppBar ? _buildClock(28) : const Text('Timestamp'),
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

  Widget _buildClock(double fontSize) {
    return GestureDetector(
      onTap: () {
        toggleDisplayMode();
      },
      child: Text(
        formatTime(ntpService.currentTime),
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'Courier New',
        ),
      ),
    );
  }

  Widget _buildBody() {
    final compact = isCompactHeight(context);
    // In compact mode the clock is shown in the app bar instead.
    final showTimer = !ref.watch(hideTimerProvider) && !compact;
    final buttonsOnTop = ref.watch(sharedUtilityProvider).getButtonLocation() ==
        ButtonLocation.top;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Conditionally show the timer
        if (showTimer) Center(child: _buildClock(35)),

        // The buttons and the event list share whatever height is left, and
        // the buttons shrink if needed so every row stays visible.
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            // Spacer between the clock and the list when buttons are at the
            // bottom; not needed in compact mode, where there is no clock.
            final topSpacer =
                compact ? const SizedBox.shrink() : const Divider(thickness: 0);
            final rows = _buttonRows(ref.watch(customButtonNamesProvider));
            final layout = ButtonSectionLayout.fit(
              rows: rows.length,
              availableHeight: constraints.maxHeight -
                  (buttonsOnTop || compact ? 0 : 16),
              sectionPadding: compact
                  ? 8
                  : ButtonSectionLayout.defaultSectionPadding,
            );
            final buttons = _buildEventButtonSection(rows, layout);
            final list = Expanded(child: _buildEventList());

            return Column(
              children:
                  buttonsOnTop ? [buttons, list] : [topSpacer, list, buttons],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    return SafeArea(
      top: false,
      bottom: false,
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
                  // sectionDate is already the right calendar day for the
                  // time format, so it must not be converted again.
                  formatDate(sectionDate, TimeFormat.local24Hour),
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
    );
  }

  /// Rows of button names; a single unnamed button if none are configured.
  List<List<String?>> _buttonRows(List<String> buttonNames) {
    if (buttonNames.isEmpty) {
      return [
        [null]
      ];
    }
    return splitIntoRows(buttonNames, ref.watch(maxButtonRowsProvider));
  }

  Widget _buildEventButtonSection(
      List<List<String?>> rows, ButtonSectionLayout layout) {
    final Color color = Theme.of(context).colorScheme.onInverseSurface;
    final halfPadding = layout.sectionPadding / 2;

    Widget buttons = Column(
      children: rows.map((rowButtons) {
        return Row(
          children: rowButtons
              .map((name) => _buildRecordEventButton(name, layout.buttonHeight))
              .toList(),
        );
      }).toList(),
    );
    if (layout.scrollable) {
      buttons = Scrollbar(
        controller: _buttonScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
            controller: _buttonScrollController, primary: false, child: buttons),
      );
    }

    return Container(
      color: color,
      height: layout.sectionHeight,
      padding: EdgeInsets.symmetric(vertical: halfPadding),
      // Keep buttons out from under the notch / Dynamic Island in landscape.
      child: SafeArea(top: false, bottom: false, child: buttons),
    );
  }

  Widget _buildRecordEventButton(String? name, double height) {
    Color buttonColor = Theme.of(context).colorScheme.primary; // Default color
    PredefinedColor predefinedColor = PredefinedColor.defaultColor;

    if (name != null) {
      // Get button color from provider, passing the context
      predefinedColor = ref.watch(customButtonModelsProvider.notifier).getButtonPredefinedColor(name);
      buttonColor = predefinedColor.getColor(ref.watch(themeModeProvider), context);
    }

    void recordEvent() {
      DateTime now = ntpService.currentTime;
      int precision = -1;
      if (ntpService.isInfoRecieved) {
        precision = ntpService.roundTripTime ~/ 2;
      }
      setState(() {
        eventManager.addEvent(Event(
          now,
          precision,
          description: name ?? '',
          color: predefinedColor, // Save the button's color with the event
        ));
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
      });
    }

    final recordOnTouchDown = ref.watch(recordOnTouchDownProvider);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: SizedBox(
          height: height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: recordOnTouchDown ? (_) => recordEvent() : null,
            child: ElevatedButton(
              onPressed: recordOnTouchDown ? () {} : recordEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: name == null
                  ? const Icon(Icons.arrow_downward, size: 24) // Slightly smaller icon
                  : AutoSizeLabel(name),
            ),
          ),
        ),
      ),
    );
  }
}
