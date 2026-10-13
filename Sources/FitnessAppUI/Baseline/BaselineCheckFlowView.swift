#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Eigenstaendiger Sub-Wizard als Sheet fuer den optionalen Start-Check
/// "Wo stehst du heute?" (siehe `OnboardingView.baselineCheckStep`, der
/// einzige Aufrufer). Struktur folgt bewusst `PlanBuilderView` (anderer
/// Sub-Wizard-als-Sheet in dieser Codebase): `NavigationStack`, oberer
/// Fortschritt, `Group { switch step { ... } }`, untere Zurueck/Weiter-Leiste.
///
/// Liefert dem Aufrufer nur per `onFinish` ein fertiges `BaselineAssessment`
/// zurueck (oder `nil` bei Abbruch) — legt selbst NICHTS in SwiftData an und
/// kennt kein `UserBodyProfile`. `OnboardingView.finishOnboarding()` schreibt
/// das Ergebnis erst zusammen mit dem restlichen Profil.
///
/// Nie ein Gate (Epic-Vorgabe): jeder Schritt ausser der einmaligen
/// Sicherheitsfrage ist ohne Eingabe weiter-klickbar, jede Bewegungsfamilie
/// einzeln ueberspringbar.
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

    let entryMode: EntryMode
    let goal: TrainingGoal
    let equipmentPreferences: Set<Equipment>
    let onFinish: (BaselineAssessment?) -> Void

    @Environment(\.dismiss) private var dismiss

    enum FlowStep: Int, CaseIterable {
        case safety, push, legs, pull, core, cardio, intensity, result
    }

    @State private var step: FlowStep = .safety

    // Sicherheit — UI-seitig 3 Antworten, auf dem Modell nur 2
    // (`SafetyStatus`): "Ja" und "Unsicher" sind gleich konservativ
    // (siehe `safetyStatus`).
    private enum SafetyAnswer: Sendable, Equatable { case yes, unsure, no }
    @State private var safetyAnswer: SafetyAnswer?

    private var safetyStatus: SafetyStatus? {
        switch safetyAnswer {
        case .yes, .unsure: return .flagged
        case .no: return .clear
        case nil: return nil
        }
    }

    // A. Push
    @State private var pushMode: FamilyMode = .test
    @State private var pushVariant: PushUpVariant = .standard
    @State private var pushReps: Int = 0
    @State private var pushSelfAssess: SelfAssessmentAnswer?

    // B. Legs
    @State private var legsMode: FamilyMode = .test
    @State private var legsTimer = PausableTimerState()
    @State private var legsReps: Int = 0
    @State private var legsSelfAssess: SelfAssessmentAnswer?

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

    // D. Core — immer optional, nie Testpflicht; laut Epic KEINE
    // Selbsteinschaetzungs-Alternative (nur Test-oder-Skip, siehe
    // `BaselineAssessmentEvaluator.evaluateCore`).
    @State private var coreTimer = PausableTimerState()
    @State private var coreSeconds: Int?

    // E. Cardio — nur bei Hybrid-Ziel (siehe `showsCardioStep`), reiner
    // 4-Optionen-Selbstbericht ohne Test/Selbsteinschaetzungs-Weiche.
    @State private var cardioAnswer: CardioBaselineAnswer?

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
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider()
                Group {
                    switch step {
                    case .safety:    safetyStepView
                    case .push:      pushStepView
                    case .legs:      legsStepView
                    case .pull:      pullStepView
                    case .core:      coreStepView
                    case .cardio:    cardioStepView
                    case .intensity: intensityStepView
                    case .result:    resultStepView
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: step)
                Divider()
                navigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(Text("baseline.flow.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onFinish(nil)
                        dismiss()
                    } label: {
                        Text("common.close", bundle: .module)
                    }
                }
            }
        }
    }

    // MARK: - Fortschritt + abgeleitete Flags

    private var visibleSteps: [FlowStep] {
        FlowStep.allCases.filter { $0 != .cardio || showsCardioStep }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let index = visibleSteps.firstIndex(of: step) {
                Text(String(format: String(localized: "baseline.progress.format", bundle: .module), index + 1, visibleSteps.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(visibleSteps, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.deltiqOrange : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }
        }
    }

    /// Epic: Cardio nur bei Lauf-/Hybrid-Ziel. `TrainingGoal` kennt kein
    /// eigenes "Lauf"-Case (siehe Audit) — `.hybrid` ("Kraft + Ausdauer +
    /// Mobilitaet") ist die einzige bestehende Achse mit Ausdaueranteil und
    /// damit der naheliegendste bestehende Proxy dafuer.
    private var showsCardioStep: Bool {
        goal == .hybrid
    }

    /// Entrypoint `.selfAssessment` (Erfahrene oder "Ich schaetze mich
    /// selbst ein") UND ein `.flagged`-Sicherheitsergebnis schalten JEDE
    /// Familie direkt auf Selbsteinschaetzung um — der gefuehrte
    /// Belastungstest wird in beiden Faellen gar nicht erst angeboten
    /// (Epic: "Ja/Unsicher -> keinen Belastungstest").
    private var isGuidedTestAllowed: Bool {
        entryMode == .guidedTest && safetyStatus == .clear
    }

    private var pullHasGymEquipment: Bool {
        equipmentPreferences.contains(.cable) || equipmentPreferences.contains(.machine)
    }

    private var pullTestPhysicallyAvailable: Bool {
        pullHasGymEquipment || hasPullUpBar == true
    }

    // MARK: - Navigation

    private var canAdvance: Bool {
        switch step {
        case .safety: return safetyAnswer != nil
        default: return true
        }
    }

    private var isLastStep: Bool { step == .result }

    private var primaryActionTitle: LocalizedStringResource {
        isLastStep
            ? LocalizedStringResource("baseline.result.doneButton", bundle: .fitnessAppUI)
            : LocalizedStringResource("onboarding.nav.next", bundle: .fitnessAppUI)
    }

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step != .safety {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("common.back", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Button {
                if isLastStep {
                    commitAndFinish()
                } else {
                    goToNextStep()
                }
            } label: {
                Label {
                    Text(primaryActionTitle)
                } icon: {
                    Image(systemName: isLastStep ? "checkmark.circle.fill" : "arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
        }
    }

    private func goToNextStep() {
        guard var next = FlowStep(rawValue: step.rawValue + 1) else { return }
        if next == .cardio && !showsCardioStep {
            next = .intensity
        }
        step = next
    }

    private func goToPreviousStep() {
        guard var prev = FlowStep(rawValue: step.rawValue - 1) else { return }
        if prev == .cardio && !showsCardioStep {
            prev = .core
        }
        step = prev
    }

    private func commitAndFinish() {
        onFinish(assembleBaselineAssessment())
        dismiss()
    }

    // MARK: - A. Safety Gate

    @ViewBuilder
    private var safetyStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text("baseline.safety.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("baseline.safety.question", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    safetyOptionRow(.yes, label: String(localized: "baseline.safety.option.yes", bundle: .module))
                    safetyOptionRow(.unsure, label: String(localized: "baseline.safety.option.unsure", bundle: .module))
                    safetyOptionRow(.no, label: String(localized: "baseline.safety.option.no", bundle: .module))
                }
                if safetyStatus == .flagged {
                    Label {
                        Text("baseline.safety.flaggedNote", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func safetyOptionRow(_ answer: SafetyAnswer, label: String) -> some View {
        let isSelected = safetyAnswer == answer
        return Button {
            safetyAnswer = answer
        } label: {
            HStack {
                Text(label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(isSelected ? 0.10 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - A. Push

    @ViewBuilder
    private var pushStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: String(localized: "baseline.family.push.title", bundle: .module),
                    cue1: String(localized: "baseline.family.push.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.push.cue2", bundle: .module),
                    exerciseName: "Liegestütze"
                )

                if pushMode == .skip {
                    skippedNote
                } else if !isGuidedTestAllowed || pushMode == .selfAssess {
                    selfAssessPicker(title: String(localized: "baseline.selfAssess.push.title", bundle: .module), selection: $pushSelfAssess)
                } else {
                    pushTestContent
                }

                familyModeFooter(mode: $pushMode)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
    private var legsStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: String(localized: "baseline.family.legs.title", bundle: .module),
                    cue1: String(localized: "baseline.family.legs.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.legs.cue2", bundle: .module),
                    exerciseName: "Kniebeuge (BW)"
                )

                if legsMode == .skip {
                    skippedNote
                } else if !isGuidedTestAllowed || legsMode == .selfAssess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("baseline.legs.noChairAssessIntro", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        selfAssessPicker(title: String(localized: "baseline.selfAssess.legs.title", bundle: .module), selection: $legsSelfAssess)
                    }
                } else {
                    chairSquatTestContent
                }

                familyModeFooter(mode: $legsMode)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var chairSquatTestContent: some View {
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

                    Stepper(value: $legsReps, in: 0...50) {
                        HStack {
                            Text("baseline.legs.reps.label", bundle: .module)
                            Spacer()
                            Text("\(legsReps)").font(.body.weight(.semibold).monospacedDigit())
                        }
                    }
                }
                .onChange(of: remaining == 0) { _, reachedZero in
                    if reachedZero, legsTimer.phase == .running {
                        legsTimer.finish(now: context.date)
                    }
                }
            }
        }
    }

    // MARK: - C. Pull

    @ViewBuilder
    private var pullStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: String(localized: "baseline.family.pull.title", bundle: .module),
                    cue1: String(localized: "baseline.family.pull.cue1", bundle: .module),
                    cue2: String(localized: "baseline.family.pull.cue2", bundle: .module),
                    exerciseName: pullHasGymEquipment ? "Latzug (weit)" : "Klimmzug (assistiert)"
                )

                if !isGuidedTestAllowed || pullMode == .selfAssess {
                    selfAssessPicker(title: String(localized: "baseline.selfAssess.pull.title", bundle: .module), selection: $pullSelfAssess)
                } else if pullMode == .skip {
                    skippedNote
                } else if pullHasGymEquipment {
                    latPulldownTestContent
                } else if hasPullUpBar == nil {
                    pullBarQuestion
                } else if hasPullUpBar == true {
                    pullUpTestContent
                } else {
                    noPullEquipmentNote
                }

                familyModeFooter(mode: $pullMode, testAvailable: pullTestPhysicallyAvailable)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
    private var coreStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                familyHeader(
                    title: String(localized: "baseline.family.core.title", bundle: .module),
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

                    Button {
                        coreTimer = PausableTimerState()
                    } label: {
                        Text("baseline.core.skipCta", bundle: .module)
                    }
                    .font(.footnote)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - E. Cardio

    @ViewBuilder
    private var cardioStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("baseline.cardio.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("baseline.cardio.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    ForEach(CardioBaselineAnswer.allCases, id: \.self) { answer in
                        optionRow(title: String(localized: answer.localizedName), isSelected: cardioAnswer == answer) {
                            cardioAnswer = answer
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Woche 1

    @ViewBuilder
    private var intensityStepView: some View {
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

    // MARK: - Ergebnis (nie eine Zahl/Note)

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
    private var resultStepView: some View {
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

                Text(overallSummaryText(for: bands))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

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

                Text("baseline.result.recheckNote", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
        if isGuidedTestAllowed && pushMode == .test {
            pushUp = PushUpAssessment(variant: pushVariant, cleanReps: pushVariant == .noCleanRep ? 0 : pushReps)
        } else if pushMode == .selfAssess || !isGuidedTestAllowed {
            pushSelf = pushSelfAssess
        }

        var chairSquat: ChairSquatAssessment?
        var legsSelf: SelfAssessmentAnswer?
        if isGuidedTestAllowed && legsMode == .test {
            chairSquat = ChairSquatAssessment(cleanReps: legsReps, durationSeconds: 30)
        } else if legsMode == .selfAssess || !isGuidedTestAllowed {
            legsSelf = legsSelfAssess
        }

        var pull: PullAssessment?
        var pullSelf: SelfAssessmentAnswer?
        if isGuidedTestAllowed && pullMode == .test && pullHasGymEquipment {
            pull = PullAssessment(variant: .latPulldown, cleanReps: pullReps, loadKg: pullLoadKg, rir: pullRir)
        } else if isGuidedTestAllowed && pullMode == .test && hasPullUpBar == true {
            pull = PullAssessment(variant: pullVariant, cleanReps: pullReps)
        } else if pullMode == .selfAssess || !isGuidedTestAllowed {
            pullSelf = pullSelfAssess
        }
        // Uebrige Faelle (Test-Modus ohne jegliches Pull-Equipment, oder
        // explizites Skip) -> beide Felder bleiben nil.

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

    /// Fusszeile unter jeder Test-/Selbsteinschaetzungs-Ansicht: je nach
    /// aktuellem `mode` wird "stattdessen einschaetzen", "zurueck zum Test"
    /// und/oder "ueberspringen" angeboten. `testAvailable` erlaubt es Pull,
    /// den Test-Link auszublenden, solange physisch kein Test moeglich ist
    /// (kein Equipment) — "einschaetzen" bleibt trotzdem ueber "ueberspringen
    /// -> einschaetzen" erreichbar (Epic: Selbsteinschaetzung ist IMMER
    /// verfuegbar).
    ///
    /// Sonderfall global erzwungene Selbsteinschaetzung
    /// (`!isGuidedTestAllowed`, z.B. durch das Sicherheits-Flag oder den
    /// `.selfAssessment`-Entrypoint): die jeweilige StepView zeigt dann IMMER
    /// die Selbsteinschaetzung, unabhaengig vom gespeicherten `mode`
    /// (`mode` bleibt dabei oft noch auf dem Default `.test` stehen). Der
    /// "stattdessen einschaetzen"-Link im `.test`-Zweig wird deshalb NUR bei
    /// `isGuidedTestAllowed` gezeigt — sonst wuerde er faelschlich einen noch
    /// nicht eingenommenen Zustand anbieten, der in Wahrheit schon der
    /// angezeigte ist. "Ueberspringen" bleibt davon unberuehrt immer sichtbar.
    @ViewBuilder
    private func familyModeFooter(mode: Binding<FamilyMode>, testAvailable: Bool = true) -> some View {
        let canOfferTest = isGuidedTestAllowed && testAvailable
        HStack(spacing: 16) {
            switch mode.wrappedValue {
            case .test:
                if isGuidedTestAllowed {
                    footerLink("baseline.action.switchToSelfAssess") { mode.wrappedValue = .selfAssess }
                }
                footerLink("baseline.action.skipExercise") { mode.wrappedValue = .skip }
            case .selfAssess:
                if canOfferTest {
                    footerLink("baseline.action.backToTest") { mode.wrappedValue = .test }
                }
                footerLink("baseline.action.skipExercise") { mode.wrappedValue = .skip }
            case .skip:
                if canOfferTest {
                    footerLink("baseline.action.backToTest") { mode.wrappedValue = .test }
                } else {
                    footerLink("baseline.action.switchToSelfAssess") { mode.wrappedValue = .selfAssess }
                }
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.deltiqOrange)
        .buttonStyle(.plain)
    }

    /// Kleiner Text-Link im Footer. Nimmt bewusst einen Compile-Zeit-Key
    /// entgegen (kein `String`-Laufzeitwert): `key` wird hier IMMER als
    /// String-LITERAL am Aufrufort uebergeben, wodurch `Text(_:bundle:)`
    /// korrekt ueber `LocalizedStringKey` lokalisiert (siehe `cueRow` fuer
    /// die Gegenprobe mit einem echten Laufzeitwert).
    private func footerLink(_ key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key, bundle: .module)
        }
    }

    private var skippedNote: some View {
        Text("baseline.action.skippedNote", bundle: .module)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
