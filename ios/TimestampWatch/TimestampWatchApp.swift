import SwiftUI

@main
struct TimestampWatchApp: App {
    @State private var store = EventStore()
    @State private var settings = WatchSettings()
    private let timeSource: TimeSource = SystemClock()

    var body: some Scene {
        WindowGroup {
            TabView {
                RecordView(timeSource: timeSource)
                EventsView()
            }
            .tabViewStyle(.verticalPage)
            .environment(store)
            .environment(settings)
        }
    }
}
