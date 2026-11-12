import WidgetKit

/// Keeps the complications counting from the reference event.
enum Complications {
    /// Call after anything that can change the reference or the time format.
    /// Cheap when nothing the complications show has changed.
    static func update(store: EventStore, settings: WatchSettings, defaults: UserDefaults? = SharedButtons.defaults) {
        let snapshot = ComplicationSnapshot(reference: store.reference, timeFormat: settings.timeFormat)
        if snapshot.save(to: defaults) {
            WidgetCenter.shared.reloadTimelines(ofKind: ComplicationSnapshot.kind)
        }
    }
}
