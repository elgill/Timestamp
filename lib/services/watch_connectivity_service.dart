import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/button_model.dart';
import '../models/event.dart';
import '../enums/predefined_colors.dart';
import '../providers/custom_button_models_provider.dart';
import '../providers/display_mode_provider.dart';
import 'event_service.dart';
import 'ntp_service.dart';

class WatchConnectivityService {
  static const platform = MethodChannel('com.timestamp.watch');
  final Ref ref;

  WatchConnectivityService(this.ref) {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    if (!Platform.isIOS) return;

    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'captureEventFromWatch':
          return await _handleCaptureEventFromWatch(call.arguments);
        case 'getButtons':
          return await _handleGetButtons();
        case 'getCurrentTime':
          return await _handleGetCurrentTime();
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Method ${call.method} not implemented',
          );
      }
    });
  }

  Future<void> _handleCaptureEventFromWatch(dynamic arguments) async {
    try {
      final args = arguments as Map<dynamic, dynamic>;
      final buttonName = args['buttonName'] as String;
      final colorString = args['color'] as String;

      // Get the NTP service
      final ntpService = ref.read(ntpServiceProvider);

      // Get the current NTP-synchronized time
      final currentTime = ntpService.currentTime;
      final precision = (ntpService.roundTripTime / 2).round();

      // Map color string to PredefinedColor enum
      PredefinedColor buttonColor;
      switch (colorString.toLowerCase()) {
        case 'red':
          buttonColor = PredefinedColor.red;
          break;
        case 'green':
          buttonColor = PredefinedColor.green;
          break;
        case 'orange':
          buttonColor = PredefinedColor.orange;
          break;
        case 'purple':
          buttonColor = PredefinedColor.purple;
          break;
        default:
          buttonColor = PredefinedColor.defaultColor;
      }

      // Create the event
      final event = Event(
        timestamp: currentTime,
        precision: precision,
        description: buttonName,
        color: buttonColor,
      );

      // Save the event
      final eventService = ref.read(eventServiceProvider);
      eventService.addEvent(event);

      print('Watch event captured: $buttonName at ${currentTime.toIso8601String()}');
    } catch (e) {
      print('Error capturing event from watch: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _handleGetButtons() async {
    try {
      final buttons = ref.read(customButtonModelsProvider);

      return buttons.map((button) {
        return {
          'id': button.name, // Use name as ID for simplicity
          'name': button.name,
          'color': _buttonColorToString(button.predefinedColor),
        };
      }).toList();
    } catch (e) {
      print('Error getting buttons: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _handleGetCurrentTime() async {
    try {
      final ntpService = ref.read(ntpServiceProvider);
      final currentTime = ntpService.currentTime;
      final isAbsolute = ref.read(displayModeProvider) == DisplayMode.absolute;

      String formattedTime;
      if (isAbsolute) {
        // Format as time of day (HH:mm:ss)
        formattedTime = _formatTimeOfDay(currentTime);
      } else {
        // Format as running time (relative to reference)
        final eventService = ref.read(eventServiceProvider);
        if (eventService.referenceEvent != null) {
          final difference = currentTime.difference(eventService.referenceEvent!.timestamp);
          formattedTime = _formatDuration(difference);
        } else {
          formattedTime = '00:00:00';
        }
      }

      return {
        'currentTime': formattedTime,
        'isAbsolute': isAbsolute,
      };
    } catch (e) {
      print('Error getting current time: $e');
      return {
        'currentTime': '--:--:--',
        'isAbsolute': true,
      };
    }
  }

  String _formatTimeOfDay(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.abs().toString().padLeft(2, '0');
    final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds.abs() % 60).toString().padLeft(2, '0');
    final sign = duration.isNegative ? '-' : '';
    return '$sign$hours:$minutes:$seconds';
  }

  String _buttonColorToString(PredefinedColor color) {
    switch (color) {
      case PredefinedColor.red:
        return 'Red';
      case PredefinedColor.green:
        return 'Green';
      case PredefinedColor.orange:
        return 'Orange';
      case PredefinedColor.purple:
        return 'Purple';
      case PredefinedColor.defaultColor:
        return 'Default';
    }
  }

  Future<void> sendToWatch({
    required List<ButtonModel> buttons,
    Map<String, dynamic>? settings,
  }) async {
    if (!Platform.isIOS) return;

    try {
      final buttonsList = buttons.map((button) {
        return {
          'id': button.name,
          'name': button.name,
          'color': _buttonColorToString(button.predefinedColor),
        };
      }).toList();

      await platform.invokeMethod('sendToWatch', {
        'buttons': buttonsList,
        'settings': settings ?? {},
      });

      print('Sent ${buttons.length} buttons to Watch');
    } catch (e) {
      print('Error sending data to watch: $e');
    }
  }
}

// Provider for watch connectivity service
final watchConnectivityServiceProvider = Provider<WatchConnectivityService>((ref) {
  return WatchConnectivityService(ref);
});
