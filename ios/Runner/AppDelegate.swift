import UIKit
import Flutter
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup Watch Connectivity
    let controller = window?.rootViewController as! FlutterViewController
    let watchChannel = FlutterMethodChannel(
      name: "com.timestamp.watch",
      binaryMessenger: controller.binaryMessenger
    )

    WatchConnectivityManager.shared.setup(withChannel: watchChannel)

    watchChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "sendToWatch" else {
        result(FlutterMethodNotImplemented)
        return
      }

      if let args = call.arguments as? [String: Any] {
        if let buttons = args["buttons"] as? [[String: Any]] {
          WatchConnectivityManager.shared.updateApplicationContext(
            buttons: buttons,
            settings: args["settings"] as? [String: Any] ?? [:]
          )
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      } else {
        result(FlutterError(code: "NO_ARGS", message: "No arguments provided", details: nil))
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
