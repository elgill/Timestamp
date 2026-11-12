import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _topics = [
    (
      icon: Icons.arrow_downward,
      title: 'Record an event',
      text: 'Tap a record button to save the exact time. Events are listed '
          'by day, newest first.',
    ),
    (
      icon: Icons.text_fields,
      title: 'Custom buttons',
      text: 'Add named, colored buttons in Settings > Custom Button Names. '
          'Each one labels its events automatically.',
    ),
    (
      icon: Icons.edit,
      title: 'Event details',
      text: 'Tap an event to see its precision or change its description '
          'and color.',
    ),
    (
      icon: Icons.delete,
      title: 'Delete events',
      text: 'Tap Edit, select events, then tap Delete Selected. If nothing '
          'is selected, the button deletes all events.',
    ),
    (
      icon: Icons.cloud,
      title: 'Time accuracy',
      text: 'The app syncs with a time server when it opens. The bottom bar '
          'shows the last sync and accuracy. Tap it for details or to sync '
          'again.',
    ),
    (
      icon: Icons.event,
      title: 'Add a past event',
      text: 'Use Settings > Manual Event Entry to add an event at any date '
          'and time.',
    ),
    (
      icon: Icons.share,
      title: 'Share your log',
      text: 'Use Settings > Share Event Log to send your events as text.',
    ),
    (
      icon: Icons.settings,
      title: 'More settings',
      text: 'Settings also has options for time format, theme, button '
          'layout, recording on touch down and keeping the screen on.',
    ),
  ];

  /// Newest first, like the event list.
  static const relativeTimeExample = [
    (label: 'Later', clock: '09:01:30.5', relative: '+00:01:30.5'),
    (label: 'Reference', clock: '09:00:00.0', relative: '00:00:00.0'),
    (label: 'Earlier', clock: '08:59:50.0', relative: '-00:00:10.0'),
  ];

  static const _relativeTime = (
    icon: Icons.schedule,
    title: 'Relative time',
    text: 'Shows how long before (-) or after (+) the reference event '
        'everything happened. Tap the clock to turn it on or off, or use '
        'Settings > Time Display Mode. The first event is the reference '
        'until you tap another event and choose Set as Reference.',
  );

  /// Only the iOS app has the Record Event action.
  static const _shortcuts = (
    icon: Icons.bolt,
    title: 'Shortcuts, Siri and the Action button',
    text: 'Record Event records with any of your buttons from Shortcuts, '
        'Siri, Spotlight or the Action button, on iPhone and Apple Watch. On '
        'an Apple Watch Ultra, choose Settings > Action Button > Controls > '
        'Timestamp. These events are timed when the action runs, a moment '
        'after you start it, so they are less precise than a tap and their '
        'precision shows as unknown.',
  );

  Widget _buildTopic(
    ({IconData icon, String title, String text}) topic, {
    Widget? example,
  }) {
    return ListTile(
      leading: Icon(topic.icon),
      title: Text(topic.title),
      subtitle: example == null
          ? Text(topic.text)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.text),
                const SizedBox(height: 8),
                example,
              ],
            ),
    );
  }

  Widget _buildRelativeTimeExample() {
    TableRow row(String label, String clock, String relative) {
      return TableRow(children: [Text(label), Text(clock), Text(relative)]);
    }

    return Table(
      children: [
        row('Event', 'Time', 'Relative'),
        for (final example in relativeTimeExample)
          row(example.label, example.clock, example.relative),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          children: [
            _buildTopic(_topics.first),
            _buildTopic(_relativeTime, example: _buildRelativeTimeExample()),
            ..._topics.skip(1).map(_buildTopic),
            if (defaultTargetPlatform == TargetPlatform.iOS)
              _buildTopic(_shortcuts),
          ],
        ),
      ),
    );
  }
}
