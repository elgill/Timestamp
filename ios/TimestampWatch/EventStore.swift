import Foundation
import Observation

/// The events the watch shows: the phone's newest events, plus any recorded
/// here that the phone hasn't taken in yet. Saved to a JSON file so they're
/// there without the phone.
@Observable
final class EventStore {
    /// Newest first.
    private(set) var events: [WatchEvent] = []
    /// What relative times count from: the reference chosen here until the
    /// phone has caught up, else the phone's reference event, or without one
    /// the oldest event, as on the phone.
    private(set) var reference: WatchEvent?

    /// Recorded here and not yet seen in what the phone sent.
    @ObservationIgnored private var recorded: [WatchEvent] = []
    /// The phone's newest events, as last sent.
    @ObservationIgnored private var phoneEvents: [WatchEvent] = []
    @ObservationIgnored private var phoneReference: WatchEvent?
    /// Chosen here and not yet settled with the phone. Kept over what the
    /// phone sends until the phone has taken it in or has a later choice, so
    /// a context sent before the phone heard of it can't undo it.
    @ObservationIgnored private var chosenReference: ReferenceChoice?
    /// Events recorded on this watch. Only these can be deleted here; the
    /// rest belong to the phone.
    @ObservationIgnored private var ownIds: Set<String> = []
    /// Deleted here but still in what the phone last sent, because it hasn't
    /// processed the delete yet.
    @ObservationIgnored private var hiddenIds: Set<String> = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = EventStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
        refresh()
    }

    func add(_ event: WatchEvent) {
        recorded.append(event)
        ownIds.insert(event.id)
        changed()
    }

    /// Recorded here and not yet seen in what the phone sent, oldest first.
    var unconfirmed: [WatchEvent] {
        recorded.sorted { $0.time < $1.time }
    }

    /// Makes `event` the reference here and returns the choice, for the
    /// phone to take too.
    @discardableResult
    func setReference(_ event: WatchEvent, at time: Date = Date()) -> ReferenceChoice {
        let choice = ReferenceChoice(id: event.id, setAt: time)
        chosenReference = choice
        changed()
        return choice
    }

    func canDelete(_ event: WatchEvent) -> Bool {
        ownIds.contains(event.id)
    }

    /// Deletes those of `ids` recorded on this watch and returns them, for
    /// the phone to delete too.
    @discardableResult
    func delete(ids: Set<String>) -> [String] {
        let deleted = ids.intersection(ownIds)
        guard !deleted.isEmpty else { return [] }
        recorded.removeAll { deleted.contains($0.id) }
        // The phone falls back on its own once it deletes the event too.
        if let chosen = chosenReference, deleted.contains(chosen.id) {
            chosenReference = nil
        }
        ownIds.subtract(deleted)
        hiddenIds.formUnion(deleted)
        changed()
        return deleted.sorted()
    }

    /// Takes in what the phone sent. Events it has, or has taken in and
    /// since deleted, no longer need holding here.
    func apply(_ context: PhoneContext) {
        phoneEvents = context.events
        phoneReference = context.reference
        let phoneIds = Set(context.events.map(\.id))
        let imported = Set(context.importedIds)
        recorded.removeAll { phoneIds.contains($0.id) || imported.contains($0.id) }
        // The phone has processed a delete once the event is gone from it.
        hiddenIds.formIntersection(phoneIds)
        ownIds.formIntersection(phoneIds.union(recorded.map(\.id)))
        if let chosen = chosenReference {
            let settled = context.referenceSetAt.map { $0 >= chosen.setAt } ?? false
            // Deleted on the phone, so it can't take the choice.
            let gone = !phoneIds.contains(chosen.id) && !recorded.contains { $0.id == chosen.id }
            if settled || gone { chosenReference = nil }
        }
        changed()
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "events.json")
    }

    private func changed() {
        refresh()
        save()
    }

    private func refresh() {
        var seen = Set<String>()
        events = (recorded + phoneEvents)
            .filter { !hiddenIds.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.time > $1.time }
        if let chosen = chosenReference, let event = events.first(where: { $0.id == chosen.id }) {
            reference = event
        } else if let phoneReference, !hiddenIds.contains(phoneReference.id) {
            reference = phoneReference
        } else {
            reference = events.last
        }
    }

    // MARK: Saving

    private struct Saved: Codable {
        var recorded: [Lossy<WatchEvent>]
        var phoneEvents: [Lossy<WatchEvent>]
        var phoneReference: WatchEvent?
        var chosenReference: ReferenceChoice?
        var ownIds: [String]
        var hiddenIds: [String]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? WatchJSON.decoder.decode(Saved.self, from: data)
        else { return }
        // One unreadable entry must not cost the user the rest of the log.
        recorded = saved.recorded.compactMap(\.value)
        phoneEvents = saved.phoneEvents.compactMap(\.value)
        phoneReference = saved.phoneReference
        chosenReference = saved.chosenReference
        ownIds = Set(saved.ownIds)
        hiddenIds = Set(saved.hiddenIds)
    }

    private func save() {
        let saved = Saved(
            recorded: recorded.map { Lossy(value: $0) },
            phoneEvents: phoneEvents.map { Lossy(value: $0) },
            phoneReference: phoneReference,
            chosenReference: chosenReference,
            ownIds: ownIds.sorted(),
            hiddenIds: hiddenIds.sorted())
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try WatchJSON.encoder.encode(saved).write(to: fileURL, options: .atomic)
        } catch {
            // Keep going: the events are still in memory and the next save
            // tries again.
            print("Saving events failed: \(error)")
        }
    }
}
