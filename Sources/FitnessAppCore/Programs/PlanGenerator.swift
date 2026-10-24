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
/// ein Compile-Fehler. `Candidate.name`/`DaySpec.name` bleiben deshalb
/// hartcodierte deutsche Strings - exakt die gleiche Konvention wie jede
/// `DaySpec(name: "Push A", ...)` in `ProgramTemplates.swift`, und weiterhin
/// der Fallback falls ein Key mal nicht aufloest.
///
/// DEL-247: zusaetzlich traegt jede `DaySpec` einen ZUSAMMENGESETZTEN
/// `localizationKey` im Format `"key1[·key2[&key3]][#rawSuffix]"` -
/// `DaySpec+DisplayName`/`TrainingDay+DisplayName` in FitnessAppUI loesen
/// das auf (Details dort) und geben generierten Tagen damit dieselbe
/// live-sprachumschaltende Anzeige wie Template-Tagen (`plan.day.*`).
/// Wiederverwendet bewusst bereits existierende Keys (`planBuilder.type.*`,
/// `day_type.*`, `muscle.core`) statt neuer Duplikate - nur die drei
/// Lauf-Zonen-Titel (`RunZone.localizationKey`) sind echte neue Keys, weil
/// dafuer noch nichts existierte. Die einzige weitere echte Lokalisierung
/// bleibt `Result.explanationKey` - eine KEY-STRING, die FitnessAppUI (wo
/// `.module` existiert) aufloest. Fuer Schritt-1 der Wizard-UI
/// (Trainingsart-AUSWAHL) siehe `TrainingTypeKind.titleKey` in
/// `PlanGeneratorInput.swift`.
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

            /// P2.4: expliziter Public-Init. Ein `public struct` mit nur
            /// `public let`-Feldern bekommt in Swift TROTZDEM nur einen
            /// `internal` Memberwise-Init synthetisiert — ohne diesen Init
            /// koennte `FitnessAppUI` (z.B. `PlanBuilderView`, um ein
            /// Ergebnis aus einem bearbeiteten `PlanDraft` zu rekonstruieren,
            /// siehe dortige Doku) keinen `GeneratedDay` bauen. Rein additiv,
            /// identische Parameter-Reihenfolge/-Labels wie der bisherige
            /// interne Konstruktionsaufruf in `generate(from:shuffle:)` —
            /// kein Verhaltensunterschied fuer bestehende Aufrufer.
            public init(spec: DaySpec, loadLevel: PlanLoadLevel) {
                self.spec = spec
                self.loadLevel = loadLevel
            }
        }
        public let days: [GeneratedDay]
        /// Lokalisierungs-KEY (nicht aufgeloester Text!) fuer den einen Satz,
        /// der die nicht-triviale Umordnungs-Entscheidung erklaert - `nil`
        /// wenn die Reihenfolge trivial ist (z.B. nur eine Trainingsart
        /// gewaehlt). Core kann den Key nicht selbst aufloesen (kein
        /// `Bundle.module` hier) - der Aufrufer (Wizard-UI in FitnessAppUI)
        /// macht `String(localized: String.LocalizationValue(key), bundle: .module)`.
        public let explanationKey: String?

        /// P2.4: siehe `GeneratedDay.init` oben — derselbe Grund.
        public init(days: [GeneratedDay], explanationKey: String? = nil) {
            self.days = days
            self.explanationKey = explanationKey
        }
    }

    /// Ein noch nicht platzierter, aber inhaltlich fertiger Tag samt
    /// geschaetzter Belastung fuer die Reihenfolge-Regel.
    private struct Candidate {
        var name: String
        /// DEL-247: siehe Datei-Kommentar. `nil` bleibt moeglich, falls ein
        /// kuenftiger Candidate-Erzeuger mal keinen Key beitragen kann -
        /// `DaySpec.localizationKey` ist schon lange optional.
        var localizationKey: String?
        let exercises: [ExerciseSpec]
        let timeFormat: WorkoutTimeFormat?
        let timeCapMinutes: Int?
        let hardness: Double
    }

    /// `shuffle`: Bugfix (Nutzer-Feedback) - `generate(from:)` war komplett
    /// deterministisch, "Neu rechnen" im Wizard (Schritt 3) rief dieselbe
    /// Funktion mit demselben `input` erneut auf und produzierte daher
    /// IMMER exakt dasselbe Ergebnis, obwohl der User eine Alternative
    /// erwartet. `shuffle: true` mischt den nach Muskelgruppe gruppierten
    /// Uebungs-Pool in `strengthCandidates`/`kettlebellEmomCandidate`
    /// (siehe dort) VOR der Auswahl, sodass verschiedene Uebungen aus der
    /// Bibliothek gezogen werden - Tagesanzahl, Cardio-Zonen-Zyklus und die
    /// "keine zwei harten Cardio-Tage direkt hintereinander"-Regel bleiben
    /// unveraendert (Cardio hat pro Zone ohnehin nur eine feste Uebung,
    /// dort gibt es nichts zu mischen). Default `false` haelt jeden
    /// bestehenden Aufrufer (u.a. `PlanGeneratorInstantiator.recalculate`,
    /// alle bisherigen Tests) exakt beim alten, deterministischen Verhalten.
    public static func generate(from input: PlanGeneratorInput, shuffle: Bool = false) -> Result {
        var candidates: [Candidate] = []
        for selection in input.selections {
            if selection.kind.isCardio {
                candidates.append(contentsOf: cardioCandidates(for: selection))
            } else {
                candidates.append(contentsOf: strengthCandidates(for: selection, shuffle: shuffle))
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
                    localizationKey: candidate.localizationKey,
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

    /// P3.3 (Audit "Gezielte Alternativen statt globalem Shuffle"): bis zu
    /// `count` unterschiedliche, komplette Alternativ-Inhalte fuer GENAU
    /// EINEN Tag - ersetzt den bisherigen "Neu rechnen"-Button
    /// (`generate(shuffle: true)`), der die GESAMTE Woche neu wuerfelte und
    /// damit jede manuelle Fixierung/Aenderung an ANDEREN Tagen unsichtbar
    /// mit wegspuelte (Abnahme B04 "keine stillen Verluste bei manuellen
    /// Aenderungen + Neuberechnung"). Diese Funktion ruehrt ausschliesslich
    /// `day` an - der Aufrufer (`PlanDraft.replaceContent`) ersetzt gezielt
    /// NUR diesen einen Tag, alle anderen bleiben unveraendert.
    public enum AlternativeGenerationResult: Sendable, Equatable {
        case alternatives([DaySpec])
        /// Dieser Tag ist Cardio (`cardioCandidates` liefert pro Zone nur
        /// EINE feste Uebung - es gibt nichts zu variieren) ODER passt zu
        /// keiner der `input.selections` mehr (z.B. weil sich Schritt 1/2
        /// seither geaendert haben). Ein eigener Fall statt einer leeren
        /// `[DaySpec]`-Liste, damit der Aufrufer einen SICHTBAREN Konflikt
        /// zeigen kann statt einer stillen "zufaellig keine Alternativen"-
        /// Deutung (Abnahme B05 "sichtbarer Konflikt statt abgeschnittener
        /// Einheiten").
        case noAlternativesAvailable
    }

    public static func targetedAlternatives(
        for day: DaySpec,
        input: PlanGeneratorInput,
        count: Int = 3
    ) -> AlternativeGenerationResult {
        guard !day.exercises.isEmpty, !day.exercises.contains(where: \.isCardio) else {
            return .noAlternativesAvailable
        }
        guard let selection = matchingSelection(for: day, in: input.selections) else {
            return .noAlternativesAvailable
        }

        var seenExerciseSets: Set<Set<String>> = [Set(day.exercises.map(\.name))]
        var alternatives: [DaySpec] = []
        var attempts = 0
        let maxAttempts = count * 8

        while alternatives.count < count, attempts < maxAttempts {
            attempts += 1
            let candidates = strengthCandidates(for: selection, shuffle: true)
            guard let picked = candidates.randomElement() else { break }
            let pickedNames = Set(picked.exercises.map(\.name))
            guard !pickedNames.isEmpty, !seenExerciseSets.contains(pickedNames) else { continue }
            seenExerciseSets.insert(pickedNames)
            alternatives.append(DaySpec(
                name: picked.name,
                localizationKey: picked.localizationKey,
                type: day.type,
                sequenceIndex: day.sequenceIndex,
                exercises: picked.exercises,
                timeFormat: picked.timeFormat,
                timeCapMinutes: picked.timeCapMinutes
            ))
        }

        return alternatives.isEmpty ? .noAlternativesAvailable : .alternatives(alternatives)
    }

    /// Rekonstruiert, aus welcher `PlanGeneratorTypeSelection` ein bereits
    /// generierter Tag stammt - ueber Equipment-Pool-Zugehoerigkeit statt
    /// einer gespeicherten Referenz (es gibt bislang keine; `DaySpec`
    /// traegt keine Herkunfts-ID, siehe Datei-Kommentar). Zuverlaessig, weil
    /// jede Kraft-Art einen EIGENEN, disjunkten Equipment-Filter hat
    /// (`TrainingTypeKind.equipmentFilter`) - ein Tag mit ausschliesslich
    /// Kurzhantel-Uebungen kann nur aus der `.dumbbell`-Auswahl stammen.
    private static func matchingSelection(
        for day: DaySpec,
        in selections: [PlanGeneratorTypeSelection]
    ) -> PlanGeneratorTypeSelection? {
        let dayExerciseNames = Set(day.exercises.map(\.name))
        guard !dayExerciseNames.isEmpty else { return nil }
        for selection in selections {
            guard let equipment = selection.kind.equipmentFilter else { continue }
            let poolNames = Set(
                ExerciseLibraryData.all
                    .filter { $0.equipment == equipment && !$0.isCardio }
                    .map(\.name)
            )
            if dayExerciseNames.isSubset(of: poolNames) {
                return selection
            }
        }
        return nil
    }

    // MARK: - Strength candidates

    private static func strengthCandidates(for selection: PlanGeneratorTypeSelection, shuffle: Bool) -> [Candidate] {
        guard let equipment = selection.kind.equipmentFilter else { return [] }
        let allowedDifficulties = difficultiesAtOrBelow(selection.experience)
        let pool = ExerciseLibraryData.all.filter {
            $0.equipment == equipment && !$0.isCardio && allowedDifficulties.contains($0.difficultyLevel)
        }
        guard !pool.isEmpty else { return [] }

        let byMuscle = groupedByMuscle(pool, shuffle: shuffle)
        let muscleOrder = MuscleGroup.allCases
        let exerciseCount = max(3, min(7, selection.sessionDurationMinutes / 7))
        let (sets, repsMin, repsMax, restSeconds) = strengthVolume(for: selection.experience)
        let kindLabel = germanTypeLabel(selection.kind)
        let kindKey = selection.kind.titleKey

        var result: [Candidate] = []
        for dayIndex in 0..<selection.daysPerWeek {
            // README 2.20: letzter Tag einer >=3-taegigen Kettlebell-Auswahl
            // wird zum EMOM-Finisher - passt zum bereits gebauten CrossFit/
            // Kettlebell-Vorlagen-Stil (README 2.9) statt jede Trainingsart
            // gleich zu behandeln.
            if selection.kind == .kettlebell, selection.daysPerWeek >= 3, dayIndex == selection.daysPerWeek - 1 {
                result.append(kettlebellEmomCandidate(
                    pool: pool, muscleOrder: muscleOrder, kindLabel: kindLabel, kindKey: kindKey,
                    sessionDurationMinutes: selection.sessionDurationMinutes,
                    shuffle: shuffle
                ))
                continue
            }

            var exercises: [ExerciseSpec] = []
            var pickedMuscles: [MuscleGroup] = []
            var hardness = 0.0
            var muscleCursor = dayIndex
            var guardCount = 0
            // Bugfix (Epic #3.3): tracks how many exercises have already been
            // taken from EACH muscle this day. Previously every revisit to a
            // muscle re-read `group[dayIndex % group.count]` — the exact same
            // index every time, since `dayIndex` never changes within this
            // loop — so a muscle contributed AT MOST one exercise per day no
            // matter how many eligible candidates it actually had, capping
            // `exercises.count` at the number of distinct muscle groups with
            // any exercise at all. That ceiling can be far below
            // `exerciseCount`: e.g. Kettlebell/Anfaenger has 9 exercises
            // across only 4 muscle groups (4 Schulter-Uebungen alone) — a
            // 100-Minuten-Plan (exerciseCount=7) still only ever got 4,
            // regardless of the chosen duration. Tracking a per-muscle offset
            // lets a second (and third, ...) pass pick the NEXT distinct
            // exercise from a muscle that still has one, once every muscle
            // has had its first pick — duration keeps mattering wherever the
            // library actually has the variety to support it, with no
            // artificial padding where it doesn't (a muscle with only one
            // eligible exercise is simply skipped on later passes).
            var picksByMuscle: [MuscleGroup: Int] = [:]
            let maxPicksForAnyMuscle = byMuscle.values.map(\.count).max() ?? 1
            while exercises.count < exerciseCount, guardCount < muscleOrder.count * maxPicksForAnyMuscle {
                defer { guardCount += 1 }
                let muscle = muscleOrder[muscleCursor % muscleOrder.count]
                muscleCursor += 1
                guard let group = byMuscle[muscle], !group.isEmpty else { continue }
                let picks = picksByMuscle[muscle, default: 0]
                guard picks < group.count else { continue }
                let spec = group[(dayIndex + picks) % group.count]
                picksByMuscle[muscle] = picks + 1
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
                localizationKey: "\(kindKey)·\(muscleFocusKey(pickedMuscles, dayIndex: dayIndex))",
                exercises: exercises,
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: hardness
            ))
        }
        disambiguateDuplicateNames(&result)
        return result
    }

    /// README 2.21: bei mehreren Tagen derselben Trainingsart kann
    /// `muscleFocusLabel` denselben Titel liefern, obwohl sich die Uebungen
    /// unterscheiden - mit dem Kettlebell-Pool z.B. an zwei Tagen je "Push &
    /// Pull" (`group[dayIndex % group.count]` waehlt andere Uebungen, aber
    /// dieselben ERSTEN ZWEI Muskel-Kategorien). Haengt bei einer Kollision
    /// den Tages-Buchstaben an, exakt wie `ProgramTemplates` es mit
    /// "Ganzkoerper A"/"Ganzkoerper B" tut.
    private static func disambiguateDuplicateNames(_ candidates: inout [Candidate]) {
        var totalCounts: [String: Int] = [:]
        for candidate in candidates {
            totalCounts[candidate.name, default: 0] += 1
        }
        var nextLetterIndex: [String: Int] = [:]
        for index in candidates.indices {
            let baseName = candidates[index].name
            guard totalCounts[baseName, default: 0] > 1 else { continue }
            let letterIndex = nextLetterIndex[baseName, default: 0]
            nextLetterIndex[baseName] = letterIndex + 1
            let suffix = disambiguationSuffix(for: letterIndex)
            candidates[index].name = "\(baseName) \(suffix)"
            // DEL-247: derselbe rohe (nicht zu lokalisierende) Buchstaben-
            // Suffix wird ans `#`-Ende des Keys gehaengt - siehe
            // Datei-Kommentar fuer das Format. Kollidiert nie mit dem
            // "Ganzkoerper N"-Fallback-Suffix aus `muscleFocusKey`, weil
            // dessen Kandidaten durch die eindeutige Zahl bereits garantiert
            // nicht in `totalCounts` kollidieren.
            if let key = candidates[index].localizationKey {
                candidates[index].localizationKey = "\(key)#\(suffix)"
            }
        }
    }

    /// A, B, C, ... Z, dann 27, 28, ... - kein Aufrufer erreicht heute mehr
    /// als 6 Duplikate desselben Namens (UI-Cap: max. 7 Tage/Woche insgesamt,
    /// siehe Audit-Notiz), aber `UInt8(65 + index)` wuerde ab Index 26
    /// entweder Muell-Zeichen liefern oder ueberlaufen und trapen - diese
    /// Grenze gehoert in die oeffentliche Core-API, nicht nur in die UI.
    private static func disambiguationSuffix(for index: Int) -> String {
        guard index < 26 else { return "\(index + 1)" }
        return String(UnicodeScalar(UInt8(65 + index)))
    }

    /// EMOM-Ganzkoerper-Finisher aus dem gleichen gefilterten Pool - vier
    /// Uebungen, je eine Minute. Deckel skaliert mit der vom User gewaehlten
    /// Session-Dauer (Bugfix, Audit - vorher fix 20 Minuten, ignorierte die
    /// Eingabe komplett), auf einen sinnvollen EMOM-Bereich geklemmt: unter
    /// 10 Minuten lohnt sich die Rotation kaum, ueber 30 waere ein
    /// "Finisher" kein Finisher mehr.
    private static func kettlebellEmomCandidate(
        pool: [ExerciseTemplateSpec],
        muscleOrder: [MuscleGroup],
        kindLabel: String,
        kindKey: String,
        sessionDurationMinutes: Int,
        shuffle: Bool
    ) -> Candidate {
        let byMuscle = groupedByMuscle(pool, shuffle: shuffle)
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
            localizationKey: "\(kindKey)·day_type.full_body",
            exercises: exercises,
            timeFormat: .emom,
            timeCapMinutes: min(30, max(10, sessionDurationMinutes)),
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

    /// Bugfix (Nutzer-Feedback): gemeinsamer Gruppierungs-Helfer fuer
    /// `strengthCandidates`/`kettlebellEmomCandidate` - mischt jede
    /// Muskelgruppen-Liste GENAU EINMAL (nicht bei jedem einzelnen Zugriff),
    /// bevor `dayIndex % group.count` daraus auswaehlt. Ein Mischen pro
    /// Zugriff wuerde die bestehende Garantie zerstoeren, dass
    /// aufeinanderfolgende Tage derselben Trainingsart verschiedene
    /// Uebungen bekommen (`dayIndex % group.count` waehlt sonst aus einem
    /// bei jedem Aufruf neu gemischten Array, zwei Tage koennten dann
    /// zufaellig dieselbe Uebung treffen).
    private static func groupedByMuscle(
        _ pool: [ExerciseTemplateSpec],
        shuffle: Bool
    ) -> [MuscleGroup: [ExerciseTemplateSpec]] {
        let grouped = Dictionary(grouping: pool, by: \.primaryMuscle)
        return shuffle ? grouped.mapValues { $0.shuffled() } : grouped
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
        case .machine:    return "Maschine"
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
    ///
    /// DEL-247: `germanLabel`/`localizationKey` sitzen bewusst NEBENEINANDER
    /// in derselben Switch-Anweisung (statt in zwei getrennten Funktionen
    /// wie zuvor) - der Compiler erzwingt so Exhaustivitaet fuer BEIDE
    /// Repraesentationen gleichzeitig, sie koennen nicht mehr auseinander-
    /// laufen. `localizationKey`s wiederverwenden bewusst bereits
    /// existierende Keys (`day_type.push/.pull/.legs`, `muscle.core` - siehe
    /// `DomainEnums+Localization.swift` in FitnessAppUI) statt neuer
    /// Duplikate, weil ihre DE-Werte exakt den hier hartcodierten Woertern
    /// entsprechen.
    private enum MuscleCategory: Equatable {
        case push, pull, legs, core

        init(_ muscle: MuscleGroup) {
            switch muscle {
            case .chest, .shoulders, .triceps: self = .push
            case .back, .biceps:               self = .pull
            case .quads, .hamstrings, .glutes, .calves: self = .legs
            case .core:                        self = .core
            }
        }

        var germanLabel: String {
            switch self {
            case .push: return "Push"
            case .pull: return "Pull"
            case .legs: return "Beine"
            case .core: return "Core"
            }
        }

        var localizationKey: String {
            switch self {
            case .push: return "day_type.push"
            case .pull: return "day_type.pull"
            case .legs: return "day_type.legs"
            case .core: return "muscle.core"
            }
        }
    }

    /// Erste zwei UNTERSCHIEDLICHEN Muskel-Kategorien aus den tatsaechlich
    /// gewaehlten Uebungen, in Auftrittsreihenfolge - gemeinsame Auswahl-
    /// Logik fuer `muscleFocusLabel`/`muscleFocusKey` (DEL-247), die nur
    /// noch unterschiedlich FORMATIEREN muessen, nicht mehr getrennt
    /// AUSWAEHLEN. Leer, wenn nichts Eindeutiges herauskommt (leerer Tag
    /// oder mehr als zwei Kategorien gleichmaessig vertreten) - beide
    /// Aufrufer behandeln das als "Ganzkoerper"-Fallback.
    private static func pickedFocusCategories(_ muscles: [MuscleGroup]) -> [MuscleCategory] {
        var seen: [MuscleCategory] = []
        for muscle in muscles {
            let category = MuscleCategory(muscle)
            if !seen.contains(category) { seen.append(category) }
            if seen.count == 2 { break }
        }
        return seen
    }

    private static func muscleFocusLabel(_ muscles: [MuscleGroup], dayIndex: Int) -> String {
        let categories = pickedFocusCategories(muscles)
        guard !categories.isEmpty else {
            return "\(fullBodyGermanLabel) \(dayIndex + 1)"
        }
        return categories.map(\.germanLabel).joined(separator: " & ")
    }

    /// DEL-247: Key-Pendant zu `muscleFocusLabel` - siehe Datei-Kommentar
    /// fuer das `key1&key2`-Format. Der "Ganzkoerper N"-Fallback kodiert
    /// die Zahl als rohes `#`-Suffix (nicht zu lokalisieren - Ziffern
    /// brauchen in DE/EN/TR keine Uebersetzung).
    private static func muscleFocusKey(_ muscles: [MuscleGroup], dayIndex: Int) -> String {
        let categories = pickedFocusCategories(muscles)
        guard !categories.isEmpty else {
            return "day_type.full_body#\(dayIndex + 1)"
        }
        return categories.map(\.localizationKey).joined(separator: "&")
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

        /// DEL-247: echte NEUE Keys (Namespace `planBuilder.day.*`) - anders
        /// als die Trainingsart-/Muskel-Fokus-Keys gibt es fuer diese drei
        /// Lauf-Zonen-Titel noch keine wiederverwendbare Entsprechung.
        /// Bewusst UNABHAENGIG von `exercise.name.intervals` etc., obwohl der
        /// DE-Wert fuer `.interval` zufaellig identisch ist - Tages-Titel und
        /// Uebungs-Name sind semantisch getrennte Konzepte (siehe
        /// `exerciseName` oben: `.tempo` nutzt "Long Run" als Uebung, aber
        /// "Tempolauf" als Tages-Titel), die nicht ueber einen Key gekoppelt
        /// sein sollten.
        var localizationKey: String {
            switch self {
            case .easy:     return "planBuilder.day.runEasy"
            case .tempo:    return "planBuilder.day.runTempo"
            case .interval: return "planBuilder.day.runInterval"
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
        // README 2.35: Zeitformat-Wahl im Wizard gilt nur fuer Laufen/
        // Radfahren (die vier Kraft-Arten haben keinen Format-Picker in
        // Schritt 1, siehe PlanBuilderView) - baut hier komplett anders als
        // die Zonen-/Einzel-Cardio-Logik unten, deshalb ein frueher Abzweig.
        if let format = selection.timeFormat {
            return timedCardioCandidates(for: selection, format: format)
        }

        let durationFactor = Double(selection.sessionDurationMinutes) / 30.0

        guard selection.kind == .running else {
            // Radfahren: das Dokument beschreibt die fehlende Typologie
            // explizit nur fuers Laufen - Radfahren bleibt bewusst eine
            // einzelne, gleichfoermige Cardio-Einheit ohne Zonen. Die
            // TITEL muessen trotzdem eindeutig sein (Bugfix, Audit) - sonst
            // stehen z.B. 3 identisch "Radfahren" benannte Tage
            // ununterscheidbar in der Plan-Uebersicht.
            let title = germanTypeLabel(.cycling)
            let titleKey = TrainingTypeKind.cycling.titleKey
            var result = (0..<selection.daysPerWeek).map { _ in
                Candidate(
                    name: title,
                    localizationKey: titleKey,
                    exercises: [ExerciseSpec(
                        name: "Radfahren (outdoor)",
                        sets: 1, repsMin: 0, repsMax: 0,
                        isCardio: true,
                        targetDurationMinutes: selection.sessionDurationMinutes,
                        enduranceSportKind: .cycling
                    )],
                    timeFormat: nil,
                    timeCapMinutes: nil,
                    hardness: 20 * durationFactor
                )
            }
            disambiguateDuplicateNames(&result)
            return result
        }

        // README 2.18/2.20: Reihenfolge so gewaehlt, dass bei genau zwei
        // Tagen niemals zwei harte Einheiten (Tempo/Intervall) zusammen
        // herauskommen - "ruhig" deckt die Luecke.
        let cycle: [RunZone] = [.easy, .interval, .tempo]

        var result = (0..<selection.daysPerWeek).map { dayIndex in
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
                    targetDistanceKm: 0.4,
                    enduranceSportKind: .running
                )
            case .easy, .tempo:
                exercise = ExerciseSpec(
                    name: zone.exerciseName,
                    sets: 1, repsMin: 0, repsMax: 0,
                    isCardio: true,
                    targetDurationMinutes: selection.sessionDurationMinutes,
                    enduranceSportKind: .running
                )
            }
            return Candidate(
                name: title,
                localizationKey: zone.localizationKey,
                exercises: [exercise],
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: zone.baseHardness * durationFactor
            )
        }
        // Bugfix (Audit): der 3-Zonen-Zyklus wiederholt sich ab Tag 4 (z.B.
        // 5x/Woche -> Tag 1 und 4 beide "Ruhiger Lauf") - ohne Disambiguierung
        // stehen dann zwei identisch benannte Lauf-Tage in der Uebersicht.
        disambiguateDuplicateNames(&result)
        return result
    }

    /// README 2.35: Laufen/Radfahren mit gewaehltem Zeitformat (AMRAP/EMOM/
    /// Auf Zeit) bekommen eine einzelne, wiederholte Cardio-Uebung statt
    /// mehrerer Kraft-Uebungen pro Runde - "dieselbe Mechanik, nur mit einer
    /// Uebung" (README-Formulierung). Referenziert bewusst die eigenen
    /// "Lauf-Intervall"/"Rad-Intervall"-Library-Eintraege statt "Easy Run"/
    /// "Radfahren (outdoor)" wiederzuverwenden: nur die neuen Eintraege sind
    /// `isTimeBased` (siehe `ExerciseLibraryData`), also zeigt
    /// `timedFormatTargetLabel` in FitnessAppUI korrekt "N Sek." statt "N
    /// Wdh." - exakt derselbe Anzeige-Pfad, den Bodyweight-Holds (Plank im
    /// EMOM) schon heute benutzen, hier nur mit einer Lauf-/Rad-Bewegung.
    ///
    /// `sets` traegt die Rundenzahl nur bei `.forTime` (dort zaehlt der
    /// Player abgehakte Boxen, siehe `ForTimePlayerView.totalBoxes`) - AMRAP/
    /// EMOM zaehlen ihre Runden/Minuten selbst live, `sets: 1` matcht damit
    /// exakt das bestehende Cindy-Muster (dort tragen AMRAP-/EMOM-Uebungen
    /// ebenfalls immer `sets: 1`).
    private static func timedCardioCandidates(
        for selection: PlanGeneratorTypeSelection,
        format: WorkoutTimeFormat
    ) -> [Candidate] {
        let exerciseName = selection.kind == .running ? "Lauf-Intervall" : "Rad-Intervall"
        // 40 Sek. Arbeit passt in jedes der drei Formate: laesst bei EMOM
        // Puffer bis zur vollen Minute, ist bei AMRAP ein uebliches
        // Intervall-Mass, und ergibt bei Auf Zeit (5 Runden) ein kurzes,
        // finisher-artiges Gesamtpensum - gleiche Groessenordnung wie
        // `kettlebellEmomCandidate`s Finisher-Charakter oben.
        let roundSeconds = 40
        let sets: Int
        let timeCapMinutes: Int?
        switch format {
        case .amrap, .emom:
            sets = 1
            timeCapMinutes = min(30, max(10, selection.sessionDurationMinutes))
        case .forTime, .circuit, .enduranceIntervals:
            // `.circuit`/`.enduranceIntervals` erreichen diese Funktion in
            // der Praxis nie - der Struktur-Picker fuer Laufen/Radfahren in
            // PlanBuilderView bietet bewusst nur AMRAP/EMOM/Auf-Zeit an (ein
            // rundenbasierter Zirkel mit Pause deckt sich fuer Cardio schon
            // mit dem bestehenden `RunZone.interval`-Muster, siehe
            // `cardioCandidates` oben; `.enduranceIntervals` [Paket 2] ist
            // eine eigene, noch ungebaute Struktur mit eigenen
            // `TrainingDay.endurance*`-Feldern statt diesem Generator-Pfad).
            // Faellt trotzdem auf dieselbe Behandlung wie Auf-Zeit zurueck
            // statt eines nicht-exhaustiven Crashs, falls der Typ je anders
            // erreicht wird.
            sets = 5
            timeCapMinutes = nil
        }

        var result = (0..<selection.daysPerWeek).map { _ in
            Candidate(
                name: germanTypeLabel(selection.kind),
                localizationKey: selection.kind.titleKey,
                exercises: [ExerciseSpec(
                    name: exerciseName,
                    sets: sets, repsMin: roundSeconds, repsMax: roundSeconds,
                    isCardio: true,
                    enduranceSportKind: selection.kind
                )],
                timeFormat: format,
                timeCapMinutes: timeCapMinutes,
                hardness: 30 * (Double(selection.sessionDurationMinutes) / 30.0)
            )
        }
        // Gleicher Bugfix wie beim uniformen Radfahren-Zweig oben: mehrere
        // Tage derselben Trainingsart brauchen eindeutige Titel.
        disambiguateDuplicateNames(&result)
        return result
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
