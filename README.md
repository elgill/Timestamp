
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

## Support

For bugs, feature requests, or further assistance, please open an issue in this repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
