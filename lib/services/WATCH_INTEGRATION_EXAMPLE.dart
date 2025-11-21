// WATCH INTEGRATION EXAMPLE
// This file shows how to integrate the Watch Connectivity service into your Flutter app.
// DO NOT import this file - it's for reference only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/services/watch_connectivity_service.dart';
import 'package:timestamp/providers/custom_button_models_provider.dart';

// EXAMPLE 1: Initialize Watch Connectivity in your main app
class MyAppExample extends ConsumerWidget {
  const MyAppExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the watch connectivity service
    // This ensures the service is created and listening for watch messages
    ref.read(watchConnectivityServiceProvider);

    // Listen for button changes and sync to Watch
    ref.listen<List<ButtonModel>>(
      customButtonModelsProvider,
      (previous, next) {
        // Whenever buttons change, send the update to the Watch
        final watchService = ref.read(watchConnectivityServiceProvider);
        watchService.sendToWatch(buttons: next);
      },
    );

    return MaterialApp(
      title: 'Timestamp',
      home: MainScreen(),
    );
  }
}

// EXAMPLE 2: Manually trigger a sync to Watch
class ManualSyncExample extends ConsumerWidget {
  const ManualSyncExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        // Get the watch connectivity service
        final watchService = ref.read(watchConnectivityServiceProvider);

        // Get current buttons
        final buttons = ref.read(customButtonModelsProvider);

        // Send to Watch with optional settings
        watchService.sendToWatch(
          buttons: buttons,
          settings: {
            'someSettingKey': 'someSettingValue',
          },
        );

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synced to Apple Watch')),
        );
      },
      child: const Text('Sync to Watch'),
    );
  }
}

// EXAMPLE 3: Add to your main.dart or app initialization
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize watch connectivity on app start
    ref.read(watchConnectivityServiceProvider);

    // Set up listener for button updates
    ref.listen<List<ButtonModel>>(
      customButtonModelsProvider,
      (previous, next) {
        ref.read(watchConnectivityServiceProvider).sendToWatch(buttons: next);
      },
    );

    return MaterialApp(
      title: 'Timestamp',
      home: MainScreen(),
    );
  }
}
*/

// EXAMPLE 4: Integration in your settings screen
class SettingsScreenExample extends ConsumerWidget {
  const SettingsScreenExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.watch),
            title: const Text('Sync to Apple Watch'),
            subtitle: const Text('Send all buttons to your Watch'),
            trailing: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () {
                final watchService = ref.read(watchConnectivityServiceProvider);
                final buttons = ref.read(customButtonModelsProvider);
                watchService.sendToWatch(buttons: buttons);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Synced to Apple Watch'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// NOTES:
//
// 1. The WatchConnectivityService automatically handles:
//    - Receiving event capture requests from Watch
//    - Getting buttons when Watch requests them
//    - Getting current time when Watch requests it
//    - Creating events with NTP-synchronized timestamps
//
// 2. You only need to:
//    - Initialize the service (ref.read(watchConnectivityServiceProvider))
//    - Send button updates when they change (sendToWatch)
//
// 3. The service only works on iOS devices/simulators.
//    It safely does nothing on other platforms.
//
// 4. All method channel communication is handled automatically.
//    You don't need to write any platform channel code.
//
// 5. Events captured from the Watch are automatically saved
//    to the EventService with proper NTP timestamps.
