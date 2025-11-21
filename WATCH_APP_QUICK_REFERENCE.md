# TIMESTAMP APP - QUICK REFERENCE ANSWERS

## Your 6 Questions Answered

### 1. What type of app is this?
**Flutter multi-platform mobile application** 
- Supported platforms: iOS, Android, macOS, Windows, Linux, Web
- Version: 1.1.2 (Build 32)
- Language: Dart
- State Management: Flutter Riverpod
- Storage: SharedPreferences (SQLite on iOS)

### 2. What is the current app structure and main features?
**Architecture Layers:**
```
UI Layer (Flutter Widgets)
    ↓
State Management (Riverpod Providers) 
    ↓
Services (EventService, NtpService, ShareService)
    ↓
Models (Event, ButtonModel)
    ↓
Persistence (SharedPreferences)
```

**Main Features:**
- High-precision event timestamping (down to 1ms via NTP)
- NTP synchronization with 5 selectable time servers
- Custom button creation with names and colors
- Two time display modes: Absolute (TOD) and Relative
- Event management (create, edit, delete, group by date)
- Settings for display, theme, time format, button layout
- Reference event support for relative time calculations
- Event sharing and export functionality
- Screen lock control (wakelock)
- Cross-platform support

### 3. How are events/buttons currently implemented?

**BUTTON IMPLEMENTATION:**
- Location: `lib/main_screen.dart` lines 576-620
- Each custom button corresponds to a ButtonModel
- Button names stored in `customButtonNamesProvider`
- Button colors stored in `customButtonModelsProvider`
- Dynamically created in rows based on `maxButtonRowsProvider`
- Can be positioned at top or bottom of screen

**EVENT CAPTURE ON BUTTON PRESS:**
```dart
// When button pressed (line 592):
DateTime now = ntpService.currentTime;        // Get synchronized time
int precision = ntpService.roundTripTime ~/2; // Calculate precision
Event event = Event(
  now,
  precision,
  description: buttonName ?? '',  // Auto-labeled from button
  color: predefinedColor,         // Button's color
);
eventManager.addEvent(event);     // Save to SharedPreferences
```

**BUTTON STORAGE:**
- Key in SharedPreferences: `customButtonModels`
- Format: JSON array of ButtonModel objects
- Each model has: name (String), predefinedColor (enum)

### 4. What do "TOD" and "running time" refer to?

**TOD = "Time Of Day" (Absolute Time Display)**
- Shows actual wall-clock time (e.g., 2:45:30 PM)
- Opposite mode: Relative time (e.g., +0:02:15)
- Setting: Display Mode (Absolute/Relative)
- User can toggle by tapping the running timer
- Implemented in: `display_mode_provider.dart`

**RUNNING TIME = Live Time Display at Top of Screen**
- Always shows current NTP-synchronized time in large text
- Updates continuously (timer every 10ms)
- Can be hidden: Settings → Display Settings → "Hide Running Timer"
- Toggles between Absolute (TOD) and Relative time display
- Synchronized via `ntpService.currentTime` 
- Formatting based on time format setting
- Implementation: `main_screen.dart` lines 451-471

**Toggle Method:**
```dart
// Tap the running timer to toggle between TOD and relative:
GestureDetector(
  onTap: () => toggleDisplayMode(), // Switch Absolute ↔ Relative
  child: Text(formatTime(ntpService.currentTime)) // Display current
)
```

### 5. What custom buttons exist?

**Button System Architecture:**
- **Default Button:** Arrow-down icon when no custom buttons exist
- **Custom Buttons:** User-created via Settings → Manage Button Names
- **Maximum:** No hard limit, but UI constrains with row layout
- **Default Configurations:** None - starts empty

**Button Properties:**
```dart
class ButtonModel {
  String name;                      // e.g., "Start", "Stop", "Lap"
  PredefinedColor predefinedColor;  // Color: Default, Red, Green, Orange, Purple
}
```

**Button Organization:**
- Location: Top or Bottom of screen (configurable)
- Rows: 1-5 configurable rows for layout
- Even distribution across rows
- Each button displays name or color indicator

**Current App (no custom buttons pre-loaded):**
- Shows single default arrow-down button
- Users create custom buttons in Settings
- Example workflow:
  1. Settings → Manage Button Names
  2. Add buttons: "Start", "Stop", "Lap"
  3. Each button can have custom color
  4. Buttons now appear in main screen
  5. Tap button → event created with description

### 6. What is the overall architecture?

```
┌─────────────────────────────────────────────────────────┐
│ TIMESTAMP APP - ARCHITECTURE OVERVIEW                   │
└─────────────────────────────────────────────────────────┘

PRESENTATION LAYER (Flutter UI)
├── MainScreen (main_screen.dart)
│   ├── Running Timer Display (formatted time)
│   ├── Event Button Section (custom buttons)
│   ├── Event List (grouped by date)
│   └── Bottom Bar (controls)
│
├── Settings Screens (settings_elements/)
│   ├── Time Format Selection
│   ├── Time Display Mode (Absolute/Relative)
│   ├── Button Management
│   ├── Theme Selection
│   └── ...
│
└── Detail Pages (pages/)
    └── Event Detail (edit description, color)

STATE MANAGEMENT LAYER (Riverpod Providers)
├── Configuration Providers
│   ├── timeFormatProvider          → Display format (12/24/UTC)
│   ├── displayModeProvider         → Absolute/Relative toggle
│   ├── hideTimerProvider           → Show/hide running time
│   ├── customButtonNamesProvider   → Button names list
│   ├── customButtonModelsProvider  → Button models with colors
│   ├── themeModeProvider           → Light/Dark/System
│   ├── buttonLocationProvider      → Top/Bottom position
│   ├── maxButtonRowsProvider       → 1-5 rows
│   └── ...more providers
│
└── Service Providers
    ├── ntpServiceProvider          → Time synchronization
    ├── eventServiceProvider        → Event management
    └── sharedUtilityProvider       → Settings wrapper

SERVICES LAYER (Business Logic)
├── NtpService
│   ├── updateNtpOffset()           → Fetch from NTP server
│   ├── currentTime (getter)        → System time + offset
│   ├── Caches sync data to device
│   └── Offline fallback support
│
├── EventService
│   ├── events: List<Event>
│   ├── referenceEvent: Event?
│   ├── addEvent(Event)
│   ├── deleteSelectedEvents()
│   ├── saveData()                  → SharedPreferences
│   └── loadData()                  ← SharedPreferences
│
├── ShareService                    → Share events via other apps
└── ExportService                   → Export events (CSV/JSON)

DATA MODELS
├── Event
│   ├── time: DateTime              → Exact moment of capture
│   ├── precision: int              → Milliseconds (RTT/2)
│   ├── description: String         → Button name or custom text
│   └── color: PredefinedColor      → Visual indicator (5 colors)
│
└── ButtonModel
    ├── name: String                → Display label
    └── predefinedColor: enum       → Color identifier

PERSISTENCE LAYER (SharedPreferences)
├── events                          → List<Event> as JSON
├── referenceEvent                  → Event as JSON (optional)
├── customButtonModels              → List<ButtonModel> as JSON
├── customEventNames                → List<String>
├── timeFormat                      → TimeFormat enum value
├── displayMode                     → "absolute" or "relative"
├── hideRunningTimer                → boolean
├── buttonSectionLocation           → "top" or "bottom"
├── maxButtonRows                   → integer (1-5)
├── themeMode                       → "light", "dark", or "system"
├── timeServer                      → NTP server name
├── ntpOffset                       → milliseconds (cached)
├── lastSyncTime                    → ISO 8601 timestamp
└── ...more settings

PLATFORM-SPECIFIC LAYER
├── iOS (ios/Runner/)
│   └── AppDelegate.swift           → Standard Flutter setup only
│
└── Android, macOS, Windows, Linux, Web
    └── Standard Flutter platforms


DATA FLOW: Button Press to Event Storage
═════════════════════════════════════════

1. User taps button in MainScreen
   ↓
2. _buildRecordEventButton() onPressed handler fires
   ↓
3. Get current NTP time: ntpService.currentTime
   ↓
4. Calculate precision: ntpService.roundTripTime / 2
   ↓
5. Create Event(time, precision, description, color)
   ↓
6. Call eventManager.addEvent(event)
   ↓
7. EventService sets referenceEvent if first event
   ↓
8. Sort events by time (descending)
   ↓
9. Save to SharedPreferences via eventManager.saveData()
   ↓
10. UI rebuilds, event appears in list
    ↓
11. Provide user feedback (haptic + sound)


TIME SYNCHRONIZATION FLOW
═════════════════════════

1. App launches → NtpService initializes
   ↓
2. updateNtpOffset() called automatically
   ↓
3. Connect to selected NTP server (pool.ntp.org default)
   ↓
4. Calculate:
   - NTP offset (clock difference in ms)
   - Round Trip Time (network latency)
   - NTP Stratum (server hierarchy level)
   - Last sync time
   ↓
5. Cache to SharedPreferences:
   - ntpOffset
   - lastSyncTime
   ↓
6. When button pressed → use: System.now() + ntpOffset
   ↓
7. If offline → use cached offset
   ↓
8. Display: NTP Details dialog shows sync status


SETTINGS SYNCHRONIZATION
═════════════════════════

Each Riverpod Provider watches SharedPreferences changes:

Setting Change → Provider State Update → UI Rebuild

Example:
User toggles "Hide Running Timer"
  ↓
hideTimerProvider.setHideTimer(true)
  ↓
Saves to SharedPreferences: hideRunningTimer = true
  ↓
MainScreen watches hideTimerProvider
  ↓
showTimer variable becomes false
  ↓
Timer display widget conditionally removed
  ↓
UI rebuilds


KEY DESIGN PATTERNS
═══════════════════

1. **Service Pattern** - EventService, NtpService encapsulate logic
2. **Provider Pattern** - Riverpod for reactive state management
3. **Model Pattern** - Event, ButtonModel for type safety
4. **Enum Pattern** - DisplayMode, TimeFormat for constraints
5. **Separation of Concerns** - UI, State, Services, Models layers
6. **Reactive UI** - Flutter widgets rebuild on provider changes
7. **Persistent State** - SharedPreferences backed providers


WATCH APP INTEGRATION CONSIDERATIONS
════════════════════════════════════

To build an Apple Watch companion app:

1. **Data Access Points:**
   - Events: `eventManager.events` from EventService
   - Buttons: `customButtonModelsProvider` (Riverpod)
   - Settings: All providers in `lib/providers/`
   - Time: `ntpService.currentTime`

2. **Shared Storage:**
   - Use App Groups UserDefaults (same key space)
   - Or WatchConnectivity for real-time sync

3. **Key Models to Share:**
   - Event (convert to Swift Codable)
   - ButtonModel (convert to Swift struct)

4. **Core Features:**
   - Display running timer (simplified)
   - Capture events with custom buttons
   - Show recent events
   - Optional NTP sync on watch

5. **Communication:**
   - Platform channels for native iOS ↔ Flutter
   - WatchConnectivity for watch sync
   - App Groups for shared data
