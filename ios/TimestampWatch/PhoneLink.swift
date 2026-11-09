import Foundation
import WatchConnectivity

/// Connects to the phone app (ios/Runner/WatchBridge.swift on the other
/// side). Sends the events recorded and deleted here, and takes in the
/// phone's events, buttons and time format.
final class PhoneLink: NSObject, WCSessionDelegate {
    private let store: EventStore
    private let settings: WatchSettings
    /// Changes made before the session was ready to send them.
    private var unsent: [WatchChanges] = []

    init(store: EventStore, settings: WatchSettings) {
        self.store = store
        self.settings = settings
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Queues changes for the phone. They're delivered in order, even if the
    /// phone app isn't running or the phone is out of reach.
    func send(added: [WatchEvent] = [], deleted: [String] = []) {
        guard !added.isEmpty || !deleted.isEmpty else { return }
        unsent.append(WatchChanges(added: added, deleted: deleted))
        flush()
    }

    private func flush() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        for changes in unsent {
            do {
                WCSession.default.transferUserInfo(["json": try changes.json()])
            } catch {
                print("Encoding changes for the phone failed: \(error)")
            }
        }
        unsent.removeAll()
    }

    /// Applies a context from the phone, if it has one.
    func apply(_ applicationContext: [String: Any]) {
        guard let json = applicationContext["json"] as? String else { return }
        do {
            let context = try PhoneContext.decode(json: json)
            store.apply(context)
            settings.buttons = context.buttons
            settings.timeFormat = context.timeFormat
        } catch {
            print("Reading what the phone sent failed: \(error)")
        }
    }

    // MARK: WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        DispatchQueue.main.async {
            self.flush()
            // What the phone sent while the app was closed.
            self.apply(context)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }
}
