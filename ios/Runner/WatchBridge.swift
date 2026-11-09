import Flutter
import Foundation
import WatchConnectivity

/// Connects the watch app to the Flutter side (lib/services/watch_sync_service.dart).
///
/// Changes from the watch can arrive while Flutter isn't running, so they
/// are kept in an inbox in UserDefaults until Flutter has saved them and
/// clears them. Flutter's events are never written from here: EventService
/// keeps them in memory and saves the whole list, which would overwrite them.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private static let channelName = "dev.gillin.timestamp/watch"
    private static let inboxKey = "watchInbox"
    private static let lastSequenceKey = "watchInboxLastSequence"

    private let defaults = UserDefaults.standard
    /// Every inbox read and write goes through here, since watch deliveries
    /// arrive on a background queue.
    private let inboxQueue = DispatchQueue(label: "dev.gillin.timestamp.watch-inbox")
    private var channel: FlutterMethodChannel?
    /// The latest context from Flutter, kept to send once the session is up.
    private var pendingContext: String?

    /// Call at launch, so changes the watch sent while the app was closed
    /// are delivered.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func attach(to messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        self.channel = channel
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "readInbox":
            inboxQueue.async {
                let inbox = self.inbox
                DispatchQueue.main.async { result(inbox) }
            }
        case "clearInbox":
            guard let upTo = arguments?["upTo"] as? Int else {
                return result(FlutterError(code: "bad-arguments", message: "upTo missing", details: nil))
            }
            inboxQueue.async {
                self.inbox = self.inbox.filter { ($0["sequence"] as? Int ?? 0) > upTo }
                DispatchQueue.main.async { result(nil) }
            }
        case "updateContext":
            guard let json = arguments?["json"] as? String else {
                return result(FlutterError(code: "bad-arguments", message: "json missing", details: nil))
            }
            pendingContext = json
            sendPendingContext()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func sendPendingContext() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let json = pendingContext
        else { return }
        do {
            try session.updateApplicationContext(["json": json])
            pendingContext = nil
        } catch {
            // Kept, to try again when the session next activates.
            print("Sending context to the watch failed: \(error)")
        }
    }

    /// Changes waiting for Flutter, oldest first: `sequence` and `json`.
    private var inbox: [[String: Any]] {
        get { defaults.array(forKey: Self.inboxKey) as? [[String: Any]] ?? [] }
        set { defaults.set(newValue, forKey: Self.inboxKey) }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let json = userInfo["json"] as? String else { return }
        inboxQueue.async {
            let sequence = self.defaults.integer(forKey: Self.lastSequenceKey) + 1
            self.defaults.set(sequence, forKey: Self.lastSequenceKey)
            self.inbox.append(["sequence": sequence, "json": json])
            DispatchQueue.main.async {
                self.channel?.invokeMethod("inboxChanged", arguments: nil)
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { self.sendPendingContext() }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // The watch app may just have been installed.
        DispatchQueue.main.async { self.sendPendingContext() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched watches; start a session with the new one.
        session.activate()
    }
}
