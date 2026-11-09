import SwiftUI

@main
struct TimestampWatchApp: App {
    @State private var store: EventStore
    @State private var settings: WatchSettings
    private let link: PhoneLink
    private let timeSource: TimeSource

    init() {
        let store = EventStore()
        let settings = WatchSettings()
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        timeSource = WatchClock(settings: settings)
        link = PhoneLink(store: store, settings: settings)
        link.activate()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                RecordView(timeSource: timeSource, link: link)
                EventsView(link: link)
            }
            .tabViewStyle(.verticalPage)
            .environment(store)
            .environment(settings)
        }
    }
}
