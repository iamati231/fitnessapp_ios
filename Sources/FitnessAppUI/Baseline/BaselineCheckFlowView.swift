#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Eigenstaendiger Sub-Wizard als Sheet fuer den optionalen Start-Check
/// "Dein Startpunkt" (siehe `OnboardingView.baselineCheckStep`, der einzige
/// Aufrufer). UX-Fix "Konzept statt linearer Kette" (`docs/
/// BASELINE_CHECK_UX.md`): Hub-and-Spoke-Navigation statt einer erzwungenen
/// Schrittkette — eine Uebersicht mit frei waehlbarer Reihenfolge, EIN
/// NavigationStack mit Push/Pop fuer die einzelnen Familien-Mini-Flows.
///
/// Liefert dem Aufrufer nur per `onFinish` ein fertiges `BaselineAssessment`
/// zurueck (oder `nil` bei Abbruch) — legt selbst NICHTS in SwiftData an und
/// kennt kein `UserBodyProfile`. `OnboardingView.finishOnboarding()` schreibt
/// das Ergebnis erst zusammen mit dem restlichen Profil.
///
/// Nie ein Gate (Epic-Vorgabe): die Uebersicht ist ab dem ersten Rendern
/// weiter-klickbar, jede Bewegungsfamilie einzeln ueberspringbar.
@available(iOS 17.0, macOS 14.0, *)
struct BaselineCheckFlowView: View {

    /// Wie der Check betreten wurde — identisch zur 3-Wege-Wahl im
    /// Onboarding-Schritt, minus "Spaeter" (das oeffnet dieses Sheet gar
    /// nicht erst). `.selfAssessment` ueberspringt JEDE gefuehrte
    /// Test-Ansicht und zeigt direkt die Selbsteinschaetzung je Familie —
    /// derselbe Pfad, den auch Erfahrene ueber ihren kompakten Link nehmen,
    /// und den ein `.flagged`-Sicherheitsergebnis erzwingt
    /// (siehe `isGuidedTestAllowed`).
    enum EntryMode: Sendable {
        case guidedTest
        case selfAssessment
    }

    /// Wie eine einzelne Bewegungsfamilie in diesem Durchlauf behandelt
    /// wird. `.skip` ist bewusst von "getestet mit 0 Wiederholungen"
    /// unterschieden — nur so bleibt das zusammengesetzte
    /// `BaselineAssessment` nach einem bewussten Uebersprung wirklich `nil`
    /// statt eines irrefuehrenden Nullwerts (siehe `assembleBaselineAssessment`).
    private enum FamilyMode: Sendable {
        case test
        case selfAssess
        case skip
    }

    /// Hub-and-Spoke-Navigation: EIN `NavigationStack` mit einem Pfad aus
    /// `Route`-Werten. Jede Familien-Karte in der Uebersicht haengt ihre
    /// Route an den Pfad an; "Speichern"/eine Selbsteinschaetzungs-Auswahl/
    /// "Ueberspringen" nimmt sie per `path.removeLast()` wieder weg — der
    /// native Zurueck-Button deckt die restliche Navigation kostenlos ab.
    private enum Route: Hashable {
        case push, legs, pull, core, cardio, intensity, result
    }

    /// Status einer Familien-Karte in der Uebersicht. Wird nie nur ueber
    /// Farbe vermittelt (siehe `familyStatusBadge`) — Icon-Form UND Text
    /// sind immer beide vorhanden.
    private enum FamilyStatus {
        case open, recorded, skipped
    }

    let entryMode: EntryMode
    let goal: TrainingGoal
    let equipmentPreferences: Set<Equipment>
    let onFinish: (BaselineAssessment?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var path: [Route] = []
    /// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): siehe
    /// `isDirty`/`discardChangesConfirmation` unten.
    @State private var showingDiscardConfirm = false

    // Sicherheit — UX-Fix vereinfacht auf 2 Antworten (das Datenmodell
    // `SafetyStatus` ist ohnehin binaer; die vorige 3-Options-Frage
    // (Ja/Unsicher/Nein) taeuschte eine Praezision vor, die es nicht gab).
    @State private var safetyStatus: SafetyStatus?

    // A. Push
    @State private var pushMode: FamilyMode = .test
    @State private var pushVariant: PushUpVariant = .standard
    @State private var pushReps: Int = 0
    @State private var pushSelfAssess: SelfAssessmentAnswer?
    @State private var pushConfirmed = false

    // B. Legs
    @State private var legsMode: FamilyMode = .test
    @State private var legsTimer = PausableTimerState()
    @State private var legsReps: Int = 0
    @State private var legsSelfAssess: SelfAssessmentAnswer?
    @State private var legsConfirmed = false

    // C. Pull — Equipment entscheidet den Pfad (siehe `pullHasGymEquipment`);
    // ohne Cable/Machine wird zusaetzlich lokal (nur fuer dieses Sheet, NICHT
    // in `equipmentPreferences` persistiert) nach einer Klimmzugstange
    // gefragt, da `Equipment` dafuer keinen eigenen Fall kennt.
    @State private var pullMode: FamilyMode = .test
    @State private var hasPullUpBar: Bool?
    @State private var pullVariant: PullVariant = .assistedPullUp
    @State private var pullReps: Int = 0
    @State private var pullLoadKg: Double?
    @State private var pullRir: Double = 2
    @State private var pullSelfAssess: SelfAssessmentAnswer?
    @State private var pullConfirmed = false

    // D. Core — immer optional, nie Testpflicht; laut Epic KEINE
    // Selbsteinschaetzungs-Alternative (nur Test-oder-Skip, siehe
    // `BaselineAssessmentEvaluator.evaluateCore`).
    @State private var coreTimer = PausableTimerState()
    @State private var coreSeconds: Int?
    @State private var coreSkipped = false

    // E. Cardio — nur bei Hybrid-Ziel (siehe `showsCardioStep`), reiner
    // 4-Optionen-Selbstbericht ohne Test/Selbsteinschaetzungs-Weiche.
    @State private var cardioAnswer: CardioBaselineAnswer?
    @State private var cardioSkipped = false

    // Woche 1
    @State private var intensity: FirstWeekIntensity = .comfortablyChallenging

    init(
        entryMode: EntryMode,
        goal: TrainingGoal,
        equipmentPreferences: Set<Equipment>,
        onFinish: @escaping (BaselineAssessment?) -> Void
    ) {
        self.entryMode = entryMode
        self.goal = goal
        self.equipmentPreferences = equipmentPreferences
        self.onFinish = onFinish
        let initialMode: FamilyMode = entryMode == .selfAssessment ? .selfAssess : .test
        _pushMode = State(initialValue: initialMode)
        _legsMode = State(initialValue: initialMode)
        _pullMode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
                .navigationTitle(Text("baseline.flow.title", bundle: .module))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        // Task 8: ohne bereits erfasste Fortschritte
                        // weiterhin sofortiges kommentarloses Schliessen
                        // (`isDirty == false`) -- mit mindestens einer
                        // bereits bearbeiteten Bewegungsfamilie (oder
                        // Sicherheitsfrage/Wochenintensitaet) fragt derselbe
                        // Button jetzt erst per `discardChangesConfirmation`
                        // nach.
                        Button {
                            if isDirty {
                                showingDiscardConfirm = true
                            } else {
                                onFinish(nil)
                                dismiss()
                            }
                        } label: {
                            Text("common.close", bundle: .module)
                        }
                    }
                }
                .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                    onFinish(nil)
                    dismiss()
                }
                // Task 8: interaktives Wegziehen des Sheets ist sonst ein
                // ungesicherter Verlassen-Weg am Discard-Dialog vorbei.
                // Ohne Fortschritt (`!isDirty`) bleibt es normal moeglich.
                .interactiveDismissDisabled(isDirty)
        }
    }

    /// Task 8: "bereits bearbeitete Bewegungsfamilie" (oder Sicherheitsfrage/
    /// Wochenintensitaet) als Entwurfs-Signal -- reine Navigation im `path`
    /// OHNE erfasste Daten zaehlt bewusst NICHT (Epic-Vorgabe "nie ein Gate":
    /// frei herumklicken ohne etwas einzugeben soll keine Rueckfrage ausloesen).
    /// Reuses `familyStatus` (bereits die Open/Recorded/Skipped-Wahrheit pro
    /// Familie) statt eine zweite, parallele Pruefung zu erfinden.
    private var isDirty: Bool {
        safetyStatus != nil
            || familyStatus(.push) != .open
            || familyStatus(.legs) != .open
            || familyStatus(.pull) != .open
            || familyStatus(.core) != .open
            || familyStatus(.cardio) != .open
            || intensity != .comfortablyChallenging
    }

    @ViewBuilder
    private var rootContent: some View {
        if entryMode == .guidedTest && safetyStatus == nil {
            safetyGateScreen
        } else {
            overviewScreen
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .push:      pushDetailScreen
        case .legs:      legsDetailScreen
        case .pull:      pullDetailScreen
        case .core:      coreDetailScreen
        case .cardio:    cardioDetailScreen
        case .intensity: intensityDetailScreen
        case .result:    resultDetailScreen
        }
    }

    // MARK: - Abgeleitete Flags

    /// Epic: Cardio nur bei Lauf-/Hybrid-Ziel. `TrainingGoal` kannte bis
    /// P2.2 kein eigenes "Lauf"-Case (siehe Audit) — `.hybrid` ("Kraft +
    /// Ausdauer + Mobilitaet") war deshalb der naheliegendste bestehende
    /// Proxy dafuer. Seit P2.2 traegt `.endurance` ("Laufen & Ausdauer")
    /// genau das urspruenglich gemeinte "Lauf-Ziel" direkt — ohne diesen
    /// Fall haette ein `.endurance`-Nutzer den Cardio-Schritt gar nicht
    /// mehr gesehen, obwohl die Vorgabe hier wortwoertlich "Lauf-/Hybrid-
    /// Ziel" nennt.
    private var showsCardioStep: Bool {
        goal == .hybrid || goal == .endurance
    }

    /// Entrypoint `.selfAssessment` (Erfahrene oder "Selbst einschaetzen")
    /// UND ein `.flagged`-Sicherheitsergebnis schalten JEDE Familie direkt
    /// auf Selbsteinschaetzung um — der gefuehrte Belastungstest wird in
    /// beiden Faellen gar nicht erst angeboten (Epic: "Lieber ohne Test ->
    /// keinen Belastungstest").
    private var isGuidedTestAllowed: Bool {
        entryMode == .guidedTest && safetyStatus == .clear
    }

    private var pullHasGymEquipment: Bool {
        equipmentPreferences.contains(.cable) || equipmentPreferences.contains(.machine)
    }

    private var pullTestPhysicallyAvailable: Bool {
        pullHasGymEquipment || hasPullUpBar == true
    }

    private func commitAndFinish() {
        onFinish(assembleBaselineAssessment())
        dismiss()
    }

    // MARK: - Sicherheitsgate (unaufdringlich, 2 Antworten)

    @ViewBuilder
    private var safetyGateScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("baseline.step.title", bundle: .module)
                    .font(.title2.weight(.bold))
                VStack(alignment: .leading, spacing: 14) {
                    Label {
                        Text("baseline.safety.title", bundle: .module)
                            .font(.headline)
                    } icon: {
                        Image(systemName: "cross.case.fill")
                            .foregroundStyle(.orange)
                    }
                    Text("baseline.safety.question", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) {
                            safetyButton(.clear)
                            safetyButton(.flagged)
                        }
                    } else {
                        HStack(spacing: 10) {
                            safetyButton(.clear)
                            safetyButton(.flagged)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// `@ViewBuilder` + if/else statt `.buttonStyle(status == .clear ?
    /// .borderedProminent : .bordered)`: `.borderedProminent`/`.bordered`
    /// sind verschiedene konkrete Typen (nicht nur verschiedene Werte
    /// desselben Enums wie z.B. `FamilyMode`), ein Ternary kann `buttonStyle`s
    /// generischen Parameter also nicht auf einen gemeinsamen Typ vereinheit-
    /// lichen — scheitert real im Xcode-Build ("type 'ButtonStyle' has no
    /// member 'borderedProminent'"), auf dem Linux-Toolchain aber unsichtbar,
    /// weil SwiftUI-Dateien dort nie typgeprueft werden (siehe Verifikations-
    /// Luecke in der Session-Doku). Jeder Zweig bekommt stattdessen seinen
    /// eigenen, nicht-bedingten `.buttonStyle(...)`-Aufruf.
    @ViewBuilder
    private func safetyButton(_ status: SafetyStatus) -> some View {
        let button = Button {
            safetyStatus = status
            if status == .flagged {
                // "Lieber ohne Test" erzwingt JEDE Familie auf Selbstein-
                // schaetzung (siehe `isGuidedTestAllowed`) — ohne diese
                // Synchronisierung bliebe `pushMode`/`legsMode`/`pullMode`
                // auf ihrem `.test`-Init-Default stehen, obwohl die Detail-
                // Screens bereits den Selbsteinschaetzungs-Inhalt zeigen
                // (siehe `pushDetailScreen` etc.): die Uebersicht wuerde
                // eine ausgefuellte Selbsteinschaetzung dann faelschlich
                // weiter als "Offen" anzeigen, weil `familyStatus` ueber
                // `mode == .test` statt `isGuidedTestAllowed` entscheidet.
                pushMode = .selfAssess
                legsMode = .selfAssess
                pullMode = .selfAssess
            }
        } label: {
            Text(status == .clear ? "baseline.safety.option.clear" : "baseline.safety.option.flagged", bundle: .module)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        if status == .clear {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    // MARK: - Uebersicht (Hub)

    @ViewBuilder
    private var overviewScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if safetyStatus == .flagged {
                    Label {
                        Text("baseline.safety.flaggedNote", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("baseline.overview.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("baseline.overview.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    familyOverviewRow(.push)
                    familyOverviewRow(.legs)
                    if showsCardioStep {
                        familyOverviewRow(.cardio)
                    }
                }

                DisclosureGroup {
                    VStack(spacing: 10) {
                        familyOverviewRow(.pull)
                        familyOverviewRow(.core)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("baseline.overview.expandTitle", bundle: .module)
                        .font(.callout.weight(.medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar("onboarding.nav.next") {
                path.append(.intensity)
            }
        }
    }

    private func familyOverviewRow(_ route: Route) -> some View {
        Button {
            resetModeIfSkipped(route)
            path.append(route)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: familyIcon(route))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(familyOverviewTitle(route))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(familyOverviewSubtitle(route))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                familyStatusBadge(route)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Hebt ein vorheriges "Ueberspringen" auf, sobald der Nutzer die Karte
    /// erneut oeffnet. Ohne das bliebe `pushMode`/`legsMode`/`pullMode` auf
    /// `.skip` stehen, obwohl `pushDetailScreen` & Co. fuer `.skip` denselben
    /// Inhalt wie `.test` zeigen (siehe deren `!isGuidedTestAllowed ||
    /// mode == .selfAssess`-Weiche) — der "Speichern"-Balken haengt dagegen
    /// an der strengeren Bedingung `mode == .test` und wuerde fehlen, und
    /// `modeFooter` haette den irrefuehrenden Link "Zurueck zum Test"
    /// obwohl bereits Testinhalt sichtbar ist. Erneutes Betreten zaehlt als
    /// bewusstes "ich ueberlege es mir anders", kein neues Ueberspringen.
    private func resetModeIfSkipped(_ route: Route) {
        // `isGuidedTestAllowed` statt `entryMode` allein: deckt zusaetzlich
        // ein zwischenzeitlich geflaggtes Sicherheitsergebnis ab (siehe
        // `safetyButton`) — sonst koennte ein Skip NACH dem Flaggen hier
        // faelschlich wieder auf `.test` zurueckfallen.
        let fallback: FamilyMode = isGuidedTestAllowed ? .test : .selfAssess
        switch route {
        case .push: if pushMode == .skip { pushMode = fallback }
        case .legs: if legsMode == .skip { legsMode = fallback }
        case .pull: if pullMode == .skip { pullMode = fallback }
        case .core, .cardio, .intensity, .result: break
        }
    }

    private func familyIcon(_ route: Route) -> String {
        switch route {
        case .push:   "figure.strengthtraining.traditional"
        case .legs:   "figure.strengthtraining.functional"
        case .pull:   "figure.climbing"
        case .core:   "figure.core.training"
        case .cardio: "figure.run"
        case .intensity, .result: "circle"
        }
    }

    private func familyOverviewTitle(_ route: Route) -> String {
        switch route {
        case .push:   String(localized: "baseline.family.push.title", bundle: .module)
        case .legs:   String(localized: "baseline.family.legs.title", bundle: .module)
        case .pull:   String(localized: "baseline.family.pull.title", bundle: .module)
        case .core:   String(localized: "baseline.family.core.title", bundle: .module)
        case .cardio: String(localized: "baseline.family.cardio.title", bundle: .module)
        case .intensity, .result: ""
        }
    }

    private func familyOverviewSubtitle(_ route: Route) -> String {
        switch route {
        case .push:   String(localized: "baseline.family.push.overviewSubtitle", bundle: .module)
        case .legs:   String(localized: "baseline.family.legs.overviewSubtitle", bundle: .module)
        case .pull:   String(localized: "baseline.family.pull.overviewSubtitle", bundle: .module)
        case .core:   String(localized: "baseline.family.core.overviewSubtitle", bundle: .module)
        case .cardio: String(localized: "baseline.family.cardio.overviewSubtitle", bundle: .module)
        case .intensity, .result: ""
        }
    }

    private func familyStatus(_ route: Route) -> FamilyStatus {
        switch route {
        case .push:   status(mode: pushMode, confirmed: pushConfirmed, selfAssess: pushSelfAssess)
        case .legs:   status(mode: legsMode, confirmed: legsConfirmed, selfAssess: legsSelfAssess)
        case .pull:   status(mode: pullMode, confirmed: pullConfirmed, selfAssess: pullSelfAssess)
        case .core:   coreSkipped ? .skipped : (coreSeconds != nil ? .recorded : .open)
        case .cardio: cardioSkipped ? .skipped : (cardioAnswer != nil ? .recorded : .open)
        case .intensity, .result: .open
        }
    }

    private func status(mode: FamilyMode, confirmed: Bool, selfAssess: SelfAssessmentAnswer?) -> FamilyStatus {
        switch mode {
        case .skip:       .skipped
        case .test:       confirmed ? .recorded : .open
        case .selfAssess: selfAssess != nil ? .recorded : .open
        }
    }

    /// Status wird NIE nur ueber Farbe vermittelt — Icon-Form UND Text sind
    /// immer beide vorhanden (`accessibilityDifferentiateWithoutColor`-sicher).
    private func familyStatusBadge(_ route: Route) -> some View {
        let (icon, key, color): (String, String, Color) = {
            switch familyStatus(route) {
            case .open:     return ("circle", "baseline.status.open", .secondary)
            case .recorded: return ("checkmark.circle.fill", "baseline.status.recorded", .green)
            case .skipped:  return ("minus.circle.fill", "baseline.status.skipped", .secondary)
            }
        }()
        return Label {
            Text(String(localized: LocalizedStringResource(String.LocalizationValue(key), bundle: .fitnessAppUI)))
        } icon: {
            Image(systemName: icon)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .labelStyle(.titleAndIcon)
    }

    // MARK: - A. Push

    @ViewBuilder
    private var pushDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: familyOverviewTitle(.push),
                    cue1: String(localized: "baseline.family.push.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.push.cue2", bundle: .module),
                    exerciseName: "Liegestütze"
                )
                if !isGuidedTestAllowed || pushMode == .selfAssess {
                    selfAssessPicker(
                        title: String(localized: "baseline.selfAssess.push.title", bundle: .module),
                        selection: poppingSelfAssessBinding($pushSelfAssess)
                    )
                } else {
                    pushTestContent
                }
                modeFooter(mode: $pushMode) {
                    pushMode = .skip
                    path.removeLast()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if isGuidedTestAllowed, pushMode == .test {
                bottomActionBar("baseline.action.saveAndContinue") {
                    pushConfirmed = true
                    path.removeLast()
                }
            }
        }
    }

    private var pushTestContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("baseline.push.variant.title", bundle: .module)
                .font(.headline)
            VStack(spacing: 8) {
                ForEach(PushUpVariant.allCases, id: \.self) { variant in
                    optionRow(title: String(localized: variant.localizedName), isSelected: pushVariant == variant) {
                        pushVariant = variant
                        if variant == .noCleanRep { pushReps = 0 }
                    }
                }
            }
            if pushVariant == .noCleanRep {
                Text("baseline.push.zeroRepsNote", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Stepper(value: $pushReps, in: 0...50) {
                    HStack {
                        Text("baseline.push.reps.label", bundle: .module)
                        Spacer()
                        Text("\(pushReps)").font(.body.weight(.semibold).monospacedDigit())
                    }
                }
                Text("baseline.push.reps.hint", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - B. Legs

    @ViewBuilder
    private var legsDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: familyOverviewTitle(.legs),
                    cue1: String(localized: "baseline.family.legs.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.legs.cue2", bundle: .module),
                    exerciseName: "Kniebeuge (BW)"
                )
                if !isGuidedTestAllowed || legsMode == .selfAssess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("baseline.legs.noChairAssessIntro", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        selfAssessPicker(
                            title: String(localized: "baseline.selfAssess.legs.title", bundle: .module),
                            selection: poppingSelfAssessBinding($legsSelfAssess)
                        )
                    }
                } else {
                    chairSquatTestContent
                }
                modeFooter(mode: $legsMode) {
                    legsTimer.cancel()
                    legsMode = .skip
                    path.removeLast()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if isGuidedTestAllowed, legsMode == .test {
                if legsTimer.phase == .finished {
                    bottomActionBar("baseline.action.saveAndContinue") {
                        legsConfirmed = true
                        path.removeLast()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chairSquatTestContent: some View {
        if legsTimer.phase == .finished {
            VStack(alignment: .leading, spacing: 14) {
                Text("baseline.legs.confirmReps.title", bundle: .module)
                    .font(.headline)
                Stepper(value: $legsReps, in: 0...50) {
                    HStack {
                        Text("baseline.legs.reps.label", bundle: .module)
                        Spacer()
                        Text("\(legsReps)").font(.body.weight(.semibold).monospacedDigit())
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("baseline.legs.timer.instructions", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let elapsed = legsTimer.elapsed(now: context.date)
                    let remaining = max(0, 30 - Int(elapsed.rounded(.up)))
                    VStack(spacing: 14) {
                        Text(timeString(remaining))
                            .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .accessibilityLabel(Text(String(format: String(localized: "baseline.timer.remaining.a11y", bundle: .module), remaining)))
                            .accessibilityAddTraits(.updatesFrequently)

                        timerControls(phase: legsTimer.phase, now: context.date, timer: $legsTimer)
                    }
                    .onChange(of: remaining == 0) { _, reachedZero in
                        if reachedZero, legsTimer.phase == .running {
                            legsTimer.finish(now: context.date)
                        }
                    }
                }
            }
        }
    }

    // MARK: - C. Pull

    @ViewBuilder
    private var pullDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: familyOverviewTitle(.pull),
                    cue1: String(localized: "baseline.family.pull.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.pull.cue2", bundle: .module),
                    exerciseName: pullHasGymEquipment ? "Latzug (weit)" : "Klimmzug (assistiert)"
                )
                pullBodyContent
                modeFooter(mode: $pullMode, testAvailable: pullTestPhysicallyAvailable) {
                    pullMode = .skip
                    path.removeLast()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if isGuidedTestAllowed, pullMode == .test, pullTestPhysicallyAvailable {
                bottomActionBar("baseline.action.saveAndContinue") {
                    pullConfirmed = true
                    path.removeLast()
                }
            }
        }
        .keyboardDismissToolbar()
    }

    @ViewBuilder
    private var pullBodyContent: some View {
        if !isGuidedTestAllowed || pullMode == .selfAssess {
            selfAssessPicker(
                title: String(localized: "baseline.selfAssess.pull.title", bundle: .module),
                selection: poppingSelfAssessBinding($pullSelfAssess)
            )
        } else if pullHasGymEquipment {
            latPulldownTestContent
        } else if hasPullUpBar == nil {
            pullBarQuestion
        } else if hasPullUpBar == true {
            pullUpTestContent
        } else {
            noPullEquipmentNote
        }
    }

    private var pullBarQuestion: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("baseline.pull.barQuestion.title", bundle: .module)
                .font(.headline)
            HStack(spacing: 10) {
                Button {
                    hasPullUpBar = true
                } label: {
                    Text("common.yes", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    hasPullUpBar = false
                } label: {
                    Text("common.no", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var pullUpTestContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("baseline.pull.pullUpVariant.title", bundle: .module)
                .font(.headline)
            VStack(spacing: 8) {
                ForEach([PullVariant.pullUp, .assistedPullUp], id: \.self) { variant in
                    optionRow(title: String(localized: variant.localizedName), isSelected: pullVariant == variant) {
                        pullVariant = variant
                    }
                }
            }
            Stepper(value: $pullReps, in: 0...30) {
                HStack {
                    Text("baseline.pull.reps.label", bundle: .module)
                    Spacer()
                    Text("\(pullReps)").font(.body.weight(.semibold).monospacedDigit())
                }
            }
        }
    }

    private var latPulldownTestContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("baseline.pull.latPulldown.intro", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
            decimalInputRow(label: String(localized: "baseline.pull.latPulldown.weight.label", bundle: .module), value: $pullLoadKg)
            Stepper(value: $pullReps, in: 0...20) {
                HStack {
                    Text("baseline.pull.latPulldown.reps.label", bundle: .module)
                    Spacer()
                    Text("\(pullReps)").font(.body.weight(.semibold).monospacedDigit())
                }
            }
            Stepper(value: $pullRir, in: 0...5, step: 0.5) {
                HStack {
                    Text("baseline.pull.latPulldown.rir.label", bundle: .module)
                    Spacer()
                    Text(Float(pullRir).formattedRIR)
                        .font(.body.weight(.semibold).monospacedDigit())
                }
            }
            Text("baseline.pull.latPulldown.rirHint", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var noPullEquipmentNote: some View {
        Text("baseline.pull.noEquipmentNote", bundle: .module)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - D. Core

    @ViewBuilder
    private var coreDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: familyOverviewTitle(.core),
                    cue1: String(localized: "baseline.family.core.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.core.cue2", bundle: .module),
                    exerciseName: "Plank"
                )
                Text("baseline.core.instructions", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let seconds = coreSeconds {
                    Stepper(value: Binding(get: { seconds }, set: { coreSeconds = $0 }), in: 0...60) {
                        HStack {
                            Text("baseline.core.seconds.label", bundle: .module)
                            Spacer()
                            Text("\(seconds)s").font(.body.weight(.semibold).monospacedDigit())
                        }
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 0.2)) { context in
                        let elapsedRaw = coreTimer.elapsed(now: context.date)
                        let display = min(60, Int(elapsedRaw))
                        VStack(spacing: 14) {
                            Text(timeString(display))
                                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText())
                                .accessibilityLabel(Text(String(format: String(localized: "baseline.timer.elapsed.a11y", bundle: .module), display)))
                                .accessibilityAddTraits(.updatesFrequently)

                            timerControls(phase: coreTimer.phase, now: context.date, timer: $coreTimer)

                            if coreTimer.phase == .running || coreTimer.phase == .paused {
                                Button {
                                    coreSeconds = min(60, Int(coreTimer.elapsed(now: context.date)))
                                    coreTimer.finish(now: context.date)
                                } label: {
                                    Text("baseline.core.doneButton", bundle: .module)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .onChange(of: elapsedRaw >= 60) { _, reachedCap in
                            if reachedCap, coreTimer.phase == .running {
                                coreSeconds = 60
                                coreTimer.finish(now: context.date)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if coreSeconds != nil {
                bottomActionBar("baseline.action.saveAndContinue") {
                    path.removeLast()
                }
            } else {
                bottomActionBar("baseline.action.skipExercise") {
                    coreTimer.cancel()
                    coreSkipped = true
                    path.removeLast()
                }
            }
        }
    }

    // MARK: - E. Cardio

    @ViewBuilder
    private var cardioDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: familyOverviewTitle(.cardio),
                    cue1: String(localized: "baseline.family.cardio.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.cardio.cue2", bundle: .module),
                    exerciseName: "Freier Lauf"
                )
                VStack(spacing: 8) {
                    ForEach(CardioBaselineAnswer.allCases, id: \.self) { answer in
                        optionRow(title: String(localized: answer.localizedName), isSelected: cardioAnswer == answer) {
                            cardioAnswer = answer
                            cardioSkipped = false
                            path.removeLast()
                        }
                    }
                }
                // Cardio sitzt in der Uebersicht auf derselben Ebene wie
                // Push/Beine (nicht unter "Optional erweitern") und braucht
                // daher denselben expliziten Ueberspringen-Link wie jede
                // andere Familie — sonst waere der native Zurueck-Button der
                // einzige (unsichtbare) Ausweg, inkonsistent zum Rest des Flows.
                HStack {
                    footerLink("baseline.action.skipExercise") {
                        cardioSkipped = true
                        path.removeLast()
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.deltiqOrange)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Woche 1

    @ViewBuilder
    private var intensityDetailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("baseline.intensity.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("baseline.intensity.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    ForEach(FirstWeekIntensity.allCases, id: \.self) { option in
                        intensityRow(option)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar("onboarding.nav.next") {
                path.append(.result)
            }
        }
    }

    private func intensityRow(_ option: FirstWeekIntensity) -> some View {
        let isSelected = intensity == option
        return Button {
            intensity = option
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.localizedName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.localizedBlurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(isSelected ? 0.10 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ergebnis als Plan-Bruecke (nie eine Zahl/Note)

    private enum OverallTendency { case veryLow, low, moderate, high, unknown }

    private func overallTendency(for bands: BaselineBands) -> OverallTendency {
        let relevant = [bands.push, bands.legs, bands.pull].filter { $0 != .unknown }
        guard !relevant.isEmpty else { return .unknown }
        if relevant.contains(.veryLow) { return .veryLow }
        if relevant.contains(.low) { return .low }
        if relevant.allSatisfy({ $0 == .high }) { return .high }
        return .moderate
    }

    private func overallSummaryText(for bands: BaselineBands) -> LocalizedStringResource {
        switch overallTendency(for: bands) {
        case .veryLow:  LocalizedStringResource("baseline.result.overall.veryLow",  bundle: .fitnessAppUI)
        case .low:      LocalizedStringResource("baseline.result.overall.low",      bundle: .fitnessAppUI)
        case .moderate: LocalizedStringResource("baseline.result.overall.moderate", bundle: .fitnessAppUI)
        case .high:     LocalizedStringResource("baseline.result.overall.high",     bundle: .fitnessAppUI)
        case .unknown:  LocalizedStringResource("baseline.result.overall.unknown",  bundle: .fitnessAppUI)
        }
    }

    @ViewBuilder
    private var resultDetailScreen: some View {
        let assembled = assembleBaselineAssessment()
        let bands = BaselineAssessmentEvaluator.evaluate(assembled)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(maxWidth: .infinity)

                Text("baseline.result.title", bundle: .module)
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Epic Punkt 5: maximal 2 Aussagen, keine Kategorie/Score.
                VStack(alignment: .leading, spacing: 10) {
                    Text(overallSummaryText(for: bands))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("baseline.result.recheckNote", bundle: .module)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if assembled.safetyStatus == .flagged {
                    Label {
                        Text("baseline.result.safetyNote", bundle: .module)
                    } icon: {
                        Image(systemName: "cross.case.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        resultDetailRow(.push)
                        resultDetailRow(.legs)
                        resultDetailRow(.pull)
                        resultDetailRow(.core)
                        if showsCardioStep {
                            resultDetailRow(.cardio)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("baseline.result.detailsTitle", bundle: .module)
                        .font(.callout.weight(.medium))
                }

                // Bis Phase 4 (PlanAdapter existiert noch nicht) explizit
                // klarstellen: der Check veraendert den Plan NICHT sofort
                // automatisch.
                Text("baseline.result.phaseNote", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar("baseline.result.planButton") {
                commitAndFinish()
            }
        }
    }

    private func resultDetailRow(_ route: Route) -> some View {
        HStack {
            Text(familyOverviewTitle(route))
                .font(.caption.weight(.medium))
            Spacer()
            familyStatusBadge(route)
        }
    }

    /// Baut das finale `BaselineAssessment` strikt aus dem, was der Nutzer
    /// tatsaechlich gemacht hat — NIE aus `pushReps`/`pullReps` etc. allein,
    /// weil deren Default (0) sonst nicht von einem bewussten Uebersprung zu
    /// unterscheiden waere. Jede Familie prueft ihren eigenen `*Mode`
    /// explizit; `.skip` (und, bei Pull, "kein Equipment + keine Stange")
    /// lassen BEIDE Felder (Test + Selbsteinschaetzung) `nil` — die Familie
    /// bleibt beim Evaluator dann korrekt `.unknown`.
    private func assembleBaselineAssessment() -> BaselineAssessment {
        var pushUp: PushUpAssessment?
        var pushSelf: SelfAssessmentAnswer?
        if isGuidedTestAllowed && pushMode == .test && pushConfirmed {
            pushUp = PushUpAssessment(variant: pushVariant, cleanReps: pushVariant == .noCleanRep ? 0 : pushReps)
        } else if pushMode == .selfAssess || !isGuidedTestAllowed {
            pushSelf = pushSelfAssess
        }

        var chairSquat: ChairSquatAssessment?
        var legsSelf: SelfAssessmentAnswer?
        if isGuidedTestAllowed && legsMode == .test && legsConfirmed {
            chairSquat = ChairSquatAssessment(cleanReps: legsReps, durationSeconds: 30)
        } else if legsMode == .selfAssess || !isGuidedTestAllowed {
            legsSelf = legsSelfAssess
        }

        var pull: PullAssessment?
        var pullSelf: SelfAssessmentAnswer?
        if isGuidedTestAllowed && pullMode == .test && pullConfirmed && pullHasGymEquipment {
            pull = PullAssessment(variant: .latPulldown, cleanReps: pullReps, loadKg: pullLoadKg, rir: pullRir)
        } else if isGuidedTestAllowed && pullMode == .test && pullConfirmed && hasPullUpBar == true {
            pull = PullAssessment(variant: pullVariant, cleanReps: pullReps)
        } else if pullMode == .selfAssess || !isGuidedTestAllowed {
            pullSelf = pullSelfAssess
        }
        // Uebrige Faelle (Test-Modus ohne Bestaetigung oder ohne jegliches
        // Pull-Equipment, oder explizites Skip) -> beide Felder bleiben nil.

        let plank = coreSeconds.map { PlankAssessment(seconds: $0) }
        let cardio = (showsCardioStep ? cardioAnswer : nil).map { CardioBaseline(answer: $0) }

        return BaselineAssessment(
            date: Date(),
            source: entryMode == .guidedTest ? .guidedTest : .selfAssessment,
            safetyStatus: safetyStatus ?? .clear,
            pushUp: pushUp,
            chairSquat: chairSquat,
            pull: pull,
            plank: plank,
            cardio: cardio,
            pushSelfAssessment: pushSelf,
            legsSelfAssessment: legsSelf,
            pullSelfAssessment: pullSelf,
            desiredFirstWeekIntensity: intensity
        )
    }

    // MARK: - Geteilte Bausteine

    private func familyHeader(title: String, cue1: String, cue2: String, exerciseName: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ExerciseGifView(exerciseName: exerciseName, displayName: title, animated: true)
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                cueRow(cue1)
                cueRow(cue2)
            }
        }
    }

    /// Nimmt bewusst den bereits aufgeloesten Text entgegen statt eines
    /// Lokalisierungs-Keys: `LocalizedStringResource`/`Text(_:bundle:)`
    /// akzeptieren nur Compile-Zeit-Literale als Key, kein `String`-
    /// Laufzeitwert (siehe `String(localized:bundle:)` an den Aufrufstellen) —
    /// dasselbe bereits etablierte Muster wie `OnboardingView.coachingCard`.
    private func cueRow(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.seal")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Fusszeile unter jeder Test-/Selbsteinschaetzungs-Ansicht: bietet den
    /// jeweils passenden Wechsel-Link (Test<->Selbsteinschaetzung) und IMMER
    /// "Ueberspringen" (`onSkip`, uebernimmt auch das Zuruecknavigieren).
    /// `testAvailable` blendet NUR den Rueckweg "Zurueck zum Test" aus,
    /// solange physisch kein Test moeglich ist (kein Equipment) — der
    /// Hinweg "Stattdessen selbst einschaetzen" bleibt davon bewusst
    /// UNBERUEHRT: Selbsteinschaetzung braucht nie Equipment, und genau in
    /// diesem Fall (z.B. Pull ohne Klimmzugstange/Kabelzug, siehe
    /// `noPullEquipmentNote`) ist sie die einzige sinnvolle Alternative zum
    /// blossen Ueberspringen. "Ueberspringen" bleibt ohnehin immer erreichbar.
    @ViewBuilder
    private func modeFooter(mode: Binding<FamilyMode>, testAvailable: Bool = true, onSkip: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            if isGuidedTestAllowed {
                if mode.wrappedValue == .test {
                    footerLink("baseline.action.switchToSelfAssess") { mode.wrappedValue = .selfAssess }
                } else if testAvailable {
                    footerLink("baseline.action.backToTest") { mode.wrappedValue = .test }
                }
            }
            footerLink("baseline.action.skipExercise", action: onSkip)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.deltiqOrange)
        .buttonStyle(.plain)
    }

    /// Kleiner Text-Link. Nimmt bewusst einen Compile-Zeit-Key entgegen
    /// (kein `String`-Laufzeitwert): `key` wird hier IMMER als String-
    /// LITERAL am Aufrufort uebergeben, wodurch `Text(_:bundle:)` korrekt
    /// ueber `LocalizedStringKey` lokalisiert (siehe `cueRow` fuer die
    /// Gegenprobe mit einem echten Laufzeitwert).
    private func footerLink(_ key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key, bundle: .module)
        }
    }

    /// Unten angeheftete Primaeraktion — konsistent fuer Uebersicht,
    /// Wochenintensitaet, Ergebnis und jede Familien-Bestaetigung
    /// ("Speichern"). `key` ist wie bei `footerLink` immer ein
    /// Compile-Zeit-Literal am Aufrufort.
    private func bottomActionBar(_ key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                Text(key, bundle: .module)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .background(.bar)
    }

    /// Wrappt eine `SelfAssessmentAnswer?`-Binding so, dass das Setzen EINES
    /// echten Werts (Tap auf eine Option) automatisch zur Uebersicht
    /// zurueck-navigiert — eine Single-Select-Auswahl ist bereits die
    /// vollstaendige, abgeschlossene Aktion (kein separates "Speichern"
    /// noetig, siehe `docs/BASELINE_CHECK_UX.md` §5).
    private func poppingSelfAssessBinding(_ base: Binding<SelfAssessmentAnswer?>) -> Binding<SelfAssessmentAnswer?> {
        Binding(
            get: { base.wrappedValue },
            set: { newValue in
                base.wrappedValue = newValue
                if newValue != nil { path.removeLast() }
            }
        )
    }

    private func selfAssessPicker(title: String, selection: Binding<SelfAssessmentAnswer?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(spacing: 8) {
                ForEach(SelfAssessmentAnswer.allCases, id: \.self) { answer in
                    optionRow(title: String(localized: answer.localizedName), isSelected: selection.wrappedValue == answer) {
                        selection.wrappedValue = answer
                    }
                }
            }
        }
    }

    private func optionRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(isSelected ? 0.10 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func decimalInputRow(label: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(0...1)))
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .decimalKeyboard()
        }
    }

    @ViewBuilder
    private func timerControls(phase: PausableTimerState.Phase, now: Date, timer: Binding<PausableTimerState>) -> some View {
        HStack(spacing: 14) {
            switch phase {
            case .idle:
                Button {
                    timer.wrappedValue.start(now: now)
                } label: {
                    Label { Text("baseline.timer.start", bundle: .module) } icon: { Image(systemName: "play.fill") }
                }
                .buttonStyle(.borderedProminent)
            case .running:
                Button {
                    timer.wrappedValue.pause(now: now)
                } label: {
                    Label { Text("baseline.timer.pause", bundle: .module) } icon: { Image(systemName: "pause.fill") }
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    timer.wrappedValue.cancel()
                } label: {
                    Text("baseline.timer.cancel", bundle: .module)
                }
                .buttonStyle(.bordered)
            case .paused:
                Button {
                    timer.wrappedValue.resume(now: now)
                } label: {
                    Label { Text("baseline.timer.resume", bundle: .module) } icon: { Image(systemName: "play.fill") }
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    timer.wrappedValue.cancel()
                } label: {
                    Text("baseline.timer.cancel", bundle: .module)
                }
                .buttonStyle(.bordered)
            case .finished:
                Label { Text("baseline.timer.finished", bundle: .module) } icon: { Image(systemName: "checkmark.circle.fill") }
                    .foregroundStyle(.green)
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Start-Check (gefuehrter Test)") {
    BaselineCheckFlowView(entryMode: .guidedTest, goal: .hybrid, equipmentPreferences: [.bodyweight]) { _ in }
}
#endif
#endif
