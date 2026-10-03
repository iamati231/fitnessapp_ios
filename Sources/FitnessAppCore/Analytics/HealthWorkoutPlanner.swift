import Foundation

// MARK: - Typen

/// Die zwei Schalter-Kategorien beim Schreiben nach Apple Health.
public enum HealthWorkoutCategory: String, Sendable, Equatable, Hashable, CaseIterable {
    case strength
    case cardio
}

/// Die Trainingsart, mit der ein Training in Apple Health landet. Bewusst nur
/// fuenf Arten: Rudern, Crosstrainer, Stepper, Schwimmen und eigene Cardio-
/// Uebungen laufen als `mixedCardio` (Innen/Aussen wird ueber `isIndoor`
/// ausgedrueckt) — jede weitere Art waere ein ungetesteter Geraete-Pfad.
public enum HealthWorkoutActivity: String, Sendable, Equatable {
    case strength
    case running
    case walking
    case cycling
    case mixedCardio

    public var category: HealthWorkoutCategory {
        self == .strength ? .strength : .cardio
    }
}

/// Ein geloggter (nicht leerer) Satz einer Session als reiner Wert.
public struct HealthWorkoutLogInput: Sendable, Equatable {
    /// System-Name der Uebung (DE-Basisname, wie `exerciseNameSnapshot`).
    /// Der Aufrufer kanonisiert Fremdsprach-Namen vorher.
    public var exerciseName: String
    public var isCardio: Bool
    public var distanceKm: Double?
    public var durationSeconds: Int?
    /// Vom Nutzer gesetztes Geraet; schlaegt den Namen (ausser `.none`).
    public var equipment: CardioEquipment

    public init(
        exerciseName: String,
        isCardio: Bool,
        distanceKm: Double? = nil,
        durationSeconds: Int? = nil,
        equipment: CardioEquipment = .none
    ) {
        self.exerciseName = exerciseName
        self.isCardio = isCardio
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.equipment = equipment
    }
}

/// Eine Session als reiner Wert — SwiftData-Modelle gibt es in Core nicht, und
/// die Entscheidungslogik soll ohne UI testbar sein.
public struct HealthWorkoutCandidate: Sendable, Equatable {
    public var startTime: Date
    public var endTime: Date
    public var durationMinutes: Int
    public var isCompleted: Bool
    public var isRestDay: Bool
    /// Aus Apple Health importiert (`importSourceName`/`healthKitSampleUUID`):
    /// wird NIE zurueckgeschrieben.
    public var isImported: Bool
    /// Wurde schon behandelt (geschrieben oder als "bereits in Health" erkannt).
    public var hasExportMarker: Bool
    /// AMRAP/EMOM/Auf Zeit/Zirkel: solche Sessions haben nie `ExerciseLog`s.
    public var hasTimeFormat: Bool
    /// `true`, wenn der (noch vorhandene) Tag nur Cardio-Uebungen enthaelt;
    /// `nil`, wenn unbekannt (Tag geloescht).
    public var dayIsAllCardio: Bool?
    /// Nur echte Saetze, keine 0/0-Platzhalter.
    public var logs: [HealthWorkoutLogInput]
    public var totalSets: Int
    public var totalVolumeKg: Double

    public init(
        startTime: Date,
        endTime: Date,
        durationMinutes: Int,
        isCompleted: Bool = true,
        isRestDay: Bool = false,
        isImported: Bool = false,
        hasExportMarker: Bool = false,
        hasTimeFormat: Bool = false,
        dayIsAllCardio: Bool? = nil,
        logs: [HealthWorkoutLogInput] = [],
        totalSets: Int = 0,
        totalVolumeKg: Double = 0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.isImported = isImported
        self.hasExportMarker = hasExportMarker
        self.hasTimeFormat = hasTimeFormat
        self.dayIsAllCardio = dayIsAllCardio
        self.logs = logs
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
    }
}

/// Was fuer ein Training nach Apple Health geschrieben werden soll.
public struct HealthWorkoutPlan: Sendable, Equatable {
    public var activity: HealthWorkoutActivity
    public var start: Date
    public var end: Date
    /// `true` = drinnen, `false` = draussen, `nil` = unbekannt (dann setzt der
    /// Writer weder Ort noch Indoor-Flag).
    public var isIndoor: Bool?
    /// Distanz-SAMPLE: nur Laufen/Gehen (`distanceWalkingRunning`); Rad-/
    /// Ruder-Distanz bekommt kein Sample (eigener Health-Typ / Berechtigung).
    public var distanceKm: Double?
    public var averagePaceMinPerKm: Double?
    /// Gesamtstrecke aller Cardio-Logs, jede Modalitaet — nur fuer die
    /// Metadaten des Workouts (`TotalDistanceKm`), nie als Sample.
    public var totalDistanceKm: Double?
    /// Nur Krafttraining.
    public var totalSets: Int?
    public var totalVolumeKg: Double?

    public var category: HealthWorkoutCategory { activity.category }

    public init(
        activity: HealthWorkoutActivity,
        start: Date,
        end: Date,
        isIndoor: Bool?,
        distanceKm: Double? = nil,
        averagePaceMinPerKm: Double? = nil,
        totalDistanceKm: Double? = nil,
        totalSets: Int? = nil,
        totalVolumeKg: Double? = nil
    ) {
        self.activity = activity
        self.start = start
        self.end = end
        self.isIndoor = isIndoor
        self.distanceKm = distanceKm
        self.averagePaceMinPerKm = averagePaceMinPerKm
        self.totalDistanceKm = totalDistanceKm
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
    }
}

public enum HealthWorkoutSkipReason: String, Sendable, Equatable {
    // Kein Export-Kandidat (taucht in keinem Zaehler auf).
    case notCompleted
    case restDay
    case imported
    case alreadyExported
    // Kandidat, aber nicht exportierbar.
    case noContent
    case tooShort
    case tooLong
    case inFuture
    // Auswahl (Kategorie abgeschaltet).
    case categoryDisabled
    // Steht (vermutlich) schon in Apple Health — eigene oder fremde Quelle.
    case alreadyInHealth

    /// Zaehlt nicht als Export-Kandidat.
    public var isIneligible: Bool {
        switch self {
        case .notCompleted, .restDay, .imported, .alreadyExported: return true
        default: return false
        }
    }

    /// Kandidat, der sich nicht sinnvoll nach Health schreiben laesst.
    public var isNotExportable: Bool {
        switch self {
        case .noContent, .tooShort, .tooLong, .inFuture: return true
        default: return false
        }
    }
}

public enum HealthWorkoutDecision: Sendable, Equatable {
    case write(HealthWorkoutPlan)
    case skip(HealthWorkoutSkipReason)
}

/// Ergebnis von `HealthWorkoutPlanner.selectForExport`. Indizes beziehen sich
/// auf die uebergebene Kandidatenliste.
public struct HealthExportSelection: Sendable, Equatable {
    public struct Planned: Sendable, Equatable {
        public let index: Int
        public let plan: HealthWorkoutPlan
        public init(index: Int, plan: HealthWorkoutPlan) {
            self.index = index
            self.plan = plan
        }
    }

    /// In der Reihenfolge der Kandidaten.
    public var toWrite: [Planned] = []
    /// Ueberlappen ein echtes Health-Workout.
    public var alreadyInHealth: [Int] = []
    /// Zu kurz/lang, in der Zukunft oder ohne Inhalt.
    public var notExportable = 0
    /// Ueberlappen nur eine andere geplante Session: weder schreiben noch markieren.
    public var deferred = 0

    public init() {}
}

// MARK: - Planer

/// Die EINE Entscheidungsfunktion fuer "Wird dieses Training nach Apple
/// Health geschrieben, und wie?" — gemeinsam fuer das Schreiben nach jedem
/// beendeten Training (ohne Health-Fenster) und den Export frueherer
/// Trainings (mit den Fenstern der in Health sichtbaren Workouts).
///
/// Reihenfolge der Pruefungen (jede Stufe ist getestet):
/// 1. Eligibility: abgeschlossen, kein Ruhetag, nicht importiert, nicht schon
///    behandelt.
/// 2. Inhalt: geloggte Saetze oder Zeitformat.
/// 3. Zeitfenster: 1 min ... 6 h, nicht in der Zukunft.
/// 4. Klassifikation (Kraft / Laufen / Gehen / Rad / Cardio gemischt).
/// 5. Kategorie-Schalter.
/// 6. Abgleich mit Health: `ExternalWorkoutDedup` mit der Session als Sample
///    — ueberlappt mehr als die Haelfte der SESSION-Dauer mit einem sichtbaren
///    Workout (eigener oder fremder Quelle), steht sie schon in Health. Ein
///    kurzes Fremd-Workout in einer langen Session blockiert sie damit nicht.
///    Geprueft wird das Fenster, das geschrieben wuerde, gegen ALLE sichtbaren
///    Workouts (`existingWindows`) — und die vermutlich urspruenglich
///    aufgezeichneten Fenster (`recordedWindows`) NUR gegen Deltiqs eigene
///    (`ownWindows`): Hat der Nutzer Beginn oder Dauer nach dem Beenden im
///    Verlauf geaendert, steht in Health noch das alte, live geschriebene Fenster
///    — sonst entstuende ein Doppel. Die Vermutung darf kein fremdes Workout
///    treffen, sonst wuerde eine unbeteiligte Session dauerhaft als "schon in
///    Health" gelten.
public enum HealthWorkoutPlanner {

    public static let minimumDurationSeconds: TimeInterval = 60
    /// Eigene Grenze (kein Apple-Wert): laengere Sessions sind fast immer
    /// vergessen offen gelassene oder fortgesetzte Einheiten — ihre Dauer als
    /// Trainingszeit in Health zu schreiben waere falsch (Review 5.1.3(ii)).
    public static let maximumDurationSeconds: TimeInterval = 6 * 60 * 60
    /// Toleranz fuer "Ende liegt in der Zukunft" (Sekundenrundung, Uhr).
    public static let futureToleranceSeconds: TimeInterval = 60

    /// Fenster, das nach Health geschrieben wird: `[start, end]`, wenn
    /// `durationMinutes` dazu passt, sonst `[start, start + durationMinutes]`.
    /// Der History-Editor aendert nur `startTime` und `durationMinutes`, nie
    /// `endTime` — nach einem Edit ist `endTime` veraltet.
    public static func effectiveWindow(
        startTime: Date,
        endTime: Date,
        durationMinutes: Int
    ) -> (start: Date, end: Date) {
        let measured = endTime.timeIntervalSince(startTime)
        let consistent = measured >= 0 && Int(measured) / 60 == durationMinutes
        if consistent { return (startTime, endTime) }
        return (startTime, startTime.addingTimeInterval(Double(max(durationMinutes, 0)) * 60))
    }

    public static func decide(
        _ candidate: HealthWorkoutCandidate,
        enabledCategories: Set<HealthWorkoutCategory>,
        existingWindows: [(start: Date, end: Date)] = [],
        ownWindows: [(start: Date, end: Date)] = [],
        now: Date
    ) -> HealthWorkoutDecision {
        if !candidate.isCompleted { return .skip(.notCompleted) }
        if candidate.isRestDay { return .skip(.restDay) }
        if candidate.isImported { return .skip(.imported) }
        if candidate.hasExportMarker { return .skip(.alreadyExported) }
        guard candidate.hasTimeFormat || !candidate.logs.isEmpty else { return .skip(.noContent) }

        let window = effectiveWindow(
            startTime: candidate.startTime,
            endTime: candidate.endTime,
            durationMinutes: candidate.durationMinutes
        )
        let duration = window.end.timeIntervalSince(window.start)
        if duration < minimumDurationSeconds { return .skip(.tooShort) }
        if duration > maximumDurationSeconds { return .skip(.tooLong) }
        if window.end > now.addingTimeInterval(futureToleranceSeconds) { return .skip(.inFuture) }

        let plan = makePlan(candidate, window: window)
        guard enabledCategories.contains(plan.category) else { return .skip(.categoryDisabled) }

        if ExternalWorkoutDedup.overlapsExisting(
            sampleStart: window.start,
            sampleEnd: window.end,
            existingWindows: existingWindows
        ) {
            return .skip(.alreadyInHealth)
        }
        for recorded in recordedWindows(of: candidate, effective: window) {
            if ExternalWorkoutDedup.overlapsExisting(
                sampleStart: recorded.start,
                sampleEnd: recorded.end,
                existingWindows: ownWindows
            ) {
                return .skip(.alreadyInHealth)
            }
        }
        return .write(plan)
    }

    /// Fenster, unter denen die Session schon (live) nach Health geschrieben
    /// worden sein kann, bevor Beginn oder Dauer im Verlauf geaendert wurden.
    /// Der History-Editor aendert nie `endTime`; es bleibt also das Ende der
    /// urspruenglichen Aufzeichnung:
    /// - nur die Dauer geaendert: `[startTime, endTime]`
    /// - nur der Beginn geaendert: `[endTime - durationMinutes, endTime]`
    /// Beides nur, wenn es vom effektiven Fenster abweicht (sonst dieselbe
    /// Pruefung). Welche der beiden Vermutungen stimmt, ist nicht erkennbar (und
    /// bei gleichzeitig geaenderten Werten stimmt keine) — deshalb werden beide
    /// ausschliesslich gegen eigene Health-Workouts geprueft (`decide`).
    static func recordedWindows(
        of candidate: HealthWorkoutCandidate,
        effective: (start: Date, end: Date)
    ) -> [(start: Date, end: Date)] {
        var windows: [(start: Date, end: Date)] = []
        let end = candidate.endTime
        if end > candidate.startTime, end != effective.end {
            windows.append((start: candidate.startTime, end: end))
        }
        if candidate.durationMinutes > 0 {
            let derivedStart = end.addingTimeInterval(-Double(candidate.durationMinutes) * 60)
            if derivedStart != effective.start || end != effective.end {
                windows.append((start: derivedStart, end: end))
            }
        }
        return windows
    }

    // MARK: Export-Auswahl

    /// Rand um den Export-Zeitraum bei der Abfrage der Health-Workouts.
    public static let queryMarginSeconds: TimeInterval = 24 * 3600

    /// Zeitraum, in dem Health-Workouts abgefragt werden muessen, damit
    /// `decide`/`selectForExport` fuer alle Kandidaten ein vollstaendiges Bild
    /// haben: alle Fenster, die geprueft werden (effektives UND die
    /// vermuteten urspruenglichen), plus Rand. `nil` ohne Kandidaten.
    public static func queryRange(
        for candidates: [HealthWorkoutCandidate]
    ) -> (start: Date, end: Date)? {
        var earliest: Date?
        var latest: Date?
        for candidate in candidates {
            let effective = effectiveWindow(
                startTime: candidate.startTime,
                endTime: candidate.endTime,
                durationMinutes: candidate.durationMinutes
            )
            for window in [effective] + recordedWindows(of: candidate, effective: effective) {
                earliest = min(earliest ?? window.start, window.start)
                latest = max(latest ?? window.end, window.end)
            }
        }
        guard let earliest, let latest else { return nil }
        return (
            start: earliest.addingTimeInterval(-queryMarginSeconds),
            end: latest.addingTimeInterval(queryMarginSeconds)
        )
    }

    /// Entscheidet fuer den Export ALLE Kandidaten (Reihenfolge = Prioritaet,
    /// neueste zuerst) und beantwortet dabei, was als "schon in Health" gilt:
    /// NUR eine Ueberlappung mit echten Health-Workouts. Eine Session, die nur
    /// eine ebenfalls GEPLANTE ueberlappt, wird weder geschrieben noch als
    /// "schon in Health" gemeldet (`deferred`): Ob die andere je geschrieben wird
    /// (Kategorie abgewaehlt, Abbruch, Fehler), steht noch nicht fest.
    public static func selectForExport(
        _ candidates: [HealthWorkoutCandidate],
        enabledCategories: Set<HealthWorkoutCategory>,
        healthWindows: [(start: Date, end: Date)],
        ownWindows: [(start: Date, end: Date)],
        now: Date
    ) -> HealthExportSelection {
        var selection = HealthExportSelection()
        var planned: [(start: Date, end: Date)] = []
        for (index, candidate) in candidates.enumerated() {
            let decision = decide(
                candidate,
                enabledCategories: enabledCategories,
                existingWindows: healthWindows,
                ownWindows: ownWindows,
                now: now
            )
            switch decision {
            case .write(let plan):
                if ExternalWorkoutDedup.overlapsExisting(
                    sampleStart: plan.start,
                    sampleEnd: plan.end,
                    existingWindows: planned
                ) {
                    selection.deferred += 1
                    continue
                }
                selection.toWrite.append(HealthExportSelection.Planned(index: index, plan: plan))
                planned.append((start: plan.start, end: plan.end))
            case .skip(.alreadyInHealth):
                selection.alreadyInHealth.append(index)
            case .skip(let reason):
                if reason.isNotExportable { selection.notExportable += 1 }
            }
        }
        return selection
    }

    // MARK: Klassifikation

    /// Prioritaetsreihenfolge bei Gleichstand (Dauer bzw. Distanz).
    private enum Group: Int, CaseIterable {
        case running = 0
        case cycling = 1
        case walking = 2
        case mixed = 3
    }

    private struct Modality {
        let group: Group
        /// `nil` = unbekannt.
        let indoor: Bool?
    }

    private struct Stats {
        var seconds = 0
        var distanceKm = 0.0
        /// Nur Logs mit Distanz UND Dauer: Grundlage der Pace. Distanz und Zeit
        /// duerfen nicht aus verschiedenen Logs gemischt werden (ein Log nur mit
        /// km, ein anderes nur mit Dauer ergaebe sonst eine erfundene Pace).
        var pairedKm = 0.0
        var pairedSeconds = 0
        var indoorVotes: [Bool] = []
    }

    /// Cardio-Bibliothekseintraege -> Gruppe/Ort, ueber den `localizationKey`
    /// (stabil gegen Umbenennungen). Ein neuer Cardio-Eintrag OHNE Zeile hier
    /// faellt auf `mixedCardio` — der Vollstaendigkeitstest
    /// (`testEveryLibraryCardioExerciseHasAnExplicitMapping`) schlaegt dann an.
    private static let modalityByKey: [String: Modality] = [
        "exercise.name.run":             Modality(group: .running, indoor: false),
        "exercise.name.easyRun":         Modality(group: .running, indoor: false),
        "exercise.name.longRun":         Modality(group: .running, indoor: false),
        "exercise.name.intervals":       Modality(group: .running, indoor: nil),
        "exercise.name.runInterval":     Modality(group: .running, indoor: nil),
        "exercise.name.treadmill":       Modality(group: .running, indoor: true),
        "exercise.name.warmupWalk":      Modality(group: .walking, indoor: nil),
        "exercise.name.cycling":         Modality(group: .cycling, indoor: false),
        "exercise.name.cyclingInterval": Modality(group: .cycling, indoor: nil),
        "exercise.name.stationaryBike":  Modality(group: .cycling, indoor: true),
        "exercise.name.rowingMachine":   Modality(group: .mixed, indoor: true),
        "exercise.name.elliptical":      Modality(group: .mixed, indoor: true),
        "exercise.name.stairStepper":    Modality(group: .mixed, indoor: true),
        "exercise.name.swimming":        Modality(group: .mixed, indoor: nil),
    ]

    private static let keyByName: [String: String] = {
        var map: [String: String] = [:]
        for spec in ExerciseLibraryData.all where spec.isCardio {
            if let key = spec.localizationKey, map[spec.name] == nil {
                map[spec.name] = key
            }
        }
        return map
    }()

    /// Hat dieser System-Name eine ausdrueckliche Zuordnung (statt des
    /// `mixedCardio`-Fallbacks)?
    public static func hasExplicitModality(forExerciseName name: String) -> Bool {
        guard let key = keyByName[name] else { return false }
        return modalityByKey[key] != nil
    }

    private static func modality(for log: HealthWorkoutLogInput) -> Modality {
        let byName: Modality? = keyByName[log.exerciseName].flatMap { modalityByKey[$0] }
        // Das vom Nutzer gesetzte Geraet schlaegt den Namen.
        switch log.equipment {
        case .none:
            return byName ?? Modality(group: .mixed, indoor: nil)
        case .treadmill:
            if let byName, byName.group == .running || byName.group == .walking {
                return Modality(group: byName.group, indoor: true)
            }
            return Modality(group: .running, indoor: true)
        case .ergometer:
            return Modality(group: .cycling, indoor: true)
        case .bikeOutdoor:
            return Modality(group: .cycling, indoor: false)
        case .rowingMachine:
            return Modality(group: .mixed, indoor: true)
        }
    }

    private static func makePlan(
        _ candidate: HealthWorkoutCandidate,
        window: (start: Date, end: Date)
    ) -> HealthWorkoutPlan {
        let sessionSeconds = window.end.timeIntervalSince(window.start)
        let cardioLogs = candidate.logs.filter { $0.isCardio }
        let strengthLogs = candidate.logs.filter { !$0.isCardio }

        let isCardioSession: Bool
        if candidate.hasTimeFormat {
            // Zeitformate haben nie Logs: nur der (noch vorhandene) Tag verraet,
            // ob er ausschliesslich aus Cardio-Uebungen bestand (Lauf-/Rad-
            // Intervall, Rudern, ...).
            isCardioSession = candidate.dayIsAllCardio == true
        } else if cardioLogs.isEmpty {
            isCardioSession = false
        } else if strengthLogs.isEmpty {
            isCardioSession = true
        } else {
            // Mischtag: Cardio, wenn er mindestens die Haelfte der Zeit ausmacht.
            let cardioSeconds = cardioLogs.reduce(0) { $0 + max($1.durationSeconds ?? 0, 0) }
            isCardioSession = Double(cardioSeconds) >= sessionSeconds * 0.5
        }

        guard isCardioSession else {
            return HealthWorkoutPlan(
                activity: .strength,
                start: window.start,
                end: window.end,
                isIndoor: true,
                totalSets: candidate.totalSets,
                totalVolumeKg: candidate.totalVolumeKg
            )
        }
        return makeCardioPlan(cardioLogs: cardioLogs, window: window)
    }

    private static func makeCardioPlan(
        cardioLogs: [HealthWorkoutLogInput],
        window: (start: Date, end: Date)
    ) -> HealthWorkoutPlan {
        var stats: [Group: Stats] = [:]
        for log in cardioLogs {
            let logModality = Self.modality(for: log)
            var entry = stats[logModality.group] ?? Stats()
            let seconds = max(log.durationSeconds ?? 0, 0)
            entry.seconds += seconds
            if let distance = log.distanceKm, distance.isFinite, distance > 0 {
                entry.distanceKm += distance
                if seconds > 0 {
                    entry.pairedKm += distance
                    entry.pairedSeconds += seconds
                }
            }
            if let indoor = logModality.indoor { entry.indoorVotes.append(indoor) }
            stats[logModality.group] = entry
        }

        // Gewinner: groesste Gesamtdauer. Die Dauer zaehlt aber nur, wenn sie fuer
        // ALLE Gruppen mit Distanz vorliegt; sonst (z.B. ein Einlaufen nur mit
        // Dauer neben einem Lauf nur mit km) waere sie nicht vergleichbar, und die
        // groesste Distanz entscheidet. Es sei denn, eine Gruppe fuellt mit ihrer
        // Dauer allein mindestens die Haelfte der Session: Dann ist sie die
        // Haupt-Aktivitaet (60 min Rad plus ein 0,3-km-Spaziergang ohne Dauer ist
        // Radfahren). Gleichstand entscheidet die feste Prioritaetsreihenfolge —
        // Live-Pfad und Export kommen so immer zum selben Ergebnis.
        let sessionSeconds = window.end.timeIntervalSince(window.start)
        let durationIsComparable = stats.values.contains { $0.seconds > 0 }
            && (stats.values.allSatisfy { $0.seconds > 0 || $0.distanceKm == 0 }
                || stats.values.contains { Double($0.seconds) >= sessionSeconds * 0.5 })
        var winner: Group?
        var best = -1.0
        for group in Group.allCases {
            guard let entry = stats[group] else { continue }
            let score = durationIsComparable ? Double(entry.seconds) : entry.distanceKm
            if score > best {
                best = score
                winner = group
            }
        }

        let activity: HealthWorkoutActivity
        switch winner ?? Group.mixed {
        case .running: activity = .running
        case .cycling: activity = .cycling
        case .walking: activity = .walking
        case .mixed: activity = .mixedCardio
        }

        // Ort: nur, wenn alle bekannten Angaben der Gewinner-Gruppe uebereinstimmen.
        var isIndoor: Bool?
        if let winner, let votes = stats[winner]?.indoorVotes, let first = votes.first,
           votes.allSatisfy({ $0 == first }) {
            isIndoor = first
        }

        // Distanz nur fuer Laufen/Gehen (`distanceWalkingRunning`); Lauf- und
        // Geh-Logs (Einlaufen) gehoeren zusammen.
        var distanceKm: Double?
        var pace: Double?
        if activity == .running || activity == .walking {
            let walkRun = [Group.running, Group.walking].compactMap { stats[$0] }
            let km = walkRun.reduce(0.0) { $0 + $1.distanceKm }
            if km > 0 {
                distanceKm = km
                pace = PaceCalculator.minutesPerKm(
                    distanceKm: walkRun.reduce(0.0) { $0 + $1.pairedKm },
                    durationSeconds: walkRun.reduce(0) { $0 + $1.pairedSeconds }
                )
            }
        }

        let totalKm = stats.values.reduce(0.0) { $0 + $1.distanceKm }

        return HealthWorkoutPlan(
            activity: activity,
            start: window.start,
            end: window.end,
            isIndoor: isIndoor,
            distanceKm: distanceKm,
            averagePaceMinPerKm: pace,
            totalDistanceKm: totalKm > 0 ? totalKm : nil
        )
    }
}
