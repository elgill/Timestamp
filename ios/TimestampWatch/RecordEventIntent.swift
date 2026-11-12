import AppIntents

/// A record button, as the Action button's control offers it.
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

struct RecordButtonQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RecordButtonEntity] {
        let buttons = SharedButtons.load()
        // A button renamed or removed on the phone keeps working under the
        // name it was chosen by, so the Action button still records something.
        return identifiers.map { name in
            RecordButtonEntity(buttons.first { $0.name == name } ?? RecordButtonConfig(name: name, color: .defaultColor))
        }
    }

    func suggestedEntities() async throws -> [RecordButtonEntity] {
        SharedButtons.load().map(RecordButtonEntity.init)
    }
}

/// Records an event, as a record button would. The Action button's control
/// runs it, with the button chosen when the control was set up.
///
/// It runs in the watch app, which it opens, because only the app keeps the
/// events and talks to the phone. The controls extension compiles it too,
/// to offer it, but never performs it.
@available(watchOS 26.0, *)
struct RecordEventIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Record Event"
    static let description = IntentDescription("Records the time, as tapping one of your buttons does.")
    static let supportedModes: IntentModes = .foreground

    /// None means the unnamed button.
    @Parameter(title: "Event")
    var button: RecordButtonEntity?

    init() {}

    init(button: RecordButtonEntity?) {
        self.button = button
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !CONTROLS_EXTENSION
        // Set by the system when the Action button started this, so the
        // event gets the moment of the press, not of the app opening.
        ActionButton.record(button?.config, pressedAt: systemContext.preciseTimestamp)
        #endif
        return .result()
    }
}
