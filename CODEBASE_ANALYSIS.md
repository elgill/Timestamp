# Timestamp App - Codebase Analysis

## 1. App Type & Technology Stack

**Type:** Flutter Multi-Platform Application (Native iOS, Android, macOS, Windows, Linux, Web)

**Framework:** Flutter with Dart
- **State Management:** Flutter Riverpod
- **Platform Support:** iOS, Android, macOS, Windows, Linux, Web
- **Version:** 1.1.2 (Build 32)

**Key Dependencies:**
- `advanced_ntp`: Custom NTP library for precision time synchronization
- `flutter_riverpod`: Modern state management
- `shared_preferences`: Local data persistence
- `wakelock_plus`: Screen wake lock to prevent auto-lock
- `flutter_platform_widgets`: Platform-specific UI (iOS/Android)
- `settings_ui`: Settings screens UI
- `share_plus`: Event sharing functionality
- `intl`: Internationalization and formatting

---

## 2. Current App Structure & Main Features

### Core Functionality
**Precise Timestamp** is an application for capturing high-precision event timestamps synchronized via NTP (Network Time Protocol) servers. It provides timing accuracy down to the tenth of a second (millisecond precision).

### Main Features

1. **NTP Synchronization**
   - Syncs with configurable time servers (pool.ntp.org, time.apple.com, time.google.com, time.cloudflare.com, time.nist.gov)
   - Maintains NTP offset, stratum, RTT (Round Trip Time)
   - Caches sync data for offline use
   - Displays sync information with accuracy estimates

2. **Event Capture & Management**
   - One-tap event timestamping with custom buttons
   - Manual event creation with custom date/time pickers
   - Event grouping by date in main list
   - Edit event descriptions and colors
   - Delete single or multiple events
   - Reference event support (for relative time calculations)

3. **Time Display Modes**
   - **Absolute Time (TOD)**: Shows actual time of day (e.g., 2:45:30 PM)
   - **Relative Time**: Shows time offset from a reference event (e.g., +0:02:15)
   - Toggle between modes by tapping the running time display
   - Time format options: Local 12-Hour, Local 24-Hour, UTC 24-Hour

4. **Custom Button System**
   - Create custom named buttons that auto-label events
   - Configurable button colors (Default, Red, Green, Orange, Purple)
   - Multi-row button layout (configurable rows)
   - Button location (top or bottom of screen)

5. **Settings & Customization**
   - Hide/show the running timer display
   - Disable auto-lock (keep screen on)
   - Button location and layout configuration
   - Theme selection (Light/Dark/System)
   - Time format and display mode settings

### Architecture Overview

```
lib/
├── main.dart                    # App entry point
├── main_screen.dart            # Main UI (632 lines)
├── app_providers.dart          # App-level providers
├── constants.dart              # App constants
│
├── models/
│   ├── event.dart             # Event data model (time, precision, description, color)
│   └── button_model.dart      # Button data model (name, color)
│
├── services/
│   ├── event_service.dart     # Event CRUD operations
│   ├── ntp_service.dart       # NTP time synchronization
│   ├── share_service.dart     # Event sharing
│   └── export_service.dart    # Event export functionality
│
├── providers/                  # Riverpod state management
│   ├── shared_pref_provider.dart    # Shared preferences wrapper
│   ├── display_mode_provider.dart   # Time display mode (Absolute/Relative)
│   ├── hide_timer_provider.dart     # Show/hide running timer
│   ├── custom_button_*_provider.dart # Custom button configuration
│   ├── theme_mode_provider.dart     # Theme selection
│   ├── time_format_provider.dart    # Time format selection
│   └── [other providers]            # Additional settings
│
├── pages/
│   └── event_detail.dart      # Event edit/view page
│
├── settings_elements/          # Settings UI screens
│   ├── settings_screen.dart
│   ├── select_time_format_screen.dart
│   ├── select_time_display_mode_screen.dart
│   ├── manage_button_names_screen.dart
│   └── [other setting screens]
│
├── utils/
│   └── time_utils.dart        # Time formatting utilities
│
└── enums/
    ├── time_format.dart       # TimeFormat enum
    ├── time_server.dart       # TimeServer enum
    ├── button_location.dart   # ButtonLocation enum
    └── predefined_colors.dart # PredefinedColor enum
```

---

## 3. Events & Button Implementation

### Event Model (`lib/models/event.dart`)
```dart
class Event {
  DateTime time;           // Event timestamp
  int precision;           // Precision in milliseconds (RTT/2)
  String description;      // Event name/description
  PredefinedColor color;   // Event color for UI
}
```

### How Events Are Captured (Main Button Press Flow)

**Location:** `lib/main_screen.dart`, lines 592-610

```dart
// When user taps a button:
DateTime now = ntpService.currentTime;  // Get NTP-synchronized time
int precision = ntpService.roundTripTime ~/ 2;  // Calculate precision

// Create and add event
eventManager.addEvent(Event(
  now,
  precision,
  description: buttonName ?? '',  // Auto-named from button
  color: predefinedColor,         // Button's color
));

// Provide feedback
SystemSound.play(SystemSoundType.click);
HapticFeedback.lightImpact();
```

### Custom Button System

**Button Layout:** `lib/main_screen.dart`, lines 547-574
- Dynamically creates button rows based on `maxButtonRowsProvider`
- Each button name in `customButtonNamesProvider` becomes a button
- Buttons are evenly distributed across rows

**Default Button:**
- When no custom buttons exist, shows arrow-down icon
- Same functionality (captures event with empty description)

**Button Properties** (`lib/models/button_model.dart`):
```dart
class ButtonModel {
  String name;                      // Button label
  PredefinedColor predefinedColor;  // Button color
}
```

---

## 4. "TOD" & "Running Time" Explained

### TOD (Time Of Day)
- **Definition:** Refers to the "Absolute Time" display mode
- **Description:** Shows the actual time of day (e.g., 2:45:30 PM)
- **Contrast:** Opposite to "Relative Time" mode (e.g., +0:02:15 from reference event)
- **Toggle:** Tap the main running time display at the top to switch between modes
- **Source:** Based on NTP-synchronized current time from `ntpService.currentTime`

### Running Time
- **Definition:** The live-updating time display at the top center of the main screen
- **Function:** Shows current time in real-time
- **Visibility:** Can be hidden via Settings → Display Settings → "Hide Running Timer"
- **Update Rate:** Updates continuously (timer runs every 10ms)
- **Display Format:** Changes based on:
  - Display mode (Absolute vs. Relative)
  - Time format (Local 12H, Local 24H, UTC)
- **Synchronization:** Based on NTP offset + system time
- **Implementation:**
  ```dart
  final showTimer = !ref.watch(hideTimerProvider);
  
  if (showTimer)
    Text(
      formatTime(ntpService.currentTime),
      style: TextStyle(fontSize: 35, fontFamily: 'Courier New'),
    )
  ```

---

## 5. Custom Buttons Overview

### Predefined Color Options
1. **Default** - Theme primary color
2. **Red** - Red
3. **Green** - Green
4. **Orange** - Orange
5. **Purple** - Purple

### Button Configuration Storage
- **Key in SharedPreferences:** `customButtonModels`
- **Format:** JSON array of ButtonModel objects
- **Persistence:** Saved to SharedPreferences, loaded on app start

### Settings Related to Buttons
1. **Button Location** - Top or Bottom of screen
2. **Button Names** - Manage custom button names
3. **Max Button Rows** - Configure 1-5 rows
4. **Button Colors** - Select color for each button

### Button Locations (Enum)
- `ButtonLocation.top` - Buttons above event list
- `ButtonLocation.bottom` - Buttons below event list (standard)

---

## 6. Overall Architecture & Data Flow

### Data Persistence
```
SharedPreferences (Local Storage)
├── events: List<Event>
├── referenceEvent: Event
├── customButtonModels: List<ButtonModel>
├── customEventNames: List<String>
├── hideRunningTimer: bool
├── buttonSectionLocation: ButtonLocation
├── maxButtonRows: int
├── themeMode: ThemeMode
├── timeFormat: TimeFormat
├── timeServer: TimeServer
├── displayMode: DisplayMode
└── [other settings]
```

### State Management (Riverpod Providers)
- Each setting has a dedicated StateNotifierProvider
- Changes persist to SharedPreferences immediately
- UI rebuilds automatically on state changes
- Reference: `lib/providers/` directory

### NTP Synchronization Flow
1. App starts → NtpService initializes
2. Connects to configured time server
3. Calculates offset, stratum, RTT
4. Stores sync data in SharedPreferences
5. When button pressed → uses `ntpService.currentTime` (system time + offset)
6. Offline fallback → uses cached sync data if network unavailable

### Event Service
```dart
EventService
├── events: List<Event>
├── referenceEvent: Event?
├── addEvent(Event)
├── deleteSelectedEvents(List<bool>)
├── deleteAllEvents()
├── loadData() → SharedPreferences
└── saveData() → SharedPreferences
```

### Main Screen Flow
1. **Init:** Load events, initialize NTP, start timer
2. **Display:** Group events by date, show buttons and running timer
3. **User Actions:**
   - Press button → capture event
   - Tap event → open detail page (edit/delete)
   - Tap running timer → toggle time display mode
   - Edit mode → select events for batch delete
4. **Save:** All changes auto-saved to SharedPreferences

---

## 7. iOS Native Code Status

### Current iOS Implementation
**Location:** `ios/Runner/AppDelegate.swift`
```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Observations
- **No custom native code** - Pure Flutter implementation
- **Standard Flutter app setup** - All functionality is in Dart
- **Plugin-based** - Uses Flutter plugins for native functionality
- **Ready for extension** - Native iOS code can be added via platform channels if needed

---

## 8. Architecture Considerations for Apple Watch Companion App

### Potential Integration Points

1. **Data Sharing**
   - Use App Groups (UserDefaults) for shared storage
   - WatchConnectivity framework for real-time sync
   - CloudKit for sync across devices

2. **Core Features for Watch**
   - Display running timer (simpler than main app)
   - Quick event capture with custom buttons
   - Show last N events
   - Access to reference event for relative time

3. **Technical Approach**
   - Create WatchKit target in iOS project
   - Share Event/ButtonModel as Swift Codable objects
   - Use WatchConnectivity for bidirectional communication
   - App Groups (com.group.dev.gillin.timestamp) for local sync

4. **Data Sync Strategy**
   - Events JSON stored in App Group defaults
   - WatchConnectivity for real-time updates
   - Background app refresh for watch app updates
   - Complication support for quick time display

5. **UI Architecture for Watch**
   - Simplify to essential features only
   - Running timer display (optional, can hide)
   - Quick button tap for events
   - Recent events list view

### Key Files to Modify/Add
- `ios/` - Add WatchKit target
- `lib/` - Add watch communication service
- Platform channels for native iOS ↔ Flutter communication
- Shared data models between platforms

---

## 9. Git History Highlights

Recent relevant commits:
- **14030f7** - Fix Android build
- **357e565, bf29b7c** - Add option to hide main running time (RUNNING TIME feature)
- **03d4b78** - Event Detail add colors
- **22c5116** - Color storage (custom button colors)
- **6b61c9c** - Introduce multirow settings (button rows)

---

## 10. Key Settings & Configuration Keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `timeFormat` | TimeFormat | local24Hour | Display time format |
| `timeServer` | TimeServer | pool.ntp.org | NTP server for sync |
| `autoLockEnable` | bool | false | Allow screen lock |
| `buttonSectionLocation` | ButtonLocation | bottom | Where to show buttons |
| `customEventNames` | List<String> | [] | Custom button names |
| `customButtonModels` | List<ButtonModel> | [] | Buttons with colors |
| `maxButtonRows` | int | 1 | Number of button rows |
| `themeMode` | ThemeMode | system | Light/Dark/System |
| `hideRunningTimer` | bool | false | Hide time display |
| `displayMode` | DisplayMode | absolute | Absolute/Relative time |

---

## Summary

**Timestamp** is a production-ready Flutter app for high-precision event timestamping with NTP synchronization. It features:
- Custom event buttons with colors
- Multiple time display modes (Absolute/Relative)
- Configurable UI layout
- Multi-platform support (iOS/Android/Web)
- Persistent local storage
- Offline-capable with NTP caching

The architecture is clean, modular, and well-suited for expansion to a WatchKit companion app with proper data sharing mechanisms.

