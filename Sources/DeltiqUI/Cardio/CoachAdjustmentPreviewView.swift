#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

/// Paket 1, Komponente 4 (Laufcoach-Plananpassung,
/// docs/DELTIQ_DEVICE_ACCEPTANCE.md): Vorher/Nachher-Vorschau für
/// `CoachAdjustmentCardModel`, mit den drei vorgegebenen Aktionen.
///
/// Nur erreichbar, wenn bereits ein aktiver Plan existiert (siehe
/// `ProfileEditorView.coachAdjustmentModel` — der "kein aktiver Plan"-Fall
/// bleibt bewusst bei der bestehenden `CardioFeasibilityCardModel`/
/// `feasibilitySection` (Leitplanke 6), die ihre eigene
/// "vorbefüllte Neuerstellung" bereits beherrscht).
/// Review-Fix (Teil 4): die drei Werte, die `weeklyVolumeProjection`
/// vollstaendig und eindeutig bestimmen - wechselt einer davon (neuer Plan,
/// anderes Ziel, anderes Rennen), ist `selectedChartWeek` auf einen fremden
/// Datenpunkt bezogen und muss zurueckgesetzt werden. Ein normales
/// SwiftUI-Re-Render mit UNVERAENDERTEN Werten darf die Auswahl dagegen NICHT
/// verwerfen - `Equatable` liefert genau diese Unterscheidung fuer
/// `.onChange(of:)`, ohne die (nicht-Equatable) `points`-Tupelliste selbst
/// vergleichen zu muessen.
private struct ChartProjectionIdentity: Equatable {
    let startKm: Double
    let goal: CardioGoal
    let weeksAvailable: Int
}

/// Review-Fix (Teil 3/6): reine Klassifikationslogik, OHNE SwiftUI-Zustand
/// (keine `@State`, keine View-Instanz noetig) - dadurch mit echten
/// Verhaltens-Asserts testbar (siehe `CoachAdjustmentChartExplanationTests`),
/// nicht nur per Source-Introspection. Keine Trainings-Berechnung (das bleibt
/// exklusiv `CardioFeasibilityCalculator`) - nur die Frage, welche der
/// vorformulierten Erklaerungen zu einem bereits fertig berechneten
/// Projektionsverlauf passt. Prioritaet von spezifischster zu generischster
/// Aussage:
///
/// 1. Reduzierung INNERHALB des Aufbaus (vor dem eigentlichen Taper) - mit
///    der heutigen, monoton steigenden Rampe (unveraendert) kann das nie
///    eintreten, der Pfad bleibt aber fuer eine spaetere, eigenstaendige
///    Entlastungswochen-Logik vorbereitet, OHNE selbst eine einzufuehren.
/// 2. Taper vorhanden - unmittelbar relevante Aussage kurz vor dem
///    Wettkampf, unabhaengig davon wie der Aufbau davor aussah.
/// 3. Ein echtes Mehrwochen-Plateau auf der Spitze (mehrere Wochen auf dem
///    Maximum, nachdem tatsaechlich aufgebaut wurde).
/// 4. Ein laengerer, durchgehender Anstieg (>= 2 Aufbau-Wochen) ohne
///    Plateau/Taper.
/// 5. Fallback: die Spitze wird quasi sofort erreicht (0-1 echte
///    Aufbau-Wochen) - z.B. sehr kurzer Plan oder bereits am Zielvolumen.
enum CoachAdjustmentChartExplanation: String, Sendable, Equatable {
    case deloadWithinBuildUp
    case taper
    case plateau
    case continuousBuildUp
    case peakReached

    static func classify(
        points: [(week: Int, km: Double)],
        phases: [CardioFeasibilityCalculator.ChartPhase]
    ) -> CoachAdjustmentChartExplanation {
        let buildUpCount = phases.filter { $0 == .buildUp }.count
        let peakCount = phases.filter { $0 == .peak }.count
        let taperOccurred = phases.contains(.taper)
        let hasDeloadWithinBuildUp = (1..<points.count).contains { i in
            phases[i] != .taper && points[i].km < points[i - 1].km - 0.001
        }
        if hasDeloadWithinBuildUp { return .deloadWithinBuildUp }
        if taperOccurred { return .taper }
        if peakCount > 1 && buildUpCount > 0 { return .plateau }
        if buildUpCount >= 2 { return .continuousBuildUp }
        return .peakReached
    }

    var localizationKey: LocalizedStringKey {
        switch self {
        case .deloadWithinBuildUp: return "profile.cardio.adjustment.chart.explanation.deloadWithinBuildUp"
        case .taper: return "profile.cardio.adjustment.chart.explanation.taper"
        case .plateau: return "profile.cardio.adjustment.chart.explanation.plateau"
        case .continuousBuildUp: return "profile.cardio.adjustment.chart.explanation.continuousBuildUp"
        case .peakReached: return "profile.cardio.adjustment.chart.explanation.peakReached"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct CoachAdjustmentPreviewView: View {
    @Bindable var profile: UserBodyProfile
    let activePlan: TrainingPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isApplying = false
    @State private var isCreatingNewPlan = false
    @State private var createNewPlanOperation = PlanCreationOperation()
    @State private var errorMessage: String?
    @State private var selectedChartWeek: Int?

    private var model: CoachAdjustmentCardModel? {
        CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan)
    }

    /// Task 7 (Decision 3 Teil 2): die Vorschau muss dasselbe Ziel zeigen,
    /// das `accept()` tatsaechlich anwendet - `model.proposedGoal` statt des
    /// rohen, moeglicherweise nicht erreichbaren `profile.cardioGoal`
    /// (Fallback nur, wenn kein kleineres Ziel mehr erreichbar ist, siehe
    /// `CoachAdjustmentCardModel.proposedGoal`). `cardioRunProfile` wird
    /// hier aus denselben Profil-Feldern gebaut wie in `accept()`, damit die
    /// "Nachher"-Spalte ebenfalls eine Pace zeigt statt immer `nil`.
    private func newCardioDays(for model: CoachAdjustmentCardModel) -> [DaySpec] {
        let goal = model.proposedGoal ?? profile.cardioGoal
        return CoachAdjustmentCardModel.cardioOnlyDaySpecs(
            for: goal,
            cardioRunProfile: CardioRunProfile(
                goal: goal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "profile.cardio.adjustment.title", bundle: .module),
                // "Bestehenden Plan beibehalten": reines Schliessen,
                // keinerlei Zustandsaenderung (Leitplanke 2 - weder
                // cardioCoachingEnabled noch der Plan werden hier
                // angefasst). cardioCoachingEnabled bleibt an, die
                // Vorschau zeigt das bereits ehrlich ueber `statusSection`.
                onBack: { dismiss() }
            )
            List {
                if let model {
                    statusSection(model)
                    beforeAfterSection(model)
                }
            }
            .alert(
                Text("profile.cardio.adjustment.applyError.title", bundle: .module),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func statusSection(_ model: CoachAdjustmentCardModel) -> some View {
        Section {
            Text(model.isAlreadyApplied
                 ? String(localized: "profile.cardio.adjustment.applied", bundle: .module)
                 : String(localized: "profile.cardio.adjustment.pending", bundle: .module))
                .font(.subheadline.weight(.semibold))
            // Fix I-4 (Final-Review, Round 2): `verdict` ist optional, weil
            // `make` seit Task 6 auch ohne Renn-Datum/Wochenvolumen non-nil
            // liefert (keine Machbarkeits-Meinung moeglich). Ohne Verdikt
            // darf KEINE Machbarkeits-Aussage (weder feasible noch
            // infeasible) angezeigt werden (Decision 2: keine unbelegte
            // Praezisions-/Sicherheits-Behauptung) - die Zeile faellt dann
            // einfach weg, statt eine unerprobte "machbar" zu behaupten.
            if let verdict = model.verdict {
                Text(verdict.feasible
                     ? String(localized: "profile.cardio.feasibility.feasibleHeadline", bundle: .module)
                     : String(localized: "profile.cardio.feasibility.infeasibleHeadline", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func beforeAfterSection(_ model: CoachAdjustmentCardModel) -> some View {
        // Nach Uebernahme: kein Vergleich mehr zeigen — der User hat bereits
        // entschieden, die Alt/Neu-Gegenueber­stellung ist jetzt Laerm.
        if model.isAlreadyApplied {
            trainingDetailSection(model)
            createNewPlanButton(model)
        } else {
        switch model.analysis.cardioAvailability {
        case .ready(let ids):
            // Fix 2 (Deltiq_Laufcoaching_Audit_Fixes_Claude.md): `ids.count`
            // existing eligible days alone may not be enough for the goal -
            // the write path (`CoachAdjustmentCardModel.accept`, Finding 1)
            // replaces all of them and atomically inserts the remainder into
            // free rest days, throwing `insufficientRestDays` BEFORE any
            // mutation if there isn't enough room. This mirrors that same
            // check here, proactively, using the identical eligibility rule
            // (`RunCoachPlanAdjustment.isEligibleRestDayForInsertion`,
            // already aggregated as `model.analysis.insertableRestDays`) -
            // same pattern as the `.noEligibleCardioDay` case below, just
            // with `ids.count` existing days already covering part of the
            // goal instead of starting from zero.
            let desiredDays = newCardioDays(for: model)
            let extraNeeded = max(0, desiredDays.count - ids.count)
            // Stärkekonversion: Gesamtkapazität = Rest + Free + convertibleStrength.
            let totalCapacity = model.analysis.insertableRestDays.count + model.analysis.freeWeekdaysForNewDays.count + model.analysis.convertibleStrengthDays.count
            if extraNeeded == 0 || model.analysis.insertableRestDays.count >= extraNeeded {
                Section {
                    ForEach(Array(activePlan.days.filter { ids.contains($0.persistentModelID) }), id: \.persistentModelID) { day in
                        Text(day.name)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(desiredDays.enumerated()), id: \.offset) { _, spec in
                        Text(spec.name)
                    }
                } header: {
                    Text("profile.cardio.adjustment.before", bundle: .module)
                } footer: {
                    Text("profile.cardio.adjustment.after", bundle: .module)
                }
                actionButtons(model)
                trainingDetailSection(model)
            } else if totalCapacity >= extraNeeded {
                strengthConversionSection(model)
            } else {
                // Not the same state as `.planChanged` (that's a real
                // race between preview-open and tap) and not the same as
                // `.noEligibleDay` (that string says "changed manually,"
                // which is false here - there IS at least one eligible
                // day, there just isn't enough SPARE room to grow to the
                // goal's day count). Dedicated message, no silent partial
                // application, no seemingly-executable action offered.
                Section {
                    Text("profile.cardio.adjustment.notEnoughRoom", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                createNewPlanButton(model)
            }
        case .noEligibleCardioDay:
            // Task 7: Task 5/6s Einfuege-Pfad (Ruhetag -> Cardio-Tag) macht
            // diesen Fall nicht mehr zwangslaeufig zu einem reinen "nichts zu
            // tun" - ist mindestens ein Ruhetag einfuegbar, zeigt die Vorschau
            // dieselben Aktionen wie der `.ready`-Zweig (`actionButtons`,
            // dessen `model.accept` die Einfuegung selbst traegt), nur mit
            // einer Vorher/Nachher-Darstellung ohne "altes" Original (siehe
            // unten: `"— → <neuer Tag>"`, kein `.strikethrough()`, da kein
            // vorhandener Tag ersetzt wird).
            // Final-Review Fix 2: "mindestens ein einfuegbarer Ruhetag" reicht
            // nicht - `accept()`s Einfuege-Pfad verlangt GENUG davon fuer das
            // Ziel (`PlanGeneratorInstantiator.CardioInsertionError.
            // insufficientRestDays`, Task 6s eigene, korrekte Guard). Zu wenige
            // eignbare Tage wuerden sonst "Auf aktuellen Plan anwenden"
            // anbieten, das JEDEN Versuch mit der irrefuehrenden "Plan hat
            // sich geaendert"-Meldung abbricht, ohne je "Neuen Plan erstellen"
            // erreichbar zu machen.
            let desired = newCardioDays(for: model)
            // Zwei Pfade: isAutoFilledPlaceholder-Ruhetage ersetzen ODER neue
            // Tage auf freien Wochentagen erzeugen (Fallback, wenn Ruhetage
            // manuell geloescht wurden). Beide Pfade laufen in accept().
            // Stärkekonversion: Gesamtkapazität = Rest + Free + convertibleStrength.
            let totalCapacity = model.analysis.insertableRestDays.count + model.analysis.freeWeekdaysForNewDays.count + model.analysis.convertibleStrengthDays.count
            if model.analysis.insertableRestDays.count >= newCardioDays(for: model).count {
                Section {
                    ForEach(Array(desired.enumerated()), id: \.offset) { _, spec in
                        Text("— → \(spec.name)")
                    }
                } header: {
                    Text("profile.cardio.adjustment.before", bundle: .module)
                } footer: {
                    Text("profile.cardio.adjustment.after", bundle: .module)
                }
                actionButtons(model)
                trainingDetailSection(model)
            } else if totalCapacity >= desired.count {
                strengthConversionSection(model)
            } else {
                Section {
                    Text("profile.cardio.adjustment.noEligibleDay", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                createNewPlanButton(model)
            }
        case .noActivePlan:
            EmptyView()
        }
        } // end else
    }

    @ViewBuilder
    private func actionButtons(_ model: CoachAdjustmentCardModel) -> some View {
        Section {
            Button {
                guard !isApplying else { return }
                isApplying = true
                do {
                    try model.accept(plan: activePlan, profile: profile, in: modelContext)
                    dismiss()
                } catch is PlanGeneratorInstantiator.CardioInsertionError {
                    // Task 7 (Entscheidung, nicht verhandelbar): `insertCoachCardioDays`s
                    // Re-Validierungsfehler (Plan hat sich seit der Vorschau
                    // geaendert) darf NICHT im generischen Catch-All unten
                    // verschwinden (dessen unleserliche "operation couldn't be
                    // completed"-Standardmeldung) - eigene, lesbare Botschaft
                    // statt eines stillen/unleserlichen Fehlschlags.
                    errorMessage = String(localized: "profile.cardio.adjustment.planChanged", bundle: .module)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isApplying = false
            } label: {
                Text("profile.cardio.adjustment.applyToCurrentPlan", bundle: .module)
            }
            .disabled(isApplying || model.isAlreadyApplied)
        }
        createNewPlanButton(model)
    }

    /// Nachbesserung ("Krafttraining bei Laufzieländerung erhalten"): wird
    /// nur erreicht, wenn weder bestehende Lauftage noch einfuegbare
    /// Ruhetage/freie Wochentage ausreichen, ABER die ueberzaehligen
    /// Krafttage (`model.analysis.convertibleStrengthDays`) die Luecke
    /// schliessen wuerden. Eine EIGENE, explizit zu bestaetigende Aktion -
    /// bewusst NICHT `actionButtons(model)` (das normale "Auf aktuellen
    /// Plan anwenden" ruehrt Krafttage nie an, siehe
    /// `CoachAdjustmentCardModel.accept`s `convertStrengthDaysIfNeeded`).
    @ViewBuilder
    private func strengthConversionSection(_ model: CoachAdjustmentCardModel) -> some View {
        let strengthDays = activePlan.days.filter { model.analysis.convertibleStrengthDays.contains($0.persistentModelID) }
        Section {
            ForEach(Array(strengthDays), id: \.persistentModelID) { day in
                Text(day.name)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("profile.cardio.adjustment.strengthConversion.header", bundle: .module)
        } footer: {
            Text("profile.cardio.adjustment.strengthConversion.footer", bundle: .module)
        }
        Section {
            Button {
                guard !isApplying else { return }
                isApplying = true
                do {
                    try model.accept(plan: activePlan, profile: profile, in: modelContext, convertStrengthDaysIfNeeded: true)
                    dismiss()
                } catch is PlanGeneratorInstantiator.CardioInsertionError {
                    errorMessage = String(localized: "profile.cardio.adjustment.planChanged", bundle: .module)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isApplying = false
            } label: {
                Text("profile.cardio.adjustment.confirmStrengthConversion", bundle: .module)
            }
            .disabled(isApplying)
        }
        createNewPlanButton(model)
    }

    /// Zeigt Paces und Startvolumen als Orientierung, wenn Profildaten vorhanden sind.
    /// Sichtbar unabhaengig von `isAlreadyApplied` — relevant vor UND nach Annahme.
    @ViewBuilder
    private func trainingDetailSection(_ model: CoachAdjustmentCardModel) -> some View {
        let refSecs = profile.current5kReferenceSeconds
        let easy = refSecs.flatMap { PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: $0) }
        let tempo = refSecs.flatMap { PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: $0) }
        let hasAnything = easy != nil || (profile.weeklyBaseVolumeKm ?? 0) > 0
        if hasAnything {
            Section {
                if let easy, let tempo {
                    Text(String(
                        format: String(localized: "profile.cardio.paceZones", bundle: .module),
                        PaceCalculator.formatPace(easy),
                        PaceCalculator.formatPace(tempo)
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                if let vol = profile.weeklyBaseVolumeKm, vol > 0 {
                    Text(String(
                        format: String(localized: "profile.cardio.adjustment.detail.startVolume", bundle: .module),
                        Int(vol)
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                let projGoal = model.proposedGoal ?? profile.cardioGoal
                if let startVol = profile.weeklyBaseVolumeKm, startVol > 0,
                   let raceDate = profile.cardioRaceDate, raceDate > Date() {
                    let totalWeeks = Calendar.current.dateComponents(
                        [.weekOfYear], from: Date(), to: raceDate
                    ).weekOfYear ?? 0
                    // Alle Punkte direkt — kein chartPoints-Sampling, das Wochen
                    // ueberspringt und visuelle Luecken erzeugt (Section 4A).
                    let points = CardioFeasibilityCalculator.weeklyVolumeProjection(
                        startKm: startVol, goal: projGoal, weeksAvailable: totalWeeks
                    )
                    if !points.isEmpty {
                        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
                        let presentPhases: [CardioFeasibilityCalculator.ChartPhase] =
                            [.buildUp, .peak, .taper].filter { phases.contains($0) }
                        if presentPhases.count > 1 {
                            HStack(spacing: 12) {
                                ForEach(presentPhases, id: \.self) { phase in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(phaseColor(phase))
                                            .frame(width: 6, height: 6)
                                        Text(phaseLabelKey(phase), bundle: .module)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Chart {
                            ForEach(0..<points.count, id: \.self) { i in
                                BarMark(
                                    x: .value("Woche", points[i].week),
                                    y: .value("km", points[i].km)
                                )
                                .foregroundStyle(phaseColor(phases[i]))
                                .accessibilityLabel(weekLabel(points[i].week))
                                .accessibilityValue("\(points[i].km.formattedWholeOrTwoDecimals) km")
                            }
                        }
                        .chartXSelection(value: $selectedChartWeek)
                        .onChange(of: ChartProjectionIdentity(startKm: startVol, goal: projGoal, weeksAvailable: totalWeeks)) {
                            selectedChartWeek = nil
                        }
                        .frame(height: 110)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let w = value.as(Int.self) {
                                        Text(weekLabel(w)).font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let km = value.as(Double.self) {
                                        Text("\(Int(km))km").font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartYAxisLabel {
                            Text("profile.cardio.adjustment.chart.yAxisLabel", bundle: .module)
                                .font(.caption2)
                        }
                        if let selectedWeek = selectedChartWeek,
                           let i = points.firstIndex(where: { $0.week == selectedWeek }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weekLabel(points[i].week))
                                    .font(.caption.weight(.semibold))
                                Text("\(points[i].km.formattedWholeOrTwoDecimals) km")
                                    .font(.caption)
                                Text("profile.cardio.adjustment.chart.plannedVolumeCaption", bundle: .module)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if i > 0 {
                                    let delta = points[i].km - points[i - 1].km
                                    Text(String(
                                        format: String(localized: "profile.cardio.adjustment.chart.weekDelta", bundle: .module),
                                        (delta >= 0 ? "+" : "−") + abs(delta).formattedWholeOrTwoDecimals + " km"
                                    ))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Text(coachingExplanationKey(points: points, phases: phases), bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("profile.cardio.adjustment.detail.header", bundle: .module)
            }
        }
    }

    /// Review-Fix: `weeklyVolumeProjection`s `week`-Feld IST bereits die
    /// tatsaechliche Trainingswochen-Nummer (`week: 1` = erste Trainingswoche,
    /// siehe dortige Doku "Woche 0 = Startvolumen, dann 10% pro Woche
    /// aufbauen") - eine zusaetzliche `+ 1`-Verschiebung zeigte faelschlich
    /// "Woche 2" fuer die erste Trainingswoche an. Einzige Ausnahme: `week: 0`
    /// ist der Ausgangspunkt (aktuelles Volumen), keine Trainingswoche - der
    /// bekommt eine eigene, eindeutige Beschriftung statt "Woche 0".
    /// Achse UND Auswahl-Panel rufen beide ausschliesslich diese eine
    /// Funktion auf, koennen also nie auseinanderlaufen.
    private func weekLabel(_ week: Int) -> String {
        guard week > 0 else {
            return String(localized: "profile.cardio.adjustment.chart.weekLabel.current", bundle: .module)
        }
        return String(
            format: String(localized: "profile.cardio.adjustment.chart.weekLabel", bundle: .module),
            week
        )
    }

    /// Dezente Opacity-Abstufungen DER BESTEHENDEN Akzentfarbe statt neuer
    /// Farben (Ticket-Vorgabe Teil 3: "Die bestehende orangefarbene Deltiq-
    /// Akzentfarbe soll weiterhin dominieren").
    private func phaseColor(_ phase: CardioFeasibilityCalculator.ChartPhase) -> Color {
        switch phase {
        case .buildUp: return Color.deltiqOrange.opacity(0.5)
        case .peak: return Color.deltiqOrange.opacity(0.9)
        case .taper: return Color.deltiqOrange.opacity(0.3)
        }
    }

    private func phaseLabelKey(_ phase: CardioFeasibilityCalculator.ChartPhase) -> LocalizedStringKey {
        switch phase {
        case .buildUp: return "profile.cardio.adjustment.chart.phase.buildUp"
        case .peak: return "profile.cardio.adjustment.chart.phase.peak"
        case .taper: return "profile.cardio.adjustment.chart.phase.taper"
        }
    }

    /// Delegiert an die SwiftUI-unabhaengige, testbare
    /// `CoachAdjustmentChartExplanation` (siehe dort fuer die
    /// Prioritaets-Begruendung der einzelnen Faelle).
    private func coachingExplanationKey(
        points: [(week: Int, km: Double)],
        phases: [CardioFeasibilityCalculator.ChartPhase]
    ) -> LocalizedStringKey {
        CoachAdjustmentChartExplanation.classify(points: points, phases: phases).localizationKey
    }

    /// "Als neuen Plan erstellen": reuse des bereits bestehenden, geprüften
    /// `CardioFeasibilityCardModel.accept`-Pfads statt einer zweiten
    /// Implementierung - exakt derselbe Mechanismus wie in
    /// `ProfileEditorView.feasibilitySection`.
    ///
    /// Task 7 (Review-Korrektur): `activePlan` wird HIER bewusst NICHT durchgereicht (anders als
    /// bei den beiden anderen Aufrufstellen). Diese Vorschau bietet DREI eigenstaendige,
    /// gleichrangige Aktionen (siehe Typ-Doku oben): "auf aktuellen Plan anwenden" (oben,
    /// `CoachAdjustmentCardModel.accept`), "als neuen Plan erstellen" (hier) und "Plan behalten"
    /// (Abbrechen). Der Nutzer hat mit dem Tap auf GENAU DIESEN Button bereits explizit einen
    /// separaten neuen Plan gewaehlt, als bewusste Alternative zur In-Place-Anpassung, die direkt
    /// darueber ebenfalls angeboten wird. Wuerde `activePlan` hier durchgereicht, wuerde
    /// `CardioFeasibilityCardModel.accept`s neue Weiche (siehe dortige Doku) diesen Tap bei einem
    /// anpassbaren Plan STILL in dieselbe In-Place-Anpassung umleiten - zwei bewusst
    /// unterschiedliche Nutzer-Entscheidungen wuerden ununterscheidbar. Diese Aufrufstelle bleibt
    /// daher bei `activePlan: nil` (Default), erzeugt also immer einen echten, separaten Plan -
    /// exakt das bisherige, unveraenderte Verhalten.
    @ViewBuilder
    private func createNewPlanButton(_ model: CoachAdjustmentCardModel) -> some View {
        if let feasibilityModel = CardioFeasibilityCardModel.make(for: profile) {
            Section {
                Button {
                    guard !isCreatingNewPlan else { return }
                    isCreatingNewPlan = true
                    _ = feasibilityModel.accept(profile: profile, in: modelContext, using: createNewPlanOperation)
                    isCreatingNewPlan = false
                    dismiss()
                } label: {
                    Text("profile.cardio.adjustment.createNewPlan", bundle: .module)
                }
                .disabled(isCreatingNewPlan)
            }
        }
    }
}
#endif
