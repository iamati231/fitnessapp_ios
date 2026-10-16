import Foundation

/// Planung-&-Trainingsbegleitung-Epic, P2.0: stabile Identitaet eines Tages
/// im Wochen-Entwurf (`PlanDraft`). `DaySpec` selbst bleibt unveraendert OHNE
/// ID-Feld (siehe Datei-Kommentar dort — `sequenceIndex` ist Array-Position
/// als Daten, keine stabile Identitaet) — diese ID lebt ausschliesslich in
/// der neuen Entwurfs-Schicht und ueberlebt Umsortierung/Fixierung/Ersetzung
/// im visuellen Wochen-Editor (P3.2).
public struct DraftDayID: Hashable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

/// Stabile Identitaet einer Uebung innerhalb eines `DraftDay` — gleiches
/// Prinzip wie `DraftDayID`, fuer `ExerciseSpec` (ebenfalls ID-los).
public struct DraftExerciseID: Hashable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

/// Eine Uebung im Wochen-Entwurf: stabile ID + ihr aktueller Inhalt. `spec`
/// ist die bestehende, unveraenderte `ExerciseSpec`-"Berechnung"-Nutzlast —
/// wird hier referenziert, nicht dupliziert/neu erfunden.
public struct DraftExercise: Sendable, Hashable, Identifiable {
    public let id: DraftExerciseID
    public var spec: ExerciseSpec

    public init(id: DraftExerciseID = DraftExerciseID(), spec: ExerciseSpec) {
        self.id = id
        self.spec = spec
    }
}

/// Ein Tag im Wochen-Entwurf: stabile ID + Inhalt (gespiegelt aus `DaySpec`)
/// + zwei UNABHAENGIG voneinander setzbare Fixierungen.
///
/// Bewusst zwei Bool-Flags PRO TAG statt zweier `Set`s auf `PlanDraft`
/// (so die fruehere Skizze in docs/PLANUNG_BEGLEITUNG_AUDIT.md:
/// `fixedDayIDs: Set<DraftDay.ID>` / `fixedPositionIndices: Set<Int>`) — ein
/// `Set<Int>` ueber Positionen bricht genau dann still, wenn ein ANDERER Tag
/// entfernt oder verschoben wird (die Vorgabe "stabile Identitaeten statt
/// volatiler Indizes" gilt damit auch fuer die Fixierung selbst, nicht nur
/// fuer die Tage). Mit dem Flag direkt am `DraftDay` bleibt die Fixierung
/// beim Verschieben automatisch am richtigen Tag.
public struct DraftDay: Sendable, Hashable, Identifiable {
    public let id: DraftDayID
    public var name: String
    public var type: DayType
    public var localizationKey: String?
    public var timeFormat: WorkoutTimeFormat?
    public var timeCapMinutes: Int?
    public var circuitRounds: Int?
    public var circuitRestSeconds: Int?
    public var circuitMode: CircuitRoundMode?
    public var exercises: [DraftExercise]
    /// Tagesinhalt (Uebungen) bleibt bei Neuberechnung/gezielter Alternative
    /// unangetastet — der Tag darf trotzdem weiterhin die Position wechseln.
    public var isContentFixed: Bool
    /// Tag bleibt an seinem aktuellen Platz in der Woche — der Inhalt darf
    /// sich trotzdem per Alternative aendern, sofern `isContentFixed == false`.
    public var isPositionFixed: Bool

    public init(
        id: DraftDayID = DraftDayID(),
        spec: DaySpec,
        isContentFixed: Bool = false,
        isPositionFixed: Bool = false
    ) {
        self.id = id
        self.name = spec.name
        self.type = spec.type
        self.localizationKey = spec.localizationKey
        self.timeFormat = spec.timeFormat
        self.timeCapMinutes = spec.timeCapMinutes
        self.circuitRounds = spec.circuitRounds
        self.circuitRestSeconds = spec.circuitRestSeconds
        self.circuitMode = spec.circuitMode
        self.exercises = spec.exercises.map { DraftExercise(spec: $0) }
        self.isContentFixed = isContentFixed
        self.isPositionFixed = isPositionFixed
    }

    /// Projiziert den Entwurfs-Inhalt zurueck auf die bestehende
    /// "Berechnung"-Nutzlast. `sequenceIndex` wird vom Aufrufer
    /// (`PlanDraft.resolvedDaySpecs`) anhand der tatsaechlichen
    /// Array-Position vergeben — ein einzelner `DraftDay` kennt seine
    /// Position im Entwurf nicht.
    public func spec(sequenceIndex: Int) -> DaySpec {
        DaySpec(
            name: name,
            localizationKey: localizationKey,
            type: type,
            sequenceIndex: sequenceIndex,
            exercises: exercises.map(\.spec),
            timeFormat: timeFormat,
            timeCapMinutes: timeCapMinutes,
            circuitRounds: circuitRounds,
            circuitRestSeconds: circuitRestSeconds,
            circuitMode: circuitMode
        )
    }
}

/// Planung-&-Trainingsbegleitung-Epic, P2.0: der editierbare Wochen-Entwurf
/// fuer den visuellen Wochen-Editor (P3.2) — die neue "Entwurf"-Schicht
/// zwischen Generator-Ausgabe/Template-Auswahl (`PlanGenerator.Result`/
/// `ResolvedPlanSelection`, beide bleiben unveraendert die "Berechnung"-
/// Schicht) und der tatsaechlichen Persistenz (`TrainingDay`/`Exercise`,
/// SwiftData, ausserhalb von Core — Doc01 §9 "Entwurf, Berechnung und
/// Persistenz trennen").
///
/// Rein wertbasiert, KEIN `ModelContext`-Bezug und KEINE Mutation eines
/// bestehenden Plans (Vorgabe "draft-first", P3.2): auch beim Bearbeiten
/// eines bereits existierenden Plans wird dessen aktueller Stand einmal
/// hierher kopiert (`init(generated:)`), nie live referenziert. Das
/// Zurueckschreiben in den `ModelContext` passiert ausschliesslich ueber den
/// gemeinsamen Adopt-Pfad (P2.3), niemals waehrend der Bearbeitung selbst.
public struct PlanDraft: Sendable, Hashable {
    public var days: [DraftDay]

    public init(days: [DraftDay]) {
        self.days = days
    }

    /// Baut den Entwurf aus bereits erzeugten/aufgeloesten Tagen auf —
    /// gleichermassen geeignet fuer frisch generierte Tage
    /// (`PlanGenerator.Result.days.map(\.spec)`), eine Template-Auswahl
    /// (`ResolvedPlanSelection.days`) ODER die exportierten Tage eines
    /// bestehenden Plans (P3.2-Bearbeiten-Fall). Sortiert nach
    /// `sequenceIndex`, damit die Array-Reihenfolge von Anfang an mit der
    /// fachlichen Reihenfolge uebereinstimmt.
    public init(generated daySpecs: [DaySpec]) {
        self.days = daySpecs
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
            .map { DraftDay(spec: $0) }
    }

    /// Die Projektion zurueck auf `[DaySpec]` (z.B. fuer einen Instantiator).
    /// `sequenceIndex` wird strikt aus der aktuellen Array-Position vergeben
    /// (1-basiert, siehe `DaySpec.sequenceIndex`-Dokumentation) — unabhaengig
    /// davon, welchen Index ein Tag beim Entwurfs-Start hatte.
    public var resolvedDaySpecs: [DaySpec] {
        days.enumerated().map { index, day in day.spec(sequenceIndex: index + 1) }
    }

    public func index(of id: DraftDayID) -> Int? {
        days.firstIndex { $0.id == id }
    }

    /// Verschiebt einen Tag an eine neue Position. Liefert `false` (Entwurf
    /// bleibt unveraendert), wenn der Tag nicht existiert oder
    /// positionsfixiert ist — ein Reorder-Drag in der UI darf das zusaetzlich
    /// selbst pruefen, die Daten-Schicht erzwingt es in jedem Fall.
    @discardableResult
    public mutating func moveDay(_ id: DraftDayID, toIndex newIndex: Int) -> Bool {
        guard let oldIndex = index(of: id), !days[oldIndex].isPositionFixed else { return false }
        let day = days.remove(at: oldIndex)
        let clampedIndex = max(0, min(newIndex, days.count))
        days.insert(day, at: clampedIndex)
        return true
    }

    /// Ersetzt den Inhalt eines Tages — die gezielte EINZEL-Alternative statt
    /// des bisherigen globalen "neu mischen" (Audit §1). Position und beide
    /// Fixierungs-Flags bleiben erhalten, nur `isContentFixed == true`
    /// verhindert den Austausch.
    @discardableResult
    public mutating func replaceContent(of id: DraftDayID, with spec: DaySpec) -> Bool {
        guard let idx = index(of: id), !days[idx].isContentFixed else { return false }
        let existing = days[idx]
        days[idx] = DraftDay(
            id: id,
            spec: spec,
            isContentFixed: existing.isContentFixed,
            isPositionFixed: existing.isPositionFixed
        )
        return true
    }

    public mutating func setContentFixed(_ fixed: Bool, for id: DraftDayID) {
        guard let idx = index(of: id) else { return }
        days[idx].isContentFixed = fixed
    }

    public mutating func setPositionFixed(_ fixed: Bool, for id: DraftDayID) {
        guard let idx = index(of: id) else { return }
        days[idx].isPositionFixed = fixed
    }
}
