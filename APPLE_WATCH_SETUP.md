# Apple Watch Companion App Setup Guide

This guide will help you set up the Apple Watch companion app for Timestamp.

## Overview

The Apple Watch companion app provides:
- **Main Screen**: Shows TOD (Time of Day) or running time + "Add Generic Event" button
- **Secondary Screen**: Horizontal swipe to view all custom event buttons
- **Haptic/Audio Feedback**: Vibration and sound on button press
- **Real-time Sync**: Communicates with iPhone app via Watch Connectivity

## Project Structure

```
ios/
├── Runner/                          # Main iOS app
│   ├── AppDelegate.swift           # Updated with Watch Connectivity
│   └── WatchConnectivityManager.swift  # Bridge between iOS and Watch
└── WatchApp/                        # Watch extension (NEW)
    ├── TimestampApp.swift          # Watch app entry point
    ├── WatchConnectivityProvider.swift  # Watch-side connectivity
    ├── ButtonModel.swift           # Button data model
    ├── ContentView.swift           # Main Watch UI
    └── Info.plist                  # Watch app configuration
```

## Setup Steps

### 1. Open Xcode Project

```bash
cd ios
open Runner.xcworkspace  # or Runner.xcodeproj
```

### 2. Add WatchKit App Target

1. In Xcode, go to **File → New → Target**
2. Select **watchOS → Watch App**
3. Configure:
   - Product Name: `Timestamp Watch`
   - Bundle Identifier: `com.elgill.timestamp.watchkitapp`
   - Organization Identifier: `com.elgill`
   - Language: **Swift**
   - User Interface: **SwiftUI**
   - Include Notification Scene: **No** (optional)
4. Click **Finish**
5. Click **Activate** when prompted to activate the Watch scheme

### 3. Add Watch Extension Target

If not automatically created:
1. Go to **File → New → Target**
2. Select **watchOS → Watch Extension**
3. Configure:
   - Product Name: `Timestamp Watch Extension`
   - Bundle Identifier: `com.elgill.timestamp.watchkitapp.watchkitextension`
4. Click **Finish**

### 4. Add Watch Source Files

1. **Delete** the auto-generated files in the Watch App target (if any):
   - `ContentView.swift` (we'll use our custom one)
   - `TimestampWatchApp.swift` (we'll use our custom one)

2. **Add** our custom files from `ios/WatchApp/`:
   - Right-click on the Watch App group in Xcode
   - Select **Add Files to "Runner"...**
   - Navigate to `ios/WatchApp/`
   - Select all `.swift` files
   - **Important**: Check the box for the **Watch App target** (not Runner)
   - Click **Add**

Files to add:
- `TimestampApp.swift`
- `WatchConnectivityProvider.swift`
- `ButtonModel.swift`
- `ContentView.swift`

3. **Replace** the Watch App `Info.plist`:
   - Delete the auto-generated `Info.plist` in the Watch App group
   - Add our custom `Info.plist` from `ios/WatchApp/Info.plist`

### 5. Add WatchConnectivityManager to iOS App

1. In Xcode, locate the **Runner** group
2. Right-click and select **Add Files to "Runner"...**
3. Navigate to `ios/Runner/`
4. Select `WatchConnectivityManager.swift`
5. Ensure the **Runner target** is checked
6. Click **Add**

The `AppDelegate.swift` has already been updated with Watch Connectivity code.

### 6. Configure App Groups (Optional but Recommended)

App Groups allow the iOS app and Watch app to share data.

1. Select the **Runner** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and create: `group.com.elgill.timestamp`
6. Repeat for the **Watch App** target

### 7. Update Bundle Identifiers

Make sure your bundle identifiers match:

- **iOS App**: `com.elgill.timestamp`
- **Watch App**: `com.elgill.timestamp.watchkitapp`
- **Watch Extension**: `com.elgill.timestamp.watchkitapp.watchkitextension`

Update these in:
- Xcode target settings (**Signing & Capabilities**)
- `ios/WatchApp/Info.plist` → `WKCompanionAppBundleIdentifier`

### 8. Add Assets (App Icons)

The Watch app requires specific icon sizes:

1. In Xcode, locate **Assets.xcassets** in the Watch App group
2. Add an **App Icon** for watchOS:
   - 40x40 (2x and 3x)
   - 44x44 (2x and 3x)
   - 50x50 (2x and 3x)
   - 86x86 (2x and 3x)
   - 98x98 (2x and 3x)
   - 108x108 (2x and 3x)

You can use the same icon as your iOS app, resized to these dimensions.

### 9. Build and Run

1. Select the **Watch App** scheme in Xcode
2. Select a Watch simulator (e.g., "Apple Watch Series 8 (45mm)")
3. Click **Run** (⌘R)

The Watch app should launch on the simulator.

### 10. Test with iOS Simulator

To test the full integration:

1. Build and run the **iOS app** on an iPhone simulator
2. Build and run the **Watch app** on a Watch simulator **paired with the same iPhone**
3. The apps should communicate via Watch Connectivity

**Note**: You need to pair the Watch simulator with the iPhone simulator:
- Open **Xcode → Window → Devices and Simulators**
- Select the Watch simulator
- Ensure it's paired with your iPhone simulator

## Flutter Integration

The Flutter side has already been set up with:
- `lib/services/watch_connectivity_service.dart` - Method channel bridge
- Method channel name: `com.timestamp.watch`

### Initialize Watch Connectivity in Flutter

To enable Watch sync, you'll need to initialize and use the Watch Connectivity service in your Flutter app.

Add this to your app initialization (e.g., `lib/main.dart` or a state provider):

```dart
import 'package:timestamp/services/watch_connectivity_service.dart';

// In your app initialization or main screen
final watchService = ref.read(watchConnectivityServiceProvider);

// Send button updates to Watch whenever they change
ref.listen(customButtonModelsProvider, (previous, next) {
  watchService.sendToWatch(buttons: next);
});
```

## How It Works

### Communication Flow

```
┌─────────────────┐                  ┌──────────────────┐
│   iPhone App    │                  │   Apple Watch    │
│   (Flutter)     │                  │   (SwiftUI)      │
└────────┬────────┘                  └────────┬─────────┘
         │                                    │
         │  1. User adds/updates buttons     │
         │     in iPhone app                 │
         ├───────────────────────────────────>│
         │  2. Flutter → iOS bridge          │
         │     (Method Channel)              │
         │                                    │
         │  3. WatchConnectivityManager      │
         │     sends to Watch                │
         ├───────────────────────────────────>│
         │  4. Watch receives buttons        │
         │                                    │
         │  5. User taps button on Watch     │
         │<───────────────────────────────────┤
         │  6. Watch sends event to iPhone   │
         │                                    │
         │  7. iOS → Flutter bridge          │
         │     (Method Channel)              │
         │                                    │
         │  8. Event saved in Flutter        │
         │     with NTP timestamp            │
         └────────────────────────────────────┘
```

### Data Flow

1. **iPhone → Watch (Button Sync)**:
   - Flutter app calls `watchService.sendToWatch(buttons: buttonList)`
   - iOS `WatchConnectivityManager` receives via method channel
   - Sends to Watch via `WCSession.updateApplicationContext()`
   - Watch `WatchConnectivityProvider` updates UI

2. **Watch → iPhone (Event Capture)**:
   - User taps button on Watch
   - Watch sends message to iPhone via `WCSession.sendMessage()`
   - iOS `WatchConnectivityManager` receives message
   - Calls Flutter via method channel: `captureEventFromWatch`
   - Flutter creates Event with NTP-synchronized timestamp
   - Event saved to `EventService`

## Features

### Main Screen (Watch)
- Large time display (updates every second)
- Toggle between Time of Day and Running Time (matches iPhone setting)
- "Add Generic Event" button (blue, prominent)
- Connection status indicator

### Custom Buttons Screen (Watch)
- Horizontal swipe from main screen
- Scrollable list of all custom buttons
- Color-coded buttons matching iPhone app
- Shows "No custom buttons" message if empty

### Feedback
- **Haptic**: Vibration on button tap (`WKInterfaceDevice.play()`)
- **Audio**: Success/failure tones
- **Visual**: Button press animations

## Troubleshooting

### Watch app won't build
- Ensure all targets have valid signing certificates
- Check bundle identifiers are correct
- Verify Watch app target includes all required files

### Watch and iPhone won't communicate
- Ensure both simulators are running simultaneously
- Check simulators are paired (Xcode → Devices and Simulators)
- Verify `WatchConnectivityManager.swift` is in Runner target
- Check method channel name matches: `com.timestamp.watch`

### Events from Watch don't appear on iPhone
- Check Flutter console for errors
- Verify `WatchConnectivityService` is initialized
- Ensure NTP service is working (check app permissions)

### Buttons don't sync to Watch
- Add the listen block for `customButtonModelsProvider` (see Flutter Integration above)
- Check iOS console for "Sent X buttons to Watch" message
- Verify Watch Connectivity is activated (check logs)

## Testing Checklist

- [ ] iOS app builds and runs
- [ ] Watch app builds and runs
- [ ] Time displays correctly on Watch
- [ ] "Add Generic Event" button works (event appears on iPhone)
- [ ] Custom buttons sync from iPhone to Watch
- [ ] Custom button taps create events on iPhone
- [ ] Haptic feedback works on button press
- [ ] Time display mode syncs between devices
- [ ] Watch shows connection status

## Next Steps

### Optional Enhancements
1. **Complications**: Add Watch face complications showing time/event count
2. **Background Sync**: Implement background updates for time
3. **Standalone Mode**: Allow Watch app to work independently (with local storage)
4. **Notifications**: Push notifications from iPhone to Watch when events occur
5. **Voice Input**: Add Siri/dictation for custom event descriptions

### Production Checklist
- [ ] Add proper error handling
- [ ] Implement retry logic for failed syncs
- [ ] Add user feedback for sync status
- [ ] Test on physical devices (not just simulators)
- [ ] Add Watch app screenshots for App Store
- [ ] Update App Store listing to mention Watch support

## Resources

- [WatchConnectivity Framework](https://developer.apple.com/documentation/watchconnectivity)
- [Building Your First watchOS App](https://developer.apple.com/documentation/watchos-apps)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)

## Support

If you encounter issues:
1. Check Xcode console for error messages
2. Check Flutter console with `flutter run -v`
3. Enable verbose logging in `WatchConnectivityManager.swift`
4. Verify all source files are in correct targets
