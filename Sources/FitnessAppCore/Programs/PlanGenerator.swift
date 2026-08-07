import Foundation

/// README 2.20 "Plan bauen": rechnet aus mehreren Trainingsarten eine
/// Wochen-Struktur, statt sie aus einer festen `ProgramTemplate` zu
/// schneiden. Lebt bewusst in Core (kein SwiftData) - gleiches Prinzip wie
/// `PlanMatchmaker`: reine, ueberall testbare Logik, die erst am Ende
/// `[DaySpec]` ausgibt und von `ProgramInstantiator` materialisiert wird.
///
/// **Bewusste v1-Vereinfachung:** die Belastungs-Schaetzung orientiert sich
/// an denselben DEL-098-Faktoren, die `DayAnalyzer` fuer fertige Tage
/// verwendet, ist aber eine eigene, einfachere Rechnung - `DayAnalyzer`
/// selbst arbeitet auf persistierten `Exercise`-Objekten (SwiftData) und
/// laesst sich nicht ohne Weiteres auf noch nicht existierende Kandidaten-
/// Tage anwenden. Ziel hier ist "hart vs. leicht grob richtig einordnen",
/// nicht numerische Parität mit `DayAnalyzer`.
///
/// **`ExerciseSpec.name`-Werte sind bewusst die exakten Library-Strings**
/// ("Easy Run", "Intervalle", ...), keine eigenen Erfindungen - nur so
/// findet `ProgramInstantiator`s namensbasierter Library-Abgleich die
/// bereits getunten DEL-098-Faktoren wieder (sonst landen generische
/// Isolations-Defaults im Plan, siehe `ProgramInstantiator.swift`).
///
/// **Keine Lokalisierung in diesem Typ:** `FitnessAppCore` deklariert in
/// `Package.swift` keine `resources:` - es gibt hier gar kein
/// `Bundle.module`, jeder `String(localized:bundle: .module)`-Aufruf waere
/// ein Compile-Fehler. Erzeugte Tages-/Plan-Namen sind deshalb bewusst
/// hartcodierte deutsche Strings, exakt die gleiche Konvention wie jede
/// `DaySpec(name: "Push A", ...)` in `ProgramTemplates.swift` - Anzeige in
/// EN/TR faellt fuer generierte Tage auf diesen deutschen String zurueck
/// (kein `localizationKey`, da der Name dynamisch aus mehreren Teilen
/// zusammengesetzt ist, nicht ein fixer Katalog-Eintrag). Die einzige
/// echte Lokalisierung ist `Result.explanationKey` - eine KEY-STRING, die
/// FitnessAppUI (wo `.module` existiert) aufloest. Fuer Schritt-1 der
/// Wizard-UI (Trainingsart-AUSWAHL) siehe stattdessen
/// `TrainingTypeKind.titleKey` in `PlanGeneratorInput.swift`.
public enum PlanGenerator {

    public struct Result: Sendable {
        /// Ein platzierter Tag samt seiner Belastungs-Einordnung fuer die
        /// Step-3-Kapsel. `loadLevel` ist bewusst RELATIV zu dieser einen
        /// generierten Woche (siehe `loadLevels(for:)`) - Kraft- und Cardio-
        /// Haerte sind unterschiedlich skaliert (Kraft summiert ueber alle
        /// Uebungen eines Tages, Cardio ueber die Zonen-Basiswerte) und waeren
        /// als universeller Absolutwert nicht sinnvoll vergleichbar. Das
        /// passt zum README-2.20-Wortlaut: "die Belastung wird verteilt und
        /// die Verteilung erklaert" - es geht um die Position in DIESER
        /// Woche, nicht um einen App-weiten Massstab.
        public struct GeneratedDay: Sendable {
            public let spec: DaySpec
            public let loadLevel: PlanLoadLevel
        }
        public let days: [GeneratedDay]
        /// Lokalisierungs-KEY (nicht aufgeloester Text!) fuer den einen Satz,
        /// der die nicht-triviale Umordnungs-Entscheidung erklaert - `nil`
        /// wenn die Reihenfolge trivial ist (z.B. nur eine Trainingsart
        /// gewaehlt). Core kann den Key nicht selbst aufloesen (kein
        /// `Bundle.module` hier) - der Aufrufer (Wizard-UI in FitnessAppUI)
        /// macht `String(localized: String.LocalizationValue(key), bundle: .module)`.
        public let explanationKey: String?
    }

    /// Ein noch nicht platzierter, aber inhaltlich fertiger Tag samt
    /// geschaetzter Belastung fuer die Reihenfolge-Regel.
    private struct Candidate {
        let name: String
        let exercises: [ExerciseSpec]
        let timeFormat: WorkoutTimeFormat?
        let timeCapMinutes: Int?
        let hardness: Double
    }

    public static func generate(from input: PlanGeneratorInput) -> Result {
        var candidates: [Candidate] = []
        for selection in input.selections {
            if selection.kind.isCardio {
                candidates.append(contentsOf: cardioCandidates(for: selection))
            } else {
                candidates.append(contentsOf: strengthCandidates(for: selection))
            }
        }

        guard !candidates.isEmpty else {
            return Result(days: [], explanationKey: nil)
        }

        let ordered = spreadByHardness(candidates)
        let levels = loadLevels(for: ordered.map(\.hardness))
        let days = ordered.enumerated().map { index, candidate in
            Result.GeneratedDay(
                spec: DaySpec(
                    name: candidate.name,
                    type: .fullBody,
                    sequenceIndex: index + 1,
                    exercises: candidate.exercises,
                    timeFormat: candidate.timeFormat,
                    timeCapMinutes: candidate.timeCapMinutes
                ),
                loadLevel: levels[index]
            )
        }

        let explanationKey = input.selections.count > 1 && ordered.count > 2
            ? "planBuilder.result.explanation.spread"
            : nil

        return Result(days: days, explanationKey: explanationKey)
    }

    // MARK: - Strength candidates

    private static func strengthCandidates(for selection: PlanGeneratorTypeSelection) -> [Candidate] {
        guard let equipment = selection.kind.equipmentFilter else { return [] }
        let allowedDifficulties = difficultiesAtOrBelow(selection.experience)
        let pool = ExerciseLibraryData.all.filter {
            $0.equipment == equipment && !$0.isCardio && allowedDifficulties.contains($0.difficultyLevel)
        }
        guard !pool.isEmpty else { return [] }

        let byMuscle = Dictionary(grouping: pool, by: \.primaryMuscle)
        let muscleOrder = MuscleGroup.allCases
        let exerciseCount = max(3, min(7, selection.sessionDurationMinutes / 7))
        let (sets, repsMin, repsMax, restSeconds) = strengthVolume(for: selection.experience)
        let kindLabel = germanTypeLabel(selection.kind)

        var result: [Candidate] = []
        for dayIndex in 0..<selection.daysPerWeek {
            // README 2.20: letzter Tag einer >=3-taegigen Kettlebell-Auswahl
            // wird zum EMOM-Finisher - passt zum bereits gebauten CrossFit/
            // Kettlebell-Vorlagen-Stil (README 2.9) statt jede Trainingsart
            // gleich zu behandeln.
            if selection.kind == .kettlebell, selection.daysPerWeek >= 3, dayIndex == selection.daysPerWeek - 1 {
                result.append(kettlebellEmomCandidate(pool: pool, muscleOrder: muscleOrder, kindLabel: kindLabel))
                continue
            }

            var exercises: [ExerciseSpec] = []
            var pickedMuscles: [MuscleGroup] = []
            var hardness = 0.0
            var muscleCursor = dayIndex
            var guardCount = 0
            while exercises.count < exerciseCount, guardCount < muscleOrder.count * 3 {
                defer { guardCount += 1 }
                let muscle = muscleOrder[muscleCursor % muscleOrder.count]
                muscleCursor += 1
                guard let group = byMuscle[muscle], !group.isEmpty else { continue }
                let spec = group[dayIndex % group.count]
                if exercises.contains(where: { $0.name == spec.name }) { continue }
                exercises.append(ExerciseSpec(
                    name: spec.name,
                    sets: sets,
                    repsMin: repsMin,
                    repsMax: repsMax,
                    restSeconds: restSeconds
                ))
                pickedMuscles.append(muscle)
                hardness += strengthHardness(spec, sets: sets, experience: selection.experience)
            }

            result.append(Candidate(
                name: "\(kindLabel) · \(muscleFocusLabel(pickedMuscles, dayIndex: dayIndex))",
                exercises: exercises,
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: hardness
            ))
        }
        return result
    }

    /// EMOM-Ganzkoerper-Finisher aus dem gleichen gefilterten Pool - vier
    /// Uebungen, je eine Minute, Deckel 20 Minuten (deckt sich mit
    /// `kettlebellAdvanced`s bereits gebautem Metcon-Tag, README 2.9).
    private static func kettlebellEmomCandidate(
        pool: [ExerciseTemplateSpec],
        muscleOrder: [MuscleGroup],
        kindLabel: String
    ) -> Candidate {
        let byMuscle = Dictionary(grouping: pool, by: \.primaryMuscle)
        var exercises: [ExerciseSpec] = []
        var hardness = 0.0
        var muscleCursor = 0
        var guardCount = 0
        while exercises.count < 4, guardCount < muscleOrder.count * 2 {
            defer { guardCount += 1 }
            let muscle = muscleOrder[muscleCursor % muscleOrder.count]
            muscleCursor += 1
            guard let group = byMuscle[muscle], let spec = group.first else { continue }
            if exercises.contains(where: { $0.name == spec.name }) { continue }
            exercises.append(ExerciseSpec(name: spec.name, sets: 1, repsMin: 12, repsMax: 12))
            hardness += strengthHardness(spec, sets: 3, experience: .intermediate)
        }
        return Candidate(
            name: "\(kindLabel) · \(fullBodyGermanLabel)",
            exercises: exercises,
            timeFormat: .emom,
            timeCapMinutes: 20,
            // README 2.18/DayAnalyzer-Konvention: EMOM wird gegenueber
            // reinen Kraft-Score-Punkten eine Stufe milder eingeordnet
            // (die Pause steckt in der Minute) - hier grob mit 0.85 nachgebildet.
            hardness: hardness * 0.85
        )
    }

    private static func strengthHardness(
        _ spec: ExerciseTemplateSpec,
        sets: Int,
        experience: DifficultyLevel
    ) -> Double {
        let intensity: Double
        switch experience {
        case .beginner:     intensity = 0.9
        case .intermediate: intensity = 1.0
        case .advanced:     intensity = 1.1
        }
        let perSet = spec.systemicFatigueFactor * 0.5 + spec.cnsDemandFactor * 0.3 + spec.axialLoadFactor * 0.2
        return Double(sets) * perSet * intensity * 10.0
    }

    private static func strengthVolume(for experience: DifficultyLevel) -> (sets: Int, repsMin: Int, repsMax: Int, restSeconds: Int) {
        switch experience {
        case .beginner:     return (3, 10, 12, 90)
        case .intermediate: return (3, 8, 12, 90)
        case .advanced:     return (4, 6, 10, 100)
        }
    }

    private static func difficultiesAtOrBelow(_ level: DifficultyLevel) -> Set<DifficultyLevel> {
        switch level {
        case .beginner:     return [.beginner]
        case .intermediate: return [.beginner, .intermediate]
        case .advanced:     return [.beginner, .intermediate, .advanced]
        }
    }

    /// Deutsches Anker-Wort fuer die Tages-Titel-Komposition - siehe
    /// Datei-Kommentar oben ("Keine Lokalisierung in diesem Typ"). Fuer die
    /// Wizard-Auswahl-Labels in Schritt 1 siehe stattdessen
    /// `TrainingTypeKind.titleKey` (`PlanGeneratorInput.swift`), das
    /// FitnessAppUI aufloest. "Koerpergewicht" statt "Eigengewicht", damit
    /// generierte Tages-Titel exakt denselben Begriff wie der
    /// Equipment-Picker verwenden (`equipment.bodyweight`s DE-Wert).
    private static func germanTypeLabel(_ kind: TrainingTypeKind) -> String {
        switch kind {
        case .barbell:    return "Langhantel"
        case .dumbbell:   return "Kurzhantel"
        case .kettlebell: return "Kettlebell"
        case .bodyweight: return "Körpergewicht"
        case .running:    return "Laufen"
        case .cycling:    return "Radfahren"
        }
    }

    /// Hartcodiertes "Ganzkörper" fuer die Tages-Titel-Komposition - exakt
    /// die gleiche Schreibweise wie jede `DaySpec(name: "Ganzkörper A", ...)`
    /// in `ProgramTemplates.swift`.
    private static let fullBodyGermanLabel = "Ganzkörper"

    /// Grobe, kurze Muskel-Kategorie fuer den Tages-Titel ("Kettlebell ·
    /// Beine & Core") - keine Praezisions-Klassifikation, nur Kosmetik.
    /// "Push"/"Pull"/"Core" sind im Deutschen dieser App bereits etablierte
    /// Gym-Fachbegriffe (siehe z.B. `DaySpec(name: "Push & Core", ...)` in
    /// `ProgramTemplates.swift` und den DE-Wert von `muscle.core`).
    private static func muscleCategoryGermanLabel(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest, .shoulders, .triceps: return "Push"
        case .back, .biceps:               return "Pull"
        case .quads, .hamstrings, .glutes, .calves: return "Beine"
        case .core:                        return "Core"
        }
    }

    /// Erste zwei UNTERSCHIEDLICHEN Muskel-Kategorien aus den tatsaechlich
    /// gewaehlten Uebungen, in Auftrittsreihenfolge. Faellt auf
    /// "Ganzkoerper" zurueck, wenn nichts Eindeutiges herauskommt (leerer
    /// Tag oder mehr als zwei Kategorien gleichmaessig vertreten).
    private static func muscleFocusLabel(_ muscles: [MuscleGroup], dayIndex: Int) -> String {
        var seen: [String] = []
        for muscle in muscles {
            let label = muscleCategoryGermanLabel(muscle)
            if !seen.contains(label) { seen.append(label) }
            if seen.count == 2 { break }
        }
        guard !seen.isEmpty else {
            return "\(fullBodyGermanLabel) \(dayIndex + 1)"
        }
        return seen.joined(separator: " & ")
    }

    // MARK: - Cardio candidates

    /// README 2.20: "der erste Baustein, der wirklich fehlt" - eine
    /// Typologie fuer Lauf-Einheiten. Bewusst nur intern in diesem
    /// Generator, keine neuen Felder auf `ExerciseSpec`/`Exercise`: eine
    /// Zone entscheidet lediglich Tages-Titel, welche existierende
    /// Library-Uebung ("Easy Run"/"Long Run"/"Intervalle") gewaehlt wird,
    /// Ziel-Dauer und Haerte zum Erzeugungs-Zeitpunkt - sie muss danach
    /// nirgendwo mehr gelesen werden. "Long Run" steht fuer die Tempo-
    /// Zone ein: die Library hat keine eigene Tempo-Lauf-Uebung, aber
    /// "Long Run"s DEL-098-Faktoren (0.70/0.35 systemisch/CNS) liegen
    /// bereits sinnvoll zwischen "Easy Run" (0.50/0.25) und "Intervalle"
    /// (0.75/0.55).
    private enum RunZone {
        case easy, tempo, interval

        var exerciseName: String {
            switch self {
            case .easy:     return "Easy Run"
            case .tempo:    return "Long Run"
            case .interval: return "Intervalle"
            }
        }

        /// Deutsches Anker-Wort fuer den Tages-Titel - README 2.20 benutzt
        /// selbst schon "ruhig / Tempo / Intervall" fuer die drei Zonen.
        var germanLabel: String {
            switch self {
            case .easy:     return "Ruhiger Lauf"
            case .tempo:    return "Tempolauf"
            case .interval: return "Intervalle"
            }
        }

        var baseHardness: Double {
            switch self {
            case .easy:     return 15
            case .tempo:    return 30
            case .interval: return 45
            }
        }
    }

    private static func cardioCandidates(for selection: PlanGeneratorTypeSelection) -> [Candidate] {
        let durationFactor = Double(selection.sessionDurationMinutes) / 30.0

        guard selection.kind == .running else {
            // Radfahren: das Dokument beschreibt die fehlende Typologie
            // explizit nur fuers Laufen - Radfahren bleibt bewusst eine
            // einzelne, gleichfoermige Cardio-Einheit ohne Zonen.
            let title = germanTypeLabel(.cycling)
            return (0..<selection.daysPerWeek).map { _ in
                Candidate(
                    name: title,
                    exercises: [ExerciseSpec(
                        name: "Radfahren (outdoor)",
                        sets: 1, repsMin: 0, repsMax: 0,
                        isCardio: true,
                        targetDurationMinutes: selection.sessionDurationMinutes
                    )],
                    timeFormat: nil,
                    timeCapMinutes: nil,
                    hardness: 20 * durationFactor
                )
            }
        }

        // README 2.18/2.20: Reihenfolge so gewaehlt, dass bei genau zwei
        // Tagen niemals zwei harte Einheiten (Tempo/Intervall) zusammen
        // herauskommen - "ruhig" deckt die Luecke.
        let cycle: [RunZone] = [.easy, .interval, .tempo]

        return (0..<selection.daysPerWeek).map { dayIndex in
            let zone = cycle[dayIndex % cycle.count]
            let title = zone.germanLabel
            let exercise: ExerciseSpec
            switch zone {
            case .interval:
                exercise = ExerciseSpec(
                    name: zone.exerciseName,
                    sets: 6, repsMin: 1, repsMax: 1,
                    restSeconds: 90,
                    isCardio: true,
                    targetDistanceKm: 0.4
                )
            case .easy, .tempo:
                exercise = ExerciseSpec(
                    name: zone.exerciseName,
                    sets: 1, repsMin: 0, repsMax: 0,
                    isCardio: true,
                    targetDurationMinutes: selection.sessionDurationMinutes
                )
            }
            return Candidate(
                name: title,
                exercises: [exercise],
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: zone.baseHardness * durationFactor
            )
        }
    }

    // MARK: - Ordering

    /// Sortiert absteigend nach Haerte, dann abwechselnd vom haertesten und
    /// leichtesten Ende genommen ("Zick-Zack-Merge") - verteilt die
    /// anstrengendsten Einheiten ueber die Woche, statt sie zu clustern.
    private static func spreadByHardness(_ candidates: [Candidate]) -> [Candidate] {
        let sorted = candidates.sorted { $0.hardness > $1.hardness }
        guard sorted.count > 2 else { return sorted }

        var result: [Candidate] = []
        var left = 0
        var right = sorted.count - 1
        var takeFromLeft = true
        while left <= right {
            if takeFromLeft {
                result.append(sorted[left])
                left += 1
            } else {
                result.append(sorted[right])
                right -= 1
            }
            takeFromLeft.toggle()
        }
        return result
    }

    /// Bildet jede Haerte auf ihre Position innerhalb der Spannweite DIESES
    /// Ergebnisses ab (0...1) und rastert in vier Viertel. Ohne Spannweite
    /// (0 oder 1 Kandidat, oder alle exakt gleich haart) gibt es nichts zu
    /// verteilen - dann bekommt jeder Tag `.medium` als neutralen Default,
    /// statt eine willkuerliche Grenze zu erfinden.
    private static func loadLevels(for hardnessValues: [Double]) -> [PlanLoadLevel] {
        guard let low = hardnessValues.min(), let high = hardnessValues.max(), high > low else {
            return hardnessValues.map { _ in .medium }
        }
        return hardnessValues.map { value in
            switch (value - low) / (high - low) {
            case ..<0.25: return .easy
            case ..<0.5:  return .medium
            case ..<0.75: return .hard
            default:      return .tough
            }
        }
    }
}

/// README 2.20 Step 3: die vier Belastungs-Kapsel-Stufen ("locker / mittel /
/// schwer / hart"). Siehe `PlanGenerator.Result.GeneratedDay` fuer die
/// bewusst relative (nicht absolute) Berechnung.
public enum PlanLoadLevel: String, Codable, Sendable, CaseIterable {
    case easy, medium, hard, tough

    public var titleKey: String {
        switch self {
        case .easy:   return "planBuilder.load.easy"
        case .medium: return "planBuilder.load.medium"
        case .hard:   return "planBuilder.load.hard"
        case .tough:  return "planBuilder.load.tough"
        }
    }
}
