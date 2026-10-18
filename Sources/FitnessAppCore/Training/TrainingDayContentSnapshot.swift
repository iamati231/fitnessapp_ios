import Foundation

/// P8-Vorbereitung (Stufe-2-Versionierung, siehe `docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`):
/// eingefrorener Tagesinhalt zum Zeitpunkt einer `WorkoutSession` — rein
/// wertbasiert, kein SwiftData-Bezug, damit Encode/Decode/Gleichheit ohne
/// Apple-Toolchain testbar sind. Die Persistenz (`WorkoutSession.
/// contentSnapshotJSON` + `TrainingDayContentSnapshotWriter`, `FitnessAppData`)
/// speichert nur das JSON, das dieser Typ erzeugt/liest.
///
/// **Feldauswahl bewusst NICHT nur von `TrainingDay.currentContentFingerprint`
/// abgeleitet** (der deckt nur "was macht 'neu rechnen' ungültig", nicht
/// "was muss eine Zusammenfassung/ein Player/eine Wiederaufnahme anzeigen
/// können"). Gegenüber dem Fingerprint zusätzlich aufgenommen: `role`
/// (DEL-087 — Warmup/Arbeitssatz/Cooldown, steuert Rendering + Progression),
/// `supersetId` (DEL-083 — A1/B1-Gruppierung), `isCardio`/`isTimeBased`/
/// `cardioEquipment` (bestimmen, welche Spalten/Zielwerte ein Player
/// überhaupt zeigt). Reihenfolge wird durch die Array-Position UND
/// `orderIndex` gehalten (nicht durch Namens-Deduplizierung) — dieselbe
/// Übung kann mehrfach am selben Tag vorkommen (z. B. Hauptsatz + Finisher)
/// und bleibt dadurch unterscheidbar.
public struct TrainingDayContentSnapshot: Codable, Sendable, Equatable {

    /// Explizite Payload-Version (Auftrag: "explizite Payload-Schemaversion").
    /// Nie rückwirkend ändern — ein künftiges Feld-Redesign erhöht diesen
    /// Wert und `decode(fromJSON:)` weist eine unbekannte Version explizit
    /// als `.unsupportedSchemaVersion` zurück, statt sie zu raten oder
    /// stillschweigend mit Platzhaltern aufzufüllen.
    public static let currentSchemaVersion = 1

    public struct ExerciseEntry: Codable, Sendable, Equatable {
        /// Position am Tag zum Aufnahmezeitpunkt — Quelle der Wahrheit für
        /// Reihenfolge UND für das Unterscheiden mehrfach vorkommender
        /// gleichnamiger Übungen (zwei Einträge mit identischem
        /// `exerciseTemplateID`/`nameSnapshot`, aber unterschiedlichem
        /// `orderIndex`, sind zwei verschiedene, absichtlich wiederholte
        /// Übungen — kein Duplikat, das dedupliziert werden dürfte).
        public let orderIndex: Int
        /// P8 Stufe-2 (Wiederaufnahme-Isolation): Snapshot von
        /// `Exercise.instanceID` — stabil ueber externe Umsortierungen des
        /// Tages waehrend einer offenen Session hinweg, anders als
        /// `orderIndex` (der sich dabei aendern kann). `SessionContentResolver`
        /// (`FitnessAppData`) nutzt dieses Feld, um einen Eintrag nach
        /// Wiederaufnahme auf GENAU das Live-Objekt zurueckzufuehren, von dem
        /// er stammt. `nil` nur bei Snapshots, die vor diesem Feld
        /// aufgenommen wurden (altes JSON ohne diesen Key dekodiert dank
        /// `Optional`-Synthese automatisch zu `nil`, kein Schemaversions-
        /// Sprung noetig) — der Resolver faellt dann auf
        /// `exerciseTemplateID`+`orderIndex` zurueck.
        public let instanceID: UUID?
        /// Settings-Epic Phase 6 (EXLIB-07/09) Stabil-Referenz-Muster,
        /// identisch zu `Exercise.exerciseTemplateID`/
        /// `ExerciseLog.exerciseTemplateIDSnapshot`. `nil` nur bei
        /// Alt-Einträgen ohne Vorlagen-Zuordnung.
        public let exerciseTemplateID: UUID?
        /// = `Exercise.name` zum Aufnahmezeitpunkt (System-/DE-Anker, nie
        /// direkt anzuzeigen — siehe `nameSnapshot`-Konvention bei
        /// `ExerciseLog`).
        public let nameSnapshot: String
        /// = `Exercise.customName`. Bewusst ZUSÄTZLICH zu `nameSnapshot`
        /// gespeichert (anders als `ExerciseLog.exerciseNameSnapshot`, das
        /// NUR den System-Namen hält) — eine künftige Anzeige dieses
        /// Snapshots soll denselben "customName zuerst, sonst lokalisierter
        /// Katalog-Eintrag"-Pfad nutzen können wie ein lebendes `Exercise`.
        public let customNameSnapshot: String?
        /// DEL-087 — Warmup/Arbeitssatz/Cooldown. Fehlt im Fingerprint,
        /// ändert aber sichtbar, wie ein Player/eine Zusammenfassung diese
        /// Zeile rendert und ob die Progression sie überhaupt bewertet.
        public let role: ExerciseRole
        /// DEL-083 — Superset-Gruppierung (A1/B1 statt A1/A2/B1/B2).
        public let supersetId: UUID?
        public let isCardio: Bool
        public let isTimeBased: Bool
        public let cardioEquipment: CardioEquipment
        public let sets: Int
        public let repsMin: Int
        public let repsMax: Int
        public let restSeconds: Int
        public let targetRir: Float
        public let targetDistanceKm: Double?
        public let targetDurationMinutes: Int?

        public init(
            orderIndex: Int,
            instanceID: UUID?,
            exerciseTemplateID: UUID?,
            nameSnapshot: String,
            customNameSnapshot: String?,
            role: ExerciseRole,
            supersetId: UUID?,
            isCardio: Bool,
            isTimeBased: Bool,
            cardioEquipment: CardioEquipment,
            sets: Int,
            repsMin: Int,
            repsMax: Int,
            restSeconds: Int,
            targetRir: Float,
            targetDistanceKm: Double?,
            targetDurationMinutes: Int?
        ) {
            self.orderIndex = orderIndex
            self.instanceID = instanceID
            self.exerciseTemplateID = exerciseTemplateID
            self.nameSnapshot = nameSnapshot
            self.customNameSnapshot = customNameSnapshot
            self.role = role
            self.supersetId = supersetId
            self.isCardio = isCardio
            self.isTimeBased = isTimeBased
            self.cardioEquipment = cardioEquipment
            self.sets = sets
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.restSeconds = restSeconds
            self.targetRir = targetRir
            self.targetDistanceKm = targetDistanceKm
            self.targetDurationMinutes = targetDurationMinutes
        }
    }

    public let schemaVersion: Int
    public let dayNameSnapshot: String
    public let dayCustomNameSnapshot: String?
    public let dayLocalizationKeySnapshot: String?
    public let weekday: Int
    public let dayType: DayType
    public let timeFormat: WorkoutTimeFormat?
    public let timeCapMinutes: Int?
    public let circuitRounds: Int?
    public let circuitRestSeconds: Int?
    public let circuitMode: CircuitRoundMode?
    /// Geordnete, VOLLSTÄNDIGE Liste — eine leere Liste ist ein gültiger
    /// Zustand (z. B. ein Ad-hoc-Training im Moment der Erzeugung, bevor die
    /// erste Übung hinzugefügt wurde), kein Fehler und keine Datenlücke.
    public let exercises: [ExerciseEntry]

    public init(
        dayNameSnapshot: String,
        dayCustomNameSnapshot: String?,
        dayLocalizationKeySnapshot: String?,
        weekday: Int,
        dayType: DayType,
        timeFormat: WorkoutTimeFormat?,
        timeCapMinutes: Int?,
        circuitRounds: Int?,
        circuitRestSeconds: Int?,
        circuitMode: CircuitRoundMode?,
        exercises: [ExerciseEntry]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.dayNameSnapshot = dayNameSnapshot
        self.dayCustomNameSnapshot = dayCustomNameSnapshot
        self.dayLocalizationKeySnapshot = dayLocalizationKeySnapshot
        self.weekday = weekday
        self.dayType = dayType
        self.timeFormat = timeFormat
        self.timeCapMinutes = timeCapMinutes
        self.circuitRounds = circuitRounds
        self.circuitRestSeconds = circuitRestSeconds
        self.circuitMode = circuitMode
        self.exercises = exercises
    }

    /// P8 Stufe-2: Kopie mit ausgetauschter Übungsliste, alle anderen Felder
    /// unverändert. Einzig für explizite In-Session-Änderungen gedacht
    /// (`TrainingDayContentSnapshotWriter.recordAdHocExercise…`) — hängt
    /// gezielt einen Eintrag an bzw. entfernt ihn, statt den gesamten
    /// Snapshot aus dem (ggf. zwischenzeitlich extern veränderten) Live-Tag
    /// neu zu bauen.
    public func withExercises(_ exercises: [ExerciseEntry]) -> TrainingDayContentSnapshot {
        TrainingDayContentSnapshot(
            dayNameSnapshot: dayNameSnapshot,
            dayCustomNameSnapshot: dayCustomNameSnapshot,
            dayLocalizationKeySnapshot: dayLocalizationKeySnapshot,
            weekday: weekday,
            dayType: dayType,
            timeFormat: timeFormat,
            timeCapMinutes: timeCapMinutes,
            circuitRounds: circuitRounds,
            circuitRestSeconds: circuitRestSeconds,
            circuitMode: circuitMode,
            exercises: exercises
        )
    }
}

/// Warum ein gespeicherter Snapshot NICHT gelesen werden konnte — nie
/// stillschweigend durch den (ggf. seither veränderten) Live-Tagesinhalt
/// ersetzen, sondern als eigenen, sichtbaren Zustand behandeln (Auftrag:
/// "Keinen beschädigten Snapshot stillschweigend durch Live-Inhalt
/// ersetzen").
public enum TrainingDayContentSnapshotDecodeError: Error, Sendable, Equatable {
    /// JSON liess sich nicht als `TrainingDayContentSnapshot` dekodieren
    /// (defekte Daten, z. B. durch Store-Korruption).
    case corrupted
    /// Dekodierbar, aber `schemaVersion` ist nicht die hier bekannte
    /// `currentSchemaVersion` — z. B. ein künftiges Feld-Redesign, dessen
    /// Payload eine ältere Appversion nicht sicher interpretieren darf.
    case unsupportedSchemaVersion(Int)
}

extension TrainingDayContentSnapshot {
    /// Einzige Decode-Stelle — prüft `schemaVersion` explizit, statt sich
    /// auf `Codable`s Standardverhalten (fehlende/zusätzliche Felder
    /// stillschweigend ignorieren) zu verlassen.
    public static func decode(
        fromJSON json: String
    ) -> Result<TrainingDayContentSnapshot, TrainingDayContentSnapshotDecodeError> {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return .failure(.corrupted)
        }
        guard decoded.schemaVersion == currentSchemaVersion else {
            return .failure(.unsupportedSchemaVersion(decoded.schemaVersion))
        }
        return .success(decoded)
    }

    /// `nil` nur bei einem (praktisch nie auftretenden) Encoding-Fehler —
    /// der Aufrufer behandelt das wie "Aufnahme fehlgeschlagen", nicht wie
    /// "kein Inhalt".
    public func encodedJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Die drei klar unterscheidbaren Fälle, in denen eine `WorkoutSession`
/// sich zu ihrem historischen Tagesinhalt äußern kann (Auftrag:
/// "unterscheidbare Fälle: kein Snapshot, gültig leerer Snapshot,
/// beschädigter oder nicht unterstützter Snapshot"). `.available` mit einer
/// leeren `exercises`-Liste IST der "gültig leere Snapshot"-Fall — er
/// bekommt bewusst keinen eigenen Case, weil er sich nicht anders verhält
/// als jeder andere erfolgreich gelesene Snapshot.
public enum TrainingDayContentSnapshotState: Sendable, Equatable {
    /// Für diese Session wurde (noch) nie ein Snapshot aufgenommen —
    /// Altbestand vor diesem Feature, oder ein Importpfad ohne
    /// Snapshot-Spalte (siehe Plan-Dokument, Paket D).
    case notCaptured
    case available(TrainingDayContentSnapshot)
    case unreadable(TrainingDayContentSnapshotDecodeError)
}
