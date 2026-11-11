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
    func send(added: [WatchEvent] = [], deleted: [String] = [], reference: ReferenceChoice? = nil) {
        guard !added.isEmpty || !deleted.isEmpty || reference != nil else { return }
        unsent.append(WatchChanges(added: added, deleted: deleted, reference: reference))
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        for changes in unsent {
            let payload: [String: Any]
            do {
                payload = ["json": try changes.json()]
            } catch {
                print("Encoding changes for the phone failed: \(error)")
                continue
            }
            // Delivered even if the phone app isn't running, but the system
            // can hold it back for minutes.
            session.transferUserInfo(payload)
            // Straight to the phone app, waking it if needed, when the phone
            // is in reach. The phone ignores whichever copy arrives second.
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { error in
                    print("Sending changes to the phone failed: \(error)")
                }
            }
        }
        unsent.removeAll()
    }

    /// Sends again the events recorded here that the phone hasn't confirmed,
    /// in case a delivery was lost. The phone ignores ones it already has.
    private func resendUnconfirmed() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isReachable else { return }
        let unconfirmed = store.unconfirmed
        guard !unconfirmed.isEmpty else { return }
        do {
            let json = try WatchChanges(added: unconfirmed).json()
            session.sendMessage(["json": json], replyHandler: nil) { error in
                print("Resending events to the phone failed: \(error)")
            }
        } catch {
            print("Encoding events for the phone failed: \(error)")
        }
    }

    /// Applies a context from the phone, if it has one.
    func apply(_ applicationContext: [String: Any]) {
        guard let json = applicationContext["json"] as? String else { return }
        do {
            let context = try PhoneContext.decode(json: json)
            store.apply(context)
            settings.buttons = context.buttons
            settings.timeFormat = context.timeFormat
            if settings.phoneAccuracy != context.accuracy {
                settings.phoneAccuracy = context.accuracy
            }
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
            self.resendUnconfirmed()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.resendUnconfirmed() }
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error {
            print("Delivering changes to the phone failed: \(error)")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }
}
