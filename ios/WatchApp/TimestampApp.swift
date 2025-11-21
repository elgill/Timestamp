import SwiftUI

@main
struct TimestampWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
