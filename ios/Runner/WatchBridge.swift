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
    /// What the complications showed when last sent to them.
    private static let complicationKey = "watchComplicationSent"

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
            updateContext(json: json)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Sends Flutter's latest context to the watch.
    func updateContext(json: String) {
        pendingContext = json
        sendPendingContext()
        shareButtons(fromContext: json)
    }

    /// Keeps the buttons from Flutter's context for `RecordEventIntent`,
    /// which can run while Flutter isn't.
    private func shareButtons(fromContext json: String) {
        struct Context: Decodable {
            var buttons: [Lossy<RecordButtonConfig>]
        }
        guard let context = try? JSONDecoder().decode(Context.self, from: Data(json.utf8)) else { return }
        let buttons = context.buttons.compactMap(\.value)
        guard buttons != SharedButtons.load() else { return }
        SharedButtons.save(buttons)
        if #available(iOS 16.0, *) {
            // So Siri knows the button names its phrases can include.
            TimestampShortcuts.updateAppShortcutParameters()
        }
    }

    private func sendPendingContext() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let json = pendingContext
        else { return }
        // So the watch can tell which of two copies is newer.
        let payload: [String: Any] = ["json": json, "sentAt": Date().timeIntervalSince1970]
        do {
            try session.updateApplicationContext(payload)
            pendingContext = nil
            sendToComplications(payload, json: json, session: session)
        } catch {
            // Kept, to try again when the session next activates.
            print("Sending context to the watch failed: \(error)")
        }
    }

    /// Sends the context again in the way the watch delivers soonest, waking
    /// its app to update the complications, but only when what they show has
    /// changed: a complication on the face gets only 50 of these a day. The
    /// context alone arrives when the watch next runs the app, which can be
    /// a long while.
    private func sendToComplications(_ payload: [String: Any], json: String, session: WCSession) {
        guard session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0,
              let shown = Self.complicationsShow(json),
              shown != defaults.string(forKey: Self.complicationKey)
        else { return }
        session.transferCurrentComplicationUserInfo(payload)
        defaults.set(shown, forKey: Self.complicationKey)
    }

    /// What of a context the watch's complications show, as a string to
    /// compare: the reference, the latest event and the time format.
    static func complicationsShow(_ json: String) -> String? {
        struct Context: Decodable {
            var events: [Lossy<WatchEvent>]?
            var reference: WatchEvent?
            var timeFormat: Int?
        }
        struct Shown: Encodable {
            var reference: WatchEvent?
            var latest: WatchEvent?
            var timeFormat: Int?
        }
        guard let context = try? WatchJSON.decoder.decode(Context.self, from: Data(json.utf8)) else { return nil }
        let latest = context.events?.compactMap(\.value).max { $0.time < $1.time }
        let shown = Shown(reference: context.reference, latest: latest, timeFormat: context.timeFormat)
        return (try? comparableEncoder.encode(shown)).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Writes the same text for the same content every time, which
    /// JSONEncoder only does with its keys sorted.
    private static let comparableEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    /// Changes waiting for Flutter, oldest first: `sequence` and `json`.
    private var inbox: [[String: Any]] {
        get { defaults.array(forKey: Self.inboxKey) as? [[String: Any]] ?? [] }
        set { defaults.set(newValue, forKey: Self.inboxKey) }
    }

    // MARK: WCSessionDelegate

    /// Changes the watch queued to arrive even if this app wasn't running.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    /// The same changes, sent straight here while the watch could reach the
    /// phone. Usually arrives first; Flutter ignores the second copy.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    private func receive(_ payload: [String: Any]) {
        guard let json = payload["json"] as? String else { return }
        deliver(json: json)
    }

    /// Puts changes in the inbox, in the watch's format, for Flutter to
    /// take in. Also how the phone's own Record Event intent records.
    func deliver(json: String) {
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
