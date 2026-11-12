import AppIntents

// Record Event, for Shortcuts, Siri, Spotlight, the Action button and
// controls. Compiled into the phone app, the watch app and the watch's
// controls extension, each of which records in its own way.

/// A record button, as Shortcuts and the Action button's control offer it.
@available(iOS 16.0, watchOS 9.0, *)
struct RecordButtonEntity: AppEntity {
    /// The button's name, which is how the phone identifies a button too.
    var id: String
    var color: EventColor

    init(_ config: RecordButtonConfig) {
        id = config.name
        color = config.color
    }

    var config: RecordButtonConfig { RecordButtonConfig(name: id, color: color) }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
    static let defaultQuery = RecordButtonQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

@available(iOS 16.0, watchOS 9.0, *)
struct RecordButtonQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RecordButtonEntity] {
        // A button renamed or deleted on the phone keeps recording under the
        // name and color it was chosen with, so a shortcut never misses.
        identifiers.map { RecordButtonEntity(SharedButtons.config(named: $0)) }
    }

    func suggestedEntities() async throws -> [RecordButtonEntity] {
        SharedButtons.load().map(RecordButtonEntity.init)
    }
}

/// Records an event, as a record button would.
///
/// On the watch it runs in the app, which it opens, because only the app
/// keeps the events and talks to the phone; the controls extension compiles
/// it to offer it, but never performs it. On the phone it runs without
/// opening the app, and the app takes the event in when it next runs.
///
/// The event is timed when this runs, which is some way behind the tap or
/// press that started it, by however long the system took to get here.
@available(iOS 16.0, watchOS 9.0, *)
struct RecordEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Event"
    static let description = IntentDescription(
        "Records the time, as tapping one of your buttons does. The time is when the action runs, a moment after you start it, so it's less precise than a tap.")

    #if os(watchOS)
    // Before watchOS 26; from then on `supportedModes` says the same.
    static let openAppWhenRun = true
    #endif

    /// None means the unnamed button.
    @Parameter(title: "Event")
    var button: RecordButtonEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$button)")
    }

    init() {}

    init(button: RecordButtonEntity?) {
        self.button = button
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Date> {
        // Read first: everything after this only adds to the delay.
        let now = Date()
        // Set by the system for some Action button presses, though not for
        // a control on the Action button, so mostly nil.
        let pressedAt = systemContext.preciseTimestamp
        #if os(iOS)
        let time = PhoneRecorder.record(button?.config, at: pressedAt ?? now)
        #elseif CONTROLS_EXTENSION
        let time = now
        #else
        let time = IntentRecorder.record(button?.config, at: now, pressedAt: pressedAt)
        #endif
        return .result(value: time)
    }
}

@available(iOS 26.0, watchOS 26.0, *)
extension RecordEventIntent {
    #if os(watchOS)
    static let supportedModes: IntentModes = .foreground
    #else
    static let supportedModes: IntentModes = .background
    #endif
}

#if os(watchOS)
/// The Action button's control is set up with the button to record.
@available(watchOS 26.0, *)
extension RecordEventIntent: ControlConfigurationIntent {}
#endif

#if !CONTROLS_EXTENSION
/// Offers Record Event to Siri, Spotlight and Shortcuts without the user
/// building a shortcut, and on iPhone to the Action button.
@available(iOS 16.0, watchOS 9.0, *)
struct TimestampShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordEventIntent(),
            phrases: [
                "Record an event in \(.applicationName)",
                "Record \(\.$button) in \(.applicationName)",
                "\(.applicationName) \(\.$button)",
            ],
            shortTitle: "Record Event",
            systemImageName: "stopwatch")
    }
}
#endif
