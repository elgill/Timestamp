import Foundation
import WatchConnectivity
import Flutter

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private var methodChannel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func setup(withChannel channel: FlutterMethodChannel) {
        self.methodChannel = channel

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("WatchConnectivity: Session activated")
        }
    }

    // MARK: - Send data to Watch
    func sendButtonsToWatch(buttons: [[String: Any]]) {
        guard WCSession.default.isReachable else {
            print("WatchConnectivity: Watch is not reachable")
            return
        }

        let message: [String: Any] = ["buttons": buttons]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivity: Error sending buttons - \(error.localizedDescription)")
        }
    }

    func sendCurrentTimeToWatch(time: String, isAbsolute: Bool) {
        guard WCSession.default.isReachable else { return }

        let message: [String: Any] = [
            "currentTime": time,
            "isAbsolute": isAbsolute
        ]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivity: Error sending time - \(error.localizedDescription)")
        }
    }

    func updateApplicationContext(buttons: [[String: Any]], settings: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        let context: [String: Any] = [
            "buttons": buttons,
            "settings": settings,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("WatchConnectivity: Application context updated")
        } catch {
            print("WatchConnectivity: Error updating context - \(error.localizedDescription)")
        }
    }

    // MARK: - Receive data from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("WatchConnectivity: Received message from Watch - \(message)")

        if let action = message["action"] as? String {
            switch action {
            case "captureEvent":
                if let buttonName = message["buttonName"] as? String,
                   let color = message["color"] as? String {
                    // Send event to Flutter
                    methodChannel?.invokeMethod("captureEventFromWatch", arguments: [
                        "buttonName": buttonName,
                        "color": color
                    ])

                    replyHandler(["success": true])
                }
            case "requestButtons":
                // Request buttons from Flutter
                methodChannel?.invokeMethod("getButtons", arguments: nil, result: { result in
                    if let buttons = result as? [[String: Any]] {
                        replyHandler(["buttons": buttons])
                    } else {
                        replyHandler(["buttons": []])
                    }
                })
            case "requestCurrentTime":
                // Request current time from Flutter
                methodChannel?.invokeMethod("getCurrentTime", arguments: nil, result: { result in
                    if let timeData = result as? [String: Any] {
                        replyHandler(timeData)
                    } else {
                        replyHandler(["error": "Failed to get time"])
                    }
                })
            default:
                replyHandler(["error": "Unknown action"])
            }
        } else {
            replyHandler(["error": "No action specified"])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("WatchConnectivity: Received message (no reply) - \(message)")
    }

    // MARK: - WCSessionDelegate required methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchConnectivity: Activation failed - \(error.localizedDescription)")
        } else {
            print("WatchConnectivity: Activation completed with state: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivity: Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WatchConnectivity: Session deactivated, reactivating...")
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WatchConnectivity: Reachability changed - isReachable: \(session.isReachable)")
    }
}
