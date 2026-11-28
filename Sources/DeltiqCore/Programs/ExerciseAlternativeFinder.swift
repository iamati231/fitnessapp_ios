import Foundation

/// UI-Ticket ("Plan Bauen Schritt 3: Template-Layout und Übungsalternativen"):
/// findet geeignete Ersatz-Uebungen fuer EINE Uebung in Schritt 3 des
/// Plan-Builders - gleiche Muskelgruppe, nur Gerätearten aus dem vom Nutzer
/// gewaehlten Pool, nicht schwieriger als die gewaehlte Erfahrungsstufe.
/// Reine, deterministische Abfrage auf der bestehenden `ExerciseLibraryData` -
/// erzeugt keinen neuen Plan-Inhalt, liefert nur Kandidaten zur Auswahl.
///
/// Bewusst GETRENNT von `ExerciseSubstitutionEngine` (Smart-Onboarding-Epic):
/// jene ersetzt automatisch, regelbasiert, genau EINE Uebung pro fehlende
/// Ausstattung (kuratierter Regelkatalog, kein Auswahl-Dialog). Hier geht es
/// um das Gegenteil - der Nutzer sieht MEHRERE passende Kandidaten und waehlt
/// selbst, unabhaengig davon, ob die Original-Uebung "fehlt" oder nicht.
public enum ExerciseAlternativeFinder {

    /// `limit`: kurze, auf einen Blick erfassbare Liste (gleiche
    /// Groessenordnung wie `PlanGenerator.targetedAlternatives`s
    /// `count: Int = 3`-Default fuer ganze Alternativ-Tage - hier
    /// grosszuegiger, weil jede Kandidaten-Uebung bereits einzeln gefiltert
    /// ist statt kompletter Tage).
    ///
    /// Liefert IMMER `[]` fuer eine Cardio-Uebung oder eine unbekannte
    /// Uebung (kein Katalog-Eintrag) - "Trainingsart" bleibt damit gewahrt
    /// (nie eine Kraft- gegen eine Cardio-Uebung tauschen, oder umgekehrt).
    public static func alternatives(
        for exerciseName: String,
        equipmentPool: Set<Equipment>,
        maxExperience: DifficultyLevel,
        limit: Int = 8
    ) -> [ExerciseTemplateSpec] {
        guard let original = ExerciseLibraryData.byName[exerciseName], !original.isCardio else { return [] }
        let allowedDifficulties = difficultiesAtOrBelow(maxExperience)
        return Array(
            ExerciseLibraryData.all
                .filter {
                    $0.name != exerciseName
                        && $0.primaryMuscle == original.primaryMuscle
                        && equipmentPool.contains($0.equipment)
                        && !$0.isCardio
                        && allowedDifficulties.contains($0.difficultyLevel)
                }
                .sorted { $0.name < $1.name }
                .prefix(limit)
        )
    }

    /// Dasselbe Prinzip wie `PlanGenerator.difficultiesAtOrBelow` - bewusst
    /// separat gehalten statt dessen private Funktion freizugeben, damit
    /// diese reine Abfrage unabhaengig von der Generator-internen API bleibt
    /// (siehe Datei-Kommentar).
    private static func difficultiesAtOrBelow(_ level: DifficultyLevel) -> Set<DifficultyLevel> {
        switch level {
        case .beginner:     return [.beginner]
        case .intermediate: return [.beginner, .intermediate]
        case .advanced:     return [.beginner, .intermediate, .advanced]
        }
    }

    /// Issue #51 — Template-Adoption-Pfad: ersetzt eine durch `BaselineBands`
    /// gesperrte Uebung durch eine zugaengliche Alternative.
    /// Gibt `spec` unveraendert zurueck (non-nil) wenn die Uebung nicht in der
    /// Library steht, kein `baselineMinBand` gesetzt ist, oder das User-Band
    /// die Schranke erfuellt — d.h. kein Konflikt vorliegt.
    /// Gibt `nil` zurueck wenn die Uebung gesperrt IST und kein zugaenglicher
    /// Ersatz gefunden werden konnte — kontrollierter Konflikt, die Uebung
    /// wird vom Aufrufer uebersprungen (kein stilles Zurueckgeben einer
    /// nachweislich ungeeigneten Uebung).
    public static func baselineSubstitute(
        _ spec: ExerciseSpec,
        bands: BaselineBands,
        equipmentPool: Set<Equipment>,
        profile: UserEquipmentProfile? = nil
    ) -> ExerciseSpec? {
        guard let libSpec = ExerciseLibraryData.byName[spec.name],
              let minBand = libSpec.effectiveBaselineMinBand,
              !bands.band(for: libSpec.primaryMuscle).meetsMinimum(minBand)
        else { return spec }
        // Issue #51 Punkt 2: die Schwierigkeits-Obergrenze fuer den Ersatz
        // richtet sich NICHT mehr nur nach `libSpec.difficultyLevel` (der
        // ORIGINAL-Uebung) — dieser wert sagt nichts ueber das tatsaechliche
        // Leistungsniveau DIESES Nutzers aus. Stattdessen der konservativere
        // (niedrigere) von zwei Deckeln: was das gemessene Baseline-Band fuer
        // diese Muskelgruppe zulaesst, UND was fuer die Original-Uebung schon
        // vorgesehen war (`intersection` zweier `difficultiesAtOrBelow`-Mengen
        // — nie laxer als die engere der beiden).
        let bandCap = maxDifficultyLevel(for: bands.band(for: libSpec.primaryMuscle))
        let allowedDifficulties = difficultiesAtOrBelow(bandCap)
            .intersection(difficultiesAtOrBelow(libSpec.difficultyLevel))
        // Pass 1: same muscle group, equipment in pool, baseline-accessible
        if let alt = findAccessibleAlternative(muscle: libSpec.primaryMuscle,
                                               excluding: spec.name,
                                               bands: bands,
                                               equipment: equipmentPool,
                                               allowedDifficulties: allowedDifficulties,
                                               movementPattern: libSpec.movementPattern,
                                               profile: profile) {
            return adjustedSpec(replacing: spec, with: alt)
        }
        // Pass 2: strict bodyweight fallback — only exercises needing NO physical item
        if let alt = findAccessibleAlternative(muscle: libSpec.primaryMuscle,
                                               excluding: spec.name,
                                               bands: bands,
                                               equipment: [.bodyweight],
                                               strictBodyweight: true,
                                               allowedDifficulties: allowedDifficulties,
                                               movementPattern: libSpec.movementPattern,
                                               profile: profile) {
            return adjustedSpec(replacing: spec, with: alt)
        }
        return nil
    }

    /// Issue #51 Punkt 2: konservative Zuordnung gemessenes Baseline-Band →
    /// hoechste zulaessige `DifficultyLevel` fuer eine Ersatz-Uebung.
    /// `.unknown` faellt auf denselben Wert wie `.low` — dieselbe Konvention
    /// wie `BaselineBand.meetsMinimum`.
    private static func maxDifficultyLevel(for band: BaselineBand) -> DifficultyLevel {
        switch band {
        case .veryLow, .low, .unknown: return .beginner
        case .moderate:                return .intermediate
        case .high:                    return .advanced
        }
    }

    private static func findAccessibleAlternative(
        muscle: MuscleGroup,
        excluding name: String,
        bands: BaselineBands,
        equipment: Set<Equipment>,
        strictBodyweight: Bool = false,
        allowedDifficulties: Set<DifficultyLevel>? = nil,
        movementPattern: MovementPattern? = nil,
        profile: UserEquipmentProfile? = nil
    ) -> ExerciseTemplateSpec? {
        return ExerciseLibraryData.all.first {
            $0.name != name
                && $0.primaryMuscle == muscle
                && equipment.contains($0.equipment)
                && !$0.isCardio
                && ($0.effectiveBaselineMinBand == nil
                    || bands.band(for: $0.primaryMuscle).meetsMinimum($0.effectiveBaselineMinBand!))
                && (!strictBodyweight
                    // nil = noch nicht annotiert, NIE "keine Anforderung"
                    // (ExerciseTemplateSpec.swift equipmentRequirement-Doku)
                    || ($0.equipmentRequirement.map(\.requiresNoPhysicalItem) ?? false))
                && (allowedDifficulties == nil || allowedDifficulties!.contains($0.difficultyLevel))
                && (movementPattern == nil || $0.movementPattern == movementPattern)
                && (profile == nil
                    || ($0.equipmentRequirement != nil && $0.equipmentRequirement!.evaluate(against: profile!).isSatisfied))
        }
    }

    /// UI-Ticket Punkt 3: Saetze/Wdh./Pause der ORIGINAL-Uebung duerfen nicht
    /// blind uebernommen werden, wenn sie fuer die Ersatz-Uebung nicht passen.
    /// Saetze und Pause bleiben fuer jede Ersatz-Uebung gueltig (reine
    /// Volumen-/Erholungs-Vorgaben, unabhaengig vom Uebungstyp) - nur wenn
    /// `isTimeBased` zwischen Original und Ersatz WECHSELT (Wiederholungs-
    /// vs. Halte-Zeit-Uebung; `repsMin`/`repsMax` tragen bei zeitbasierten
    /// Uebungen Sekunden statt Wiederholungen, siehe
    /// `ExerciseSpec+DisplayName.swift`s `detailLine`-Kommentar), wird der
    /// Wiederholungs-/Sekunden-Bereich auf einen sinnvollen Default der
    /// Ziel-Uebung zurueckgesetzt statt die alte Zahl falsch umzudeuten.
    public static func adjustedSpec(replacing original: ExerciseSpec, with target: ExerciseTemplateSpec) -> ExerciseSpec {
        let originalIsTimeBased = ExerciseLibraryData.byName[original.name]?.isTimeBased ?? false
        let (repsMin, repsMax): (Int, Int)
        if target.isTimeBased == originalIsTimeBased {
            (repsMin, repsMax) = (original.repsMin, original.repsMax)
        } else {
            // Kein Datenpunkt aus der Original-Uebung passt hier sinnvoll -
            // ein neutraler, oft genutzter Default fuer den jeweiligen Typ
            // (30s Halte-Zeit bzw. 8-12 Wiederholungen).
            (repsMin, repsMax) = target.isTimeBased ? (30, 30) : (8, 12)
        }
        return ExerciseSpec(
            name: target.name,
            sets: original.sets,
            repsMin: repsMin,
            repsMax: repsMax,
            restSeconds: original.restSeconds,
            targetRir: original.targetRir,
            isCardio: original.isCardio,
            role: original.role
        )
    }
}
