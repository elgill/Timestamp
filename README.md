
# Precise Timestamp App

## Overview

**Precise Timestamp** is a Flutter-based application designed to provide high-precision timekeeping by capturing the exact time of events down to the tenth of a second. Utilizing Network Time Protocol (NTP) for synchronization with time servers, it offers unparalleled accuracy and is available for both [iOS](https://apps.apple.com/us/app/precise-timestamp/id6463294734) and [Android](https://play.google.com/store/apps/details?id=dev.gillin.timestamp) platforms.

## Features

-   **NTP Synchronization**: Ensures high-precision timekeeping by syncing with NTP servers.
-   **Dynamic Display Modes**: Offers Absolute and Relative time displays, along with organized event grouping.
-   **Seamless Event Management**: Facilitates easy event editing and deletion through a user-friendly interface.
-   **Custom Event Buttons**: Specify custom button names to allow multiple buttons which will automatically name the event.

## Getting Started

### Prerequisites

-   Flutter (latest version recommended)
-   Dart (latest version recommended)
-   For iOS: Xcode (latest version recommended)
-   For Android: Android Studio (latest version recommended)

### Setup

1.  **Clone the Repository**
    
    `git clone https://github.com/elgill/Timestamp.git` 
    
2.  **Navigate to the Project Directory**
    
    `cd Timestamp` 
    
3.  **Install Dependencies**
    
    `flutter pub get` 
    

### Running the App

-   **iOS**
    `open -a Simulator
    flutter run` 
    
-   **Android**
    `flutter run` 
    
## Testing

-   **Run the test suite**
    `flutter test`

    Includes layout tests that render the main screen on simulated devices
    (iPhone 15 Pro portrait/landscape, iPhone SE landscape, iPad) and check
    that every record button is on screen, inside the safe area and tappable.

-   **Render device screenshots**
    `flutter test test/screenshot_test.dart --dart-define=SCREENSHOTS=true`

    Writes PNGs to `build/screenshots/`. CI uploads these as the
    `device-screenshots` artifact on every push.

## Apple Watch app

A native SwiftUI app in `ios/TimestampWatch`, embedded in the iOS app. It
records events on its own and syncs with the phone through WatchConnectivity:
`ios/Runner/WatchBridge.swift` on the phone side and
`lib/services/watch_sync_service.dart` on the Flutter side.

-   **Run its tests**
    `xcodebuild test -workspace ios/Runner.xcworkspace -scheme TimestampWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`

-   **Message format**: `test/fixtures/watch` holds an example of each message.
    The Dart and Swift tests both check against them.

-   **Simulator builds**: `flutter build ios --simulator` needs a device
    (`-d <udid>`) now that the app has a watch companion.

-   **Testing on simulators**: run the phone app with `flutter run`, and install
    the watch app after the phone app, so the phone sees it as installed. The
    watch sends each change twice: as a message while the phone is in reach,
    and as a `transferUserInfo` backup that the system may hold for minutes.
    On simulators only the message arrives, so keep the phone app open.

## App Store screenshots

`dart run tool/store_screenshots.dart`

Runs the real app on iOS simulators with demo data and a frozen clock, and
writes upload-ready PNGs to `build/store_screenshots/<device>/`:

| Folder | Device | Size | Display class in App Store Connect |
| --- | --- | --- | --- |
| `iphone-69` | iPhone 18 Pro Max | 1320 x 2868 | iPhone with Dynamic Island (large) |
| `iphone-63` | iPhone 18 Pro | 1206 x 2622 | iPhone with Dynamic Island (medium) |
| `ipad-13` | iPad Pro 13-inch | 2064 x 2752 | iPad 13" |
| `duo-outer` | iPhone Duo, closed | 1398 x 2034 | iPhone Duo (outer display) |
| `duo-inner` | iPhone Duo, open | 2853 x 2007 | iPhone Duo (inner display) |

-   Pass folder names to capture only those devices.
-   `duo-inner` needs [duoctl](https://github.com/skarol/duoctl) to unfold the
    simulator: `brew install skarol/tap/duoctl`.
-   The tool creates its own `Store Screenshots ...` simulators, so your other
    simulators and their data are left alone.
-   Edit scenes and demo data in `test_driver/store_screenshots.dart`. Sizes
    are checked against the list in `tool/store_screenshots.dart`; compare it
    with [Apple's specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
    when new devices ship.

## Support

For bugs, feature requests, or further assistance, please open an issue in this repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
