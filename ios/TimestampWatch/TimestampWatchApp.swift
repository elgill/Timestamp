import SwiftUI

@main
struct TimestampWatchApp: App {
    @State private var store: EventStore
    @State private var settings: WatchSettings
    @State private var recorder: Recorder
    private let link: PhoneLink
    private let timeSource: TimeSource

    init() {
        let store = EventStore()
        let settings = WatchSettings()
        let link = PhoneLink(store: store, settings: settings)
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        let recorder = Recorder(store: store, link: link)
        let timeSource = WatchClock(settings: settings)
        _recorder = State(initialValue: recorder)
        self.timeSource = timeSource
        self.link = link
        link.activate()
        IntentRecorder.recorder = recorder
        IntentRecorder.settings = settings
    }

    var body: some Scene {
        WindowGroup {
            // One navigation stack around all the pages, as watchOS expects;
            // each page adds its own toolbar items.
            NavigationStack {
                // Pages of buttons that each fit on the screen, then the
                // events, which scroll and so come last. The Digital Crown
                // moves a page at a time.
                TabView {
                    ForEach(Array(ButtonLayout.pages(settings.buttons).enumerated()), id: \.offset) { _, page in
                        RecordView(page: page, timeSource: timeSource)
                    }
                    EventsView(timeSource: timeSource)
                }
                .tabViewStyle(.verticalPage)
                .navigationDestination(for: String.self) { id in
                    EventDetailView(eventId: id)
                }
            }
            .environment(store)
            .environment(settings)
            .environment(recorder)
        }
    }
}
