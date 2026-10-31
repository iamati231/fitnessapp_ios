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
