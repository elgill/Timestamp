import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityProvider: NSObject, ObservableObject {
    @Published var currentTime: String = "--:--:--"
    @Published var isAbsoluteTime: Bool = true
    @Published var buttons: [ButtonModel] = []
    @Published var isConnected: Bool = false

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }

        // Request initial data
        requestButtons()
        startTimeUpdates()
    }

    func requestButtons() {
        guard let session = session, session.isReachable else {
            print("Watch: Session not reachable")
            return
        }

        let message: [String: Any] = ["action": "requestButtons"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            if let buttonsData = reply["buttons"] as? [[String: Any]] {
                DispatchQueue.main.async {
                    self?.buttons = buttonsData.compactMap { ButtonModel.from(dict: $0) }
                }
            }
        }) { error in
            print("Watch: Error requesting buttons - \(error.localizedDescription)")
        }
    }

    func requestCurrentTime() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = ["action": "requestCurrentTime"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let time = reply["currentTime"] as? String {
                    self?.currentTime = time
                }
                if let isAbsolute = reply["isAbsolute"] as? Bool {
                    self?.isAbsoluteTime = isAbsolute
                }
            }
        }) { error in
            print("Watch: Error requesting time - \(error.localizedDescription)")
        }
    }

    func captureEvent(buttonName: String, color: String, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.isReachable else {
            completion(false)
            return
        }

        let message: [String: Any] = [
            "action": "captureEvent",
            "buttonName": buttonName,
            "color": color
        ]

        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                completion(reply["success"] as? Bool ?? false)
            }
        }) { error in
            print("Watch: Error capturing event - \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    private func startTimeUpdates() {
        // Update time every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.requestCurrentTime()
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityProvider: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }

        if let error = error {
            print("Watch: Activation failed - \(error.localizedDescription)")
        } else {
            print("Watch: Activation completed")
            requestButtons()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Watch: Received application context")

        if let buttonsData = applicationContext["buttons"] as? [[String: Any]] {
            DispatchQueue.main.async {
                self.buttons = buttonsData.compactMap { ButtonModel.from(dict: $0) }
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Watch: Received message - \(message)")

        if let time = message["currentTime"] as? String {
            DispatchQueue.main.async {
                self.currentTime = time
            }
        }

        if let isAbsolute = message["isAbsolute"] as? Bool {
            DispatchQueue.main.async {
                self.isAbsoluteTime = isAbsolute
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
}
