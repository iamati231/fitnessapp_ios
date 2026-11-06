#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// reine Analyse, welche Tage eines bestehenden, AKTIVEN `TrainingPlan`
/// eine Coach-Aktivierung automatisch anpassen darf, und ob die
/// vorhandene Bein-Kraftarbeit zum neuen Laufziel passt. Keine
/// SwiftData-Mutation hier - nur Lesen/Klassifizieren, siehe
/// `PlanGeneratorInstantiator.applyCoachCardioAdjustment` fuer die
/// eigentliche Anwendung.
public enum RunCoachPlanAdjustment {

    /// Fuenf Faelle laut Produktvorgabe: passende Bein-Arbeit vorhanden
    /// (`unchanged`), ueberwiegend Oberkoerper (`addSmallAddition`),
    /// bereits umfangreich (`redistribute`), wenig Zeit/Platz
    /// (`replaceForTime`), keine tragfaehige Kombination (`conflict`).
    ///
    /// Wichtige Grenze (Paket 1, Leitplanke 5): diese Klassifikation
    /// erkennt nur, ob Bein-Muskelgruppen ÜBERHAUPT in ausreichendem
    /// Satzvolumen vorkommen (ueber die bestehende, fuer Hypertrophie-
    /// Volumensteuerung gedachte `MuscleVolumeBucket`-Taxonomie, DEL-082).
    /// Sie bewertet NICHT, ob dieses Volumen fuer den LAUFBEZOGENEN Zweck
    /// (z. B. Laufoekonomie/Verletzungspraevention) tatsaechlich
    /// ausreichend ist - dafuer existiert keine belastbare Regel im Projekt,
    /// und es wird hier bewusst KEINE neue, unbelegte Schwelle dafuer
    /// erfunden. "Vorhanden" ≠ "fuer den Laufcoach-Zweck ausreichend".
    public enum LegWorkRecommendation: Equatable, Sendable {
        case unchanged
        case addSmallAddition
        case redistribute
        case replaceForTime
        case conflict
    }

    /// Welche Cardio-Tage eine Zielaenderung automatisch anpassen darf.
    public enum CardioAvailability: Equatable, Sendable {
        /// Mindestens ein Cardio-Tag ist anfassbar - enthaelt dessen IDs in
        /// Plan-Reihenfolge (fuer `applyCoachCardioAdjustment`s `zip`).
        case ready([PersistentIdentifier])
        /// Der Plan hat entweder keinen Cardio-Tag, oder jeder vorhandene
        /// ist geschuetzt (manuell/editiert/mit Historie) - keiner darf
        /// automatisch angepasst werden. Der Aufrufer bietet in diesem Fall
        /// nur "als neuen Plan erstellen"/"beibehalten" an, keine
        /// In-Place-Anpassung.
        case noEligibleCardioDay
        /// Kein aktiver Plan vorhanden.
        case noActivePlan
    }

    public struct Analysis: Equatable, Sendable {
        public let cardioAvailability: CardioAvailability
        public let legWork: LegWorkRecommendation
        /// Phase B (Laufcoaching Dual-Path, Task 5): unabhaengig von
        /// `cardioAvailability` - ein Plan kann GLEICHZEITIG einen
        /// ersetzbaren Cardio-Tag (`.ready`) UND einfuegbare Ruhetage haben,
        /// das eine schliesst das andere nicht aus. Siehe
        /// `eligibleRestDaysForInsertion`.
        public let insertableRestDays: [PersistentIdentifier]
        /// Wochentage (1-7), die im Plan noch voellig leer sind (kein
        /// `TrainingDay` mit diesem `weekday`) - Fallback-Slots fuer den
        /// Fall, dass weder anfassbare Cardio-Tage noch
        /// `isAutoFilledPlaceholder`-Ruhetage verfuegbar sind (z.B. nach
        /// manuellem Loeschen aller Ruhetage).
        public let freeWeekdaysForNewDays: [Int]
        /// Bugfix ("Bestehenden Trainingsplan bei Zieländerung flexibel
        /// umstrukturieren"): bisher anfassbare Krafttage, die das NEUE Ziel
        /// nicht mehr braucht (siehe `convertibleStrengthDays` unten) -
        /// bereits in `cardioAvailability`s `.ready`-IDs enthalten, hier
        /// zusaetzlich einzeln sichtbar fuer eine ehrliche Vorher/Nachher-
        /// Anzeige (welche Tage sind Kraft- statt Lauf-Ersetzungen).
        public let convertibleStrengthDays: [PersistentIdentifier]
    }

    /// Bein-Muskelgruppen laut bestehender `MuscleGroup`-Taxonomie
    /// (`Sources/DeltiqCore/Domain/DomainEnums.swift`) - keine neue
    /// Klassifikation.
    private static let legMuscleGroups: Set<MuscleGroup> = [.quads, .hamstrings, .glutes, .calves]

    /// A12/Architektur-Antwort (Paket 1): ein Tag darf automatisch
    /// angepasst werden, wenn er vom Wizard erzeugt UND seither
    /// unveraendert ist (`generationFingerprint == currentContentFingerprint`,
    /// exakt dasselbe Prinzip wie `PlanGeneratorInstantiator.recalculate`)
    /// UND keine Trainingshistorie traegt. Manuell hinzugefuegte Tage
    /// (kein Fingerprint) oder seither editierte Tage (Fingerprint weicht
    /// ab) sind IMMER geschuetzt.
    ///
    /// Wichtige Grenze (Paket 1, Leitplanke 4): "Fingerprint stimmt
    /// ueberein" heisst nur "seit der Erzeugung NICHT NACHWEISLICH
    /// editiert" - NICHT "der Nutzer wollte diesen Tag bewusst austauschbar
    /// lassen". Ein gespeicherter `TrainingPlan`/`TrainingDay` kennt (anders
    /// als `PlanDraft.isContentFixed`/`isPositionFixed`, die NUR in der
    /// Wizard-Entwurfsschicht vor dem ersten Speichern existieren) KEIN
    /// explizites Fixierungs-Konzept. Diese Funktion behauptet daher
    /// ausdruecklich KEINE Fixierungs-Unterstuetzung, die es auf einem
    /// bereits aktiven Plan real nicht gibt - "nicht erfasst" (kein
    /// Fixierungsfeld vorhanden) ist NICHT dasselbe wie "frei ersetzbar".
    /// Der Fingerprint-Vergleich bleibt der einzige verfuegbare,
    /// nachweisbare Signal-Kandidat fuer "wurde seither angefasst".
    /// Korrektur (Paket 1, Teil 3): `TrainingDay.type == .cardio` reicht
    /// NICHT aus, um einen Cardio-Tag zu erkennen - `PlanGenerator.generate`
    /// (der Ziel-gefuehrte "Plan bauen"-Pfad, genau der, den dieses Paket
    /// anspricht) stempelt JEDEN generierten Tag hartcodiert mit
    /// `type: .fullBody`, unabhaengig vom Inhalt (verifiziert durch Lesen
    /// von `PlanGenerator.generate`). `.cardio` als Tagestyp wird
    /// ausschliesslich von den kuratierten `ProgramTemplates` gesetzt. Die
    /// tatsaechlich verlaessliche Erkennung laeuft daher ueber die
    /// Uebungen selbst (`Exercise.isCardio`, von `PlanGenerator` fuer jede
    /// Lauf-/Rad-Uebung gesetzt) - deckt BEIDE Ursprungspfade ab.
    private static func isCardioDay(_ day: TrainingDay) -> Bool {
        if day.type == .cardio { return true }
        let exercises = day.activeExercises
        return !exercises.isEmpty && exercises.allSatisfy(\.isCardio)
    }

    public static func isEligibleForAdjustment(_ day: TrainingDay) -> Bool {
        guard day.generationFingerprint != nil,
              day.generationFingerprint == day.currentContentFingerprint
        else { return false }
        return day.sessions.isEmpty
    }

    /// Geteilte Filterung fuer `analyze` UND `CoachAdjustmentCardModel.accept`
    /// (Leitplanke 3: `accept` berechnet die anfassbaren Tage am JETZT
    /// aktuellen Planzustand neu, statt veraltete IDs aus `analyze`
    /// weiterzureichen - derselbe Grundsatz wie bei der Coach-
    /// Reaktivierungs-Pruefung).
    public static func eligibleCardioDays(in plan: TrainingPlan) -> [TrainingDay] {
        plan.days.filter(isCardioDay).filter(isEligibleForAdjustment)
    }

    /// Rest-Tage, in die ein neuer Cardio-Tag eingefuegt werden darf.
    /// Herkunft wird durch `TrainingDay.isAutoFilledPlaceholder` bewiesen
    /// (Auftraggeber-Entscheidung, Option (a) — siehe "Dritte Review-Runde"),
    /// NICHT durch Name/Fingerprint/eine zufaellige Feldkombination geraten.
    /// FUENF Bedingungen, ALLE erforderlich (fünfte Review-Runde, Präzisierung 3
    /// — diese Funktion garantiert NUR die Tag-eigene Eignung; Plan-Zugehörigkeit
    /// und ausreichende Anzahl sind eine SEPARATE Garantie von
    /// `insertCoachCardioDays`, siehe dort): `isAutoFilledPlaceholder == true`
    /// (historischer Herkunfts-Beweis — bleibt nach einer erfolgreichen
    /// Einfuegung bewusst `true` stehen, exakt dasselbe Prinzip wie
    /// `generationFingerprint`: ein permanenter Erzeugungs-Stempel, kein
    /// "ist aktuell noch leer"-Live-Bit), `type == .rest`, `activeExercises.isEmpty`,
    /// `sessions.isEmpty` (drei Live-Zustands-Pruefungen), UND `customName == nil`
    /// (Vierte Review-Runde, Entscheidung 2: einziges ueber `DayEditorView`
    /// erreichbares Feld, das eine bewusste Nutzer-Absicht fuer GENAU diesen
    /// Tag ausdrueckt — unabhaengig von `isAutoFilledPlaceholder`, das nur die
    /// Herkunft, nicht die seitherige Nutzer-Absicht beweist).
    public static func isEligibleRestDayForInsertion(_ day: TrainingDay) -> Bool {
        day.isAutoFilledPlaceholder
            && day.type == .rest
            && day.activeExercises.isEmpty
            && day.sessions.isEmpty
            && day.customName == nil
    }

    public static func eligibleRestDaysForInsertion(in plan: TrainingPlan) -> [TrainingDay] {
        plan.days.filter(isEligibleRestDayForInsertion)
    }

    /// Wochentage 1-7, die im Plan noch GAR NICHT belegt sind (kein Tag mit
    /// diesem `weekday`). Sortiert aufsteigend. Gebraucht als Fallback, wenn
    /// weder anfassbare Cardio-Tage noch `isAutoFilledPlaceholder`-Ruhetage
    /// verfuegbar sind - z.B. nach manuellem Loeschen aller Ruhetage.
    public static func freeWeekdays(in plan: TrainingPlan) -> [Int] {
        let used = Set(plan.days.map(\.weekday))
        return (1...7).filter { !used.contains($0) }
    }

    /// Waehlt aus den freien Wochentagen `count` aus - gleiche Adjazenz-
    /// Heuristik wie `selectRestDaysForInsertion` (bevorzugt Tage NICHT
    /// direkt neben einem harten Kraft-Tag, best-effort).
    public static func selectWeekdaysForNewDays(
        free: [Int], count: Int, otherDays: [TrainingDay]
    ) -> [Int] {
        guard count > 0 else { return [] }
        let hardStrengthWeekdays = Set(
            otherDays.filter { $0.type != .rest && !isCardioDay($0) }.map(\.weekday)
        )
        let preferred = free.filter { wd in
            !hardStrengthWeekdays.contains(wd - 1) && !hardStrengthWeekdays.contains(wd + 1)
        }
        let fallback = free.filter { wd in
            hardStrengthWeekdays.contains(wd - 1) || hardStrengthWeekdays.contains(wd + 1)
        }
        return Array((preferred + fallback).prefix(count))
    }

    /// Waehlt aus den eignungsfaehigen Rest-Tagen genau `count` aus (bevorzugt
    /// Tage NICHT direkt neben einem bereits existierenden harten Krafttag,
    /// best-effort - Platzkonflikt mit einem Nicht-Rest-Tag ist nie erlaubt,
    /// aber auch nie moeglich: diese Funktion waehlt ausschliesslich aus
    /// `eligible`, das bereits auf echte Rest-Tage gefiltert ist).
    /// Deterministisch: gleiche Eingabe -> gleiche Auswahl (sortiert nach
    /// `weekday` vor jeder Auswahl-Entscheidung).
    ///
    /// "Harter Krafttag" = jeder Tag in `otherDays`, der weder Ruhetag noch
    /// Cardio-Tag ist (`type` nicht `.rest`/`.cardio`) - die bestehende
    /// `DayType`-Taxonomie kennt keine feinere "hart"/"leicht"-Unterscheidung
    /// fuer Kraft-Tage, eine solche zu erfinden waere eine unbelegte neue
    /// Schwelle (gleiches Prinzip wie `LegWorkRecommendation`s Doku oben).
    public static func selectRestDaysForInsertion(
        eligible: [TrainingDay], count: Int, otherDays: [TrainingDay]
    ) -> [TrainingDay] {
        guard count > 0 else { return [] }
        let sorted = eligible.sorted { $0.weekday < $1.weekday }
        let hardStrengthWeekdays = Set(otherDays.filter { $0.type != .rest && $0.type != .cardio }.map(\.weekday))
        func isAdjacentToHardStrengthDay(_ day: TrainingDay) -> Bool {
            hardStrengthWeekdays.contains(day.weekday - 1) || hardStrengthWeekdays.contains(day.weekday + 1)
        }
        let preferred = sorted.filter { !isAdjacentToHardStrengthDay($0) }
        let fallback = sorted.filter { isAdjacentToHardStrengthDay($0) }
        return Array((preferred + fallback).prefix(count))
    }

    /// `targetGoal`: das Ziel, auf das gewechselt wird - nur dann kann
    /// beurteilt werden, wie viele der vorhandenen Krafttage dafuer noch
    /// gebraucht werden (`convertibleStrengthDays`). Ohne `targetGoal`
    /// (bestehende Aufrufer, z.B. der reine Machbarkeits-Check ohne
    /// Zielwechsel-Kontext) bleibt das Verhalten unveraendert: nur
    /// bestehende Cardio-Tage zaehlen als `.ready`.
    public static func analyze(plan: TrainingPlan?, targetGoal: CardioGoal? = nil) -> Analysis {
        guard let plan else {
            return Analysis(cardioAvailability: .noActivePlan, legWork: .conflict, insertableRestDays: [], freeWeekdaysForNewDays: [], convertibleStrengthDays: [])
        }

        let eligibleCardio = eligibleCardioDays(in: plan)
        // Bugfix ("Bestehenden Trainingsplan bei Zieländerung flexibel
        // umstrukturieren"): ein Zielwechsel, der WENIGER Krafttage braucht
        // (z.B. Halbmarathon 2 -> Marathon 0), machte die jetzt
        // ueberfluessigen Krafttage bisher nirgends als verfuegbaren Platz
        // sichtbar - obwohl sie dieselbe Eignung wie ein anfassbarer
        // Cardio-Tag haben. `accept()` MUSS denselben kombinierten Satz
        // verwenden (siehe `eligibleDaysForGoalChange`), sonst zeigt die
        // Vorschau etwas an, das die Anwendung nicht leisten kann.
        let strengthSurplus = targetGoal.map { convertibleStrengthDays(in: plan, targetGoal: $0) } ?? []
        let combinedEligible = eligibleCardio + strengthSurplus
        let cardioAvailability: CardioAvailability = combinedEligible.isEmpty
            ? .noEligibleCardioDay
            : .ready(combinedEligible.map(\.persistentModelID))

        let legWork = legWorkRecommendation(eligibleStrengthDays: eligibleStrengthDays(in: plan))
        let insertableRestDays = eligibleRestDaysForInsertion(in: plan).map(\.persistentModelID)
        let freeWds = freeWeekdays(in: plan)

        return Analysis(
            cardioAvailability: cardioAvailability, legWork: legWork, insertableRestDays: insertableRestDays,
            freeWeekdaysForNewDays: freeWds, convertibleStrengthDays: strengthSurplus.map(\.persistentModelID)
        )
    }

    /// Anfassbare Krafttage (Wizard-erzeugt, seither unveraendert, keine
    /// Historie) - geteilte Eignungsregel fuer `legWorkRecommendation` UND
    /// `convertibleStrengthDays` (vorher zwei getrennte inline-Kopien
    /// desselben Filters).
    private static func eligibleStrengthDays(in plan: TrainingPlan) -> [TrainingDay] {
        plan.days.filter { $0.type != .rest && !isCardioDay($0) && isEligibleForAdjustment($0) }
    }

    /// Bugfix ("Bestehenden Trainingsplan bei Zieländerung flexibel
    /// umstrukturieren"): anfassbare Krafttage, die `targetGoal` nicht mehr
    /// braucht (`CardioFeasibilityCalculator.strengthDaysNeeded`) - sortiert
    /// nach Wochentag, die SPAETESTEN in der Woche liegenden ueberzaehligen
    /// Tage werden zuerst freigegeben (deterministisch, gleiche
    /// Sortier-vor-Auswahl-Regel wie `selectRestDaysForInsertion`).
    public static func convertibleStrengthDays(in plan: TrainingPlan, targetGoal: CardioGoal) -> [TrainingDay] {
        let eligible = eligibleStrengthDays(in: plan).sorted { $0.weekday < $1.weekday }
        let stillNeeded = CardioFeasibilityCalculator.strengthDaysNeeded(for: targetGoal)
        let surplus = max(0, eligible.count - stillNeeded)
        return Array(eligible.suffix(surplus))
    }

    /// Alle Tage, die ein Zielwechsel automatisch mit neuen Cardio-Inhalten
    /// belegen darf: bestehende anfassbare Cardio-Tage PLUS die durch das
    /// neue Ziel ueberzaehlig gewordenen Krafttage. Einzige Quelle fuer
    /// diesen kombinierten Satz - `analyze` (Vorschau) UND
    /// `CoachAdjustmentCardModel.accept` (tatsaechliche Anwendung) rufen
    /// BEIDE diese Funktion, damit sie nie auseinanderlaufen koennen.
    public static func eligibleDaysForGoalChange(in plan: TrainingPlan, targetGoal: CardioGoal) -> [TrainingDay] {
        eligibleCardioDays(in: plan) + convertibleStrengthDays(in: plan, targetGoal: targetGoal)
    }

    private static func legWorkRecommendation(eligibleStrengthDays: [TrainingDay]) -> LegWorkRecommendation {
        guard !eligibleStrengthDays.isEmpty else {
            // Keine anfassbare Kraft-Tage (alles manuell/editiert/mit
            // Historie) - keine tragfaehige Kombination fuer eine
            // automatische Ergaenzung, der Nutzer muesste selbst Platz
            // schaffen.
            return .conflict
        }

        let legSets = eligibleStrengthDays
            .flatMap(\.activeExercises)
            .filter { $0.primaryMuscle.map(legMuscleGroups.contains) ?? false }
            .reduce(0) { $0 + $1.sets }

        switch MuscleVolumeBucket(setsThisWeek: legSets) {
        case .maintenance, .optimal:
            return .unchanged
        case .overreaching:
            return .redistribute
        case .untrained:
            // Faustregel (keine wissenschaftliche Herleitung, nur ein
            // einfacher Platz-Proxy): ein Tag mit bereits >=6 Uebungen hat
            // keinen Platz fuer eine Ergaenzung ohne etwas zu entfernen.
            let isAnyDayAlreadyFull = eligibleStrengthDays.contains { $0.activeExercises.count >= 6 }
            return isAnyDayAlreadyFull ? .replaceForTime : .addSmallAddition
        }
    }
}
#endif
