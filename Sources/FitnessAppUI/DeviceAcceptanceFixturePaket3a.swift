#if DEBUG
#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Paket-3a-Gerätenachweis (docs/DELTIQ_DEVICE_ACCEPTANCE.md, Abschnitt
/// "Paket 3a: Geräteabnahme"): einziger Zweck ist, auf einem TestingBot-
/// Testbuild einen fachlich gültigen Laufversäumnis-Auslösezustand
/// herzustellen, den die NORMALE Produktlogik (`MissedRunDayEvaluator` →
/// `CardioCoachingAdvisor` → `MissedRunDaysCardModel` → `DashboardView`)
/// unveraendert auswertet — dieser Typ selbst entscheidet NICHTS ueber die
/// Sichtbarkeit des Hinweises, er legt nur Ausgangsdaten ueber den normalen
/// `ModelContext` an.
///
/// Nur aktiv, wenn BEIDE Bedingungen gelten:
///   * Debug-Build (`#if DEBUG`) — jeder CI-/TestingBot-Build dieses
///     Projekts ist ausschliesslich ein Debug-Build (`project.yml`:
///     `defaultConfig: Debug`; `apple-ci-comparison.yml`: xcodebuild
///     `-configuration Debug`). Ein App-Store-/TestFlight-Release
///     (`testflight-release.yml`) kompiliert dagegen `Release` — dort ist
///     dieser gesamte Typ nicht Teil des Binaries.
///   * Das Launch-Argument `launchArgument` ist explizit gesetzt — kein
///     regulaerer App-Start setzt es jemals.
/// Beruehrt KEINEN Produktionscode-Pfad: reines `context.insert(...)` auf
/// bestehenden, bereits produktiv genutzten Modellen — Evaluator/Advisor/
/// Card-Modell/UI selbst bleiben unveraendert.
@MainActor
enum DeviceAcceptanceFixturePaket3a {
    static let launchArgument = "-deltiqDeviceAcceptanceFixturePaket3a"

    /// Namen, ueber die sowohl diese Funktion ihre Idempotenz prueft als
    /// auch der Geraete-Tester die beiden Plaene am Bildschirm unterscheidet.
    static let affectedPlanName = "Marathon-Vorbereitung A"
    static let otherPlanName = "Kraft-Grundlagen B"

    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        seed(in: context)
    }

    /// Eigentliche Seed-Logik, OHNE das Launch-Argument-Gate — so direkt
    /// testbar (siehe `DeviceAcceptanceFixturePaket3aTests`: Selbstcheck,
    /// dass diese Daten ueber die ECHTE Evaluator-Kette tatsaechlich einen
    /// `MissedRunDaysCardModel`-Treffer ergeben, BEVOR das erste
    /// TestingBot-Gerätefenster davon abhaengt).
    static func seed(in context: ModelContext) {
        // Idempotent: ein echter Kaltstart (Schritt D des Geraete-Nachweises)
        // ruft diese Funktion erneut auf — sie darf dabei NICHT ein zweites
        // Mal seeden (das wuerde `activatedAt`/den Fingerprint veraendern und
        // damit genau die zu pruefende Unterdrueckungs-Bindung zerstoeren).
        let existingPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        guard !existingPlans.contains(where: { $0.customName == affectedPlanName }) else { return }

        let profile = UserBodyProfile(
            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            heightCm: 175,
            profile: .male,
            firstName: "Geräteabnahme",
            trainingGoal: .hybrid,
            cardioCoachingEnabled: true,
            cardioGoal: .marathon,
            cardioRaceDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            weeklyBaseVolumeKm: 20
        )
        context.insert(profile)

        // Betroffener, aktiver Plan: vor 21 Tagen aktiviert, drei echte,
        // ueber `enduranceSportKind` als Laufen markierte Tage, KEINE
        // geloggten Sessions darauf — "lange zurueckliegende, nicht
        // geloggte Lauf-Tage" (Auftrag Schritt 2). 21 Tage bei 3
        // Lauf-Tagen/Woche (flexible Kadenz, kein Generator-Input) ergeben
        // ~9 faellige Gelegenheiten — deutlich ueber der Ausloeseschwelle von
        // 2 (`CardioCoachingAdvisor.minimumMissedRunDaysToFlag`).
        let activatedAt = Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date()
        let affectedPlan = TrainingPlan(
            name: affectedPlanName,
            customName: affectedPlanName,
            isActive: true,
            activatedAt: activatedAt
        )
        context.insert(affectedPlan)

        for (weekday, label) in [(2, "Ruhiger Lauf Mo"), (4, "Ruhiger Lauf Mi"), (6, "Ruhiger Lauf Fr")] {
            let day = TrainingDay(name: label, weekday: weekday, type: .cardio, plan: affectedPlan, enduranceSportKind: .running)
            // Macht den Tag fuer `RunCoachPlanAdjustment.isEligibleForAdjustment`
            // "anfassbar" (wie ein echter Wizard-generierter Tag) — ohne das
            // zeigt die Vorschau nur den generischen "kein anfassbarer Tag"-
            // Text statt der tatsaechlichen, planspezifischen Tagesnamen, die
            // Schritt B's Unterscheidbarkeits-Pruefung am Geraet braucht.
            day.generationFingerprint = day.currentContentFingerprint
            context.insert(day)
        }
        for weekday in [1, 3, 5, 7] {
            context.insert(TrainingDay(name: "Ruhetag", weekday: weekday, type: .rest, plan: affectedPlan))
        }

        // Zweiter, klar unterscheidbarer Plan — bewusst INAKTIV statt eines
        // zweiten GLEICHZEITIG aktiven Plans: mehrere gleichzeitig aktive
        // Plaene sind zwar ein gewolltes Produktverhalten
        // (`ProgramInstantiator`-Doku), aber welcher davon `activePlans.first`
        // liefert, ist dort selbst als "defensiv" dokumentiert — eine
        // Paket-1/Dashboard-weite Architekturfrage, die nicht spezifisch zur
        // neuen Paket-3a-Karte/ihrer Anbindung gehoert und außerhalb dieses
        // Auftrags-Scopes liegt. Diese Wahl prueft trotzdem den eigentlichen
        // Punkt des Auftrags: dass die Vorschau tatsaechlich DIESES Plans
        // Inhalt zeigt, nicht pauschal "irgendeinen"/den falschen.
        let otherPlan = TrainingPlan(name: otherPlanName, customName: otherPlanName, isActive: false)
        context.insert(otherPlan)
        context.insert(TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: otherPlan))

        try? context.save()
    }
}
#endif
#endif
