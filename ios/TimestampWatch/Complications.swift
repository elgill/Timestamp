import WidgetKit

/// Keeps the complications counting from the reference and latest events.
enum Complications {
    /// Call after anything that can change the events or the time format.
    /// Cheap when nothing the complications show has changed.
    static func update(store: EventStore, settings: WatchSettings, defaults: UserDefaults? = SharedButtons.defaults) {
        let snapshot = ComplicationSnapshot(
            reference: store.reference, latest: store.events.first, timeFormat: settings.timeFormat)
        for source in snapshot.save(to: defaults) {
            WidgetCenter.shared.reloadTimelines(ofKind: source.kind)
        }
    }
}
