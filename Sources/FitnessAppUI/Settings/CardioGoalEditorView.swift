#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Deltiq-Geräteabnahme (C01): die Cardio-/Laufziel-Felder lagen bisher
/// direkt in `ProfileEditorView`s Autosave-Bindungen — die gebündelte
/// Anpassungsvorschau (`CardioFeasibilityCardModel`) erschien dadurch
/// nachweislich bei JEDEM Tastenanschlag statt wie von Dok. 01 §6
/// gefordert "einmalig gebündelt nach einem gespeicherten Update" (siehe
/// docs/DELTIQ_DEVICE_ACCEPTANCE.md, C01). Fix: derselbe Lokaler-Draft-
/// mit-explizitem-Speichern/Abbrechen-Schnitt wie bereits
/// `BodyDataEditorView`/`TrainingLocationEquipmentEditorView` — erst nach
/// dem Speichern-Tap ändert sich `profile`, und erst dann kann
/// `CardioFeasibilityCardModel.make(for:)` (in `ProfileEditorView`,
/// unverändert) überhaupt eine neue Vorschau berechnen.
@available(iOS 17.0, macOS 14.0, *)
struct CardioGoalEditorView: View {
    @Bindable var profile: UserBodyProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completedSessions: [WorkoutSession]

    /// Paket 1 (Laufcoach-Plananpassung): fuer die Preview nach dem
    /// Aktivieren des Coachs (siehe `save()`).
    @Query(filter: #Predicate<TrainingPlan> { $0.isActive == true })
    private var activePlans: [TrainingPlan]

    @State private var draftCardioCoachingEnabled: Bool
    @State private var draftEnduranceModality: EnduranceModality?
    @State private var draftCardioGoal: CardioGoal
    @State private var draftCardioRaceDate: Date?
    @State private var draftWeeklyBaseVolumeKm: Double?
    @State private var draftMaxHeartRateBpm: Int?
    @State private var draftFiveKReferenceText: String

    @State private var showingDiscardConfirm = false
    @State private var pendingCardioBaseline: CardioBaselineCalculator.Result?
    @State private var retroSyncEmptyNoticeVisible = false
    /// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): Doppeltap-
    /// Schutz fuer `save()`.
    @State private var isSaving = false
    /// Task 5: sichtbare Fehlermeldung statt des bisher verschluckten
    /// `try? modelContext.save()`-Fehlers.
    @State private var saveErrorMessage: String?

    /// Paket 1 (Laufcoach-Plananpassung, Komponente 5):
    /// "Coach aus"-Bestätigung (eigener, sofort wirksamer Weg - siehe
    /// `cardioFields`s Toggle-Binding) und die Vorschau nach dem
    /// Aktivieren (siehe `save()`).
    @State private var showingCoachOffConfirm = false
    @State private var showingAdjustmentPreview = false
    @State private var planForAdjustmentPreview: TrainingPlan?

    init(profile: UserBodyProfile) {
        self.profile = profile
        _draftCardioCoachingEnabled = State(initialValue: profile.cardioCoachingEnabled)
        _draftEnduranceModality = State(initialValue: profile.enduranceModality)
        _draftCardioGoal = State(initialValue: profile.cardioGoal)
        _draftCardioRaceDate = State(initialValue: profile.cardioRaceDate)
        _draftWeeklyBaseVolumeKm = State(initialValue: profile.weeklyBaseVolumeKm)
        _draftMaxHeartRateBpm = State(initialValue: profile.maxHeartRateBpm)
        _draftFiveKReferenceText = State(
            initialValue: profile.current5kReferenceSeconds.map(PaceCalculator.formatDuration) ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DeltiqHeader(
                    eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                    title: String(localized: "profile.section.cardio", bundle: .module),
                    onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                    actions: [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            // Task 5 (d): Freitext-Zahlenfeld `draftFiveKReferenceText`
                            // (MM:SS) muss vor dem Speichern valide sein, sonst
                            // wuerde eine ungueltige Eingabe von `save()` still
                            // auf `nil` fallen (siehe `PaceCalculator.
                            // parseDurationToSeconds`) statt den Nutzer auf den
                            // Tippfehler hinzuweisen.
                            isDisabled: !canSave || isSaving,
                            accessibilityLabel: String(localized: "common.save", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let saveErrorMessage {
                            errorRow(saveErrorMessage)
                        }
                        cardioFields
                    }
                    .padding()
                }
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            .keyboardDismissToolbar()
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            .interactiveDismissDisabled(isDirty)
            .confirmationDialog(
                Text("profile.cardio.retroSync.title", bundle: .module),
                isPresented: Binding(
                    get: { pendingCardioBaseline != nil },
                    set: { if !$0 { pendingCardioBaseline = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingCardioBaseline
            ) { result in
                Button {
                    applyCardioBaseline(result)
                    pendingCardioBaseline = nil
                } label: {
                    Text("profile.cardio.retroSync.apply", bundle: .module)
                }
                Button(role: .cancel) {
                    pendingCardioBaseline = nil
                } label: {
                    Text("profile.cardio.retroSync.discard", bundle: .module)
                }
            } message: { result in
                Text(cardioBaselineMessage(result))
            }
            // Paket 1, Komponente 5: "Coach ausschalten" - sofort wirksam,
            // ausserhalb des normalen Entwurf-Speichern-Flusses. Bestaetigt
            // schreibt NUR `cardioCoachingEnabled = false` - Trainingsdaten/
            // Laufeinheiten/Historie bleiben unangetastet.
            .confirmationDialog(
                Text("profile.cardio.coachOff.title", bundle: .module),
                isPresented: $showingCoachOffConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    profile.cardioCoachingEnabled = false
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("profile.cardio.coachOff.confirm", bundle: .module)
                }
                Button(role: .cancel) {} label: {
                    Text("common.cancel", bundle: .module)
                }
            } message: {
                Text("profile.cardio.coachOff.message", bundle: .module)
            }
            // Paket 1, Komponente 5: nach dem Aktivieren schliesst diese
            // View erst, NACHDEM die Vorschau geschlossen wurde (egal mit
            // welcher Aktion) - der Nutzer landet danach wieder auf
            // `ProfileEditorView`, nicht in diesem (bereits gespeicherten,
            // nicht mehr dirty) Editor haengen.
            .sheet(isPresented: $showingAdjustmentPreview, onDismiss: { dismiss() }) {
                if let planForAdjustmentPreview {
                    CoachAdjustmentPreviewView(profile: profile, activePlan: planForAdjustmentPreview)
                }
            }
        }
    }

    /// Vergleich gegen den beim Öffnen erfassten Profilstand — identisches
    /// Muster wie `BodyDataEditorView.isDirty`.
    private var isDirty: Bool {
        draftCardioCoachingEnabled != profile.cardioCoachingEnabled
            || draftEnduranceModality != profile.enduranceModality
            || draftCardioGoal != profile.cardioGoal
            || draftCardioRaceDate != profile.cardioRaceDate
            || draftWeeklyBaseVolumeKm != profile.weeklyBaseVolumeKm
            || draftMaxHeartRateBpm != profile.maxHeartRateBpm
            || draftFiveKReferenceText != (profile.current5kReferenceSeconds.map(PaceCalculator.formatDuration) ?? "")
    }

    /// Task 5 (d): gate fuer das Save-Haekchen — das einzige Freitext-
    /// Zahlenfeld dieses Editors (`draftFiveKReferenceText`, MM:SS) muss
    /// entweder leer (keine Referenzzeit) oder ueber `PaceCalculator.
    /// parseDurationToSeconds` parsbar sein. Die uebrigen Zahlenfelder
    /// (`draftWeeklyBaseVolumeKm`/`draftMaxHeartRateBpm`) sind bereits ueber
    /// typisierte `TextField(value:)`-Bindings gegen ungueltige Eingaben
    /// geschuetzt und brauchen keine zusaetzliche Pruefung hier.
    private var canSave: Bool {
        guard draftCardioCoachingEnabled else { return true }
        let text = draftFiveKReferenceText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty || PaceCalculator.parseDurationToSeconds(text) != nil
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        // Paket 1, Komponente 5: nur ECHTES Aktivieren (vorher aus, jetzt
        // an) loest die Anpassungsvorschau aus - ein Speichern, bei dem der
        // Coach schon vorher an war (z. B. nur Renndatum geaendert), zeigt
        // sie nicht erneut.
        let coachJustActivated = !profile.cardioCoachingEnabled && draftCardioCoachingEnabled

        profile.setEnduranceModality(draftEnduranceModality, runCoachEnabled: draftCardioCoachingEnabled)
        profile.cardioGoal = draftCardioGoal
        profile.cardioRaceDate = draftCardioRaceDate
        profile.weeklyBaseVolumeKm = draftWeeklyBaseVolumeKm
        profile.maxHeartRateBpm = draftMaxHeartRateBpm
        profile.current5kReferenceSeconds = PaceCalculator.parseDurationToSeconds(draftFiveKReferenceText)
        // Geraete-Nachtest (Runde 5, docs/DELTIQ_DEVICE_ACCEPTANCE.md): ohne
        // diesen expliziten Save ging ein gerade bestaetigtes Cardio-Update
        // bei einem Kaltstart kurz danach wieder verloren (SwiftDatas
        // impliziter Autosave kam nicht reproduzierbar rechtzeitig durch) -
        // derselbe Musterfehler wie in `MeasurementPersistenceTests`/E01.
        // Task 5: `try?` verschluckte den Fehler bisher komplett — der
        // Nutzer sah "Erfolg", obwohl nichts persistiert wurde.
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            return
        }

        if coachJustActivated, let plan = activePlans.first {
            planForAdjustmentPreview = plan
            showingAdjustmentPreview = true
        } else {
            dismiss()
        }
    }

    /// Mirrors `UserBodyProfile.setEnduranceModality` auf dem lokalen Draft:
    /// eine explizit nicht laufcoach-faehige Ausdauerform (Radfahren) darf
    /// den Coach-Schalter nicht eingeschaltet lassen.
    private func setDraftEnduranceModality(_ modality: EnduranceModality?, runCoachEnabled wantsCoach: Bool) {
        draftEnduranceModality = modality
        draftCardioCoachingEnabled = wantsCoach && (modality?.supportsRunCoach ?? true)
    }

    private var displayedEnduranceModality: EnduranceModality {
        draftEnduranceModality ?? .running
    }

    private var needsEnduranceModalityQuestion: Bool {
        profile.trainingGoal == .endurance || profile.trainingGoal == .hybrid || draftCardioCoachingEnabled
    }

    @ViewBuilder
    private var cardioFields: some View {
        DeltiqSection(String(localized: "profile.section.cardio", bundle: .module).uppercased()) {
            DeltiqControlRow(
                icon: "figure.run",
                label: String(localized: "profile.cardio.enable", bundle: .module),
                showsDivider: draftCardioCoachingEnabled
            ) {
                Toggle("", isOn: Binding(
                    get: { draftCardioCoachingEnabled },
                    set: { newValue in
                        // Paket 1, Komponente 5: "Coach ausschalten" ist ein
                        // eigener, SOFORT wirksamer Weg (eigene Bestätigung,
                        // schreibt direkt auf `profile`, kein Teil des
                        // normalen Entwurf-dann-Speichern-Flusses der
                        // übrigen Felder hier) - siehe
                        // `profile.cardio.coachOff.title` weiter unten.
                        if !newValue && draftCardioCoachingEnabled {
                            showingCoachOffConfirm = true
                        } else {
                            setDraftEnduranceModality(draftEnduranceModality, runCoachEnabled: newValue)
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.deltiqOrange)
                .disabled(needsEnduranceModalityQuestion && !displayedEnduranceModality.supportsRunCoach)
                .accessibilityLabel(Text("profile.cardio.enable", bundle: .module))
            }
            if needsEnduranceModalityQuestion {
                DeltiqControlRow(
                    label: String(localized: "profile.coaching.enduranceModality", bundle: .module),
                    showsDivider: draftCardioCoachingEnabled
                ) {
                    Picker(selection: Binding(
                        get: { displayedEnduranceModality },
                        set: { setDraftEnduranceModality($0, runCoachEnabled: draftCardioCoachingEnabled) }
                    )) {
                        ForEach(EnduranceModality.allCases, id: \.self) { modality in
                            Text(modality.localizedName).tag(modality)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                if !displayedEnduranceModality.supportsRunCoach {
                    hintRow(String(localized: "profile.coaching.runCoach.unavailableHint", bundle: .module))
                }
            }
            if draftCardioCoachingEnabled {
                Button {
                    let result = computeCardioBaseline()
                    if result.isEmpty {
                        retroSyncEmptyNoticeVisible = true
                    } else {
                        retroSyncEmptyNoticeVisible = false
                        pendingCardioBaseline = result
                    }
                } label: {
                    HStack {
                        Label {
                            Text("profile.cardio.retroSync.button", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
                if retroSyncEmptyNoticeVisible {
                    hintRow(String(localized: "profile.cardio.retroSync.empty", bundle: .module))
                }
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
                DeltiqControlRow(label: String(localized: "profile.cardio.goal", bundle: .module)) {
                    Picker(selection: $draftCardioGoal) {
                        ForEach(CardioGoal.allCases, id: \.self) { goal in
                            Label {
                                Text(goal.localizedName)
                            } icon: {
                                Image(systemName: goal.symbol)
                            }
                            .tag(goal)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                DeltiqControlRow(label: String(localized: "profile.cardio.fiveKReference", bundle: .module)) {
                    TextField("MM:SS", text: $draftFiveKReferenceText, prompt: Text("MM:SS"))
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15))
                        .fitnessNumberStyle()
                        .frame(maxWidth: 90)
                }
                if let zonesSummary {
                    hintRow(zonesSummary)
                }
                DeltiqControlRow(
                    label: String(localized: "profile.cardio.raceDateToggle", bundle: .module),
                    showsDivider: draftCardioRaceDate != nil
                ) {
                    Toggle("", isOn: cardioRaceDateToggleBinding)
                        .labelsHidden()
                        .tint(Color.deltiqOrange)
                        .accessibilityLabel(Text("profile.cardio.raceDateToggle", bundle: .module))
                }
                if draftCardioRaceDate != nil {
                    DeltiqControlRow(label: String(localized: "profile.cardio.raceDateValue", bundle: .module)) {
                        DatePicker(
                            selection: Binding(
                                get: { draftCardioRaceDate ?? Self.defaultRaceDate },
                                set: { draftCardioRaceDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }
                DeltiqControlRow(label: String(localized: "profile.cardio.weeklyVolume", bundle: .module)) {
                    decimalField(
                        String(localized: "profile.cardio.weeklyVolume", bundle: .module),
                        value: $draftWeeklyBaseVolumeKm,
                        placeholder: String(localized: "profile.cardio.weeklyVolumePlaceholder", bundle: .module)
                    )
                }
                DeltiqControlRow(label: String(localized: "profile.cardio.maxHeartRate", bundle: .module), showsDivider: false) {
                    intField(
                        String(localized: "profile.cardio.maxHeartRate", bundle: .module),
                        value: $draftMaxHeartRateBpm,
                        placeholder: String(localized: "profile.cardio.maxHeartRatePlaceholder", bundle: .module)
                    )
                }
            }
            hintRow(String(localized: "profile.cardio.footer", bundle: .module))
        }
    }

    private var zonesSummary: String? {
        guard let seconds = PaceCalculator.parseDurationToSeconds(draftFiveKReferenceText),
              let easy = PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: seconds),
              let tempo = PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: seconds)
        else { return nil }
        let template = String(localized: "profile.cardio.paceZones", bundle: .module)
        return String(format: template, PaceCalculator.formatPace(easy), PaceCalculator.formatPace(tempo))
    }

    private var cardioRaceDateToggleBinding: Binding<Bool> {
        Binding(
            get: { draftCardioRaceDate != nil },
            set: { isOn in
                draftCardioRaceDate = isOn ? (draftCardioRaceDate ?? Self.defaultRaceDate) : nil
            }
        )
    }

    private static var defaultRaceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    }

    // MARK: - DEL-251 Retro-Sync (auf den lokalen Draft statt `profile`)

    private func cardioLogs(sinceDaysAgo days: Int) -> [ExerciseLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return completedSessions
            .filter { $0.isRealWorkout && $0.startTime >= cutoff }
            .flatMap(\.logs)
            .filter(\.resolvedIsCardio)
    }

    private func computeCardioBaseline() -> CardioBaselineCalculator.Result {
        let volumeDistancesKm = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.weeklyVolumeWindowDays)
            .compactMap(\.distanceKm)
        let referenceRuns = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.referenceWindowDays)
            .compactMap { log -> CardioBaselineCalculator.RunSample? in
                guard let distanceKm = log.distanceKm, let durationSeconds = log.durationSeconds else { return nil }
                return CardioBaselineCalculator.RunSample(distanceKm: distanceKm, durationSeconds: durationSeconds)
            }
        return CardioBaselineCalculator.Result(
            weeklyVolumeKm: CardioBaselineCalculator.weeklyVolumeKm(distancesKm: volumeDistancesKm),
            referenceSeconds: CardioBaselineCalculator.fastestReferenceSeconds(from: referenceRuns)
        )
    }

    private func applyCardioBaseline(_ result: CardioBaselineCalculator.Result) {
        if let weeklyVolumeKm = result.weeklyVolumeKm {
            draftWeeklyBaseVolumeKm = weeklyVolumeKm
        }
        if let referenceSeconds = result.referenceSeconds {
            draftFiveKReferenceText = PaceCalculator.formatDuration(referenceSeconds)
        }
    }

    private func cardioBaselineMessage(_ result: CardioBaselineCalculator.Result) -> String {
        let volumeText = result.weeklyVolumeKm.map(\.formattedOneDecimal)
        let paceText = result.referenceSeconds
            .flatMap(PaceZoneCalculator.racePaceMinutesPerKm)
            .map(PaceCalculator.formatPace)
        switch (volumeText, paceText) {
        case let (.some(v), .some(p)):
            return String(format: String(localized: "profile.cardio.retroSync.messageBoth", bundle: .module), v, p)
        case let (.some(v), nil):
            return String(format: String(localized: "profile.cardio.retroSync.messageVolumeOnly", bundle: .module), v)
        case let (nil, .some(p)):
            return String(format: String(localized: "profile.cardio.retroSync.messagePaceOnly", bundle: .module), p)
        case (nil, nil):
            return ""
        }
    }

    // MARK: - Fields (identisch zu ProfileEditorView, DEL-250-Muster)

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    @ViewBuilder
    private func intField(_ label: String, value: Binding<Int?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    /// Task 5: identisches Inline-Fehler-Muster wie `GearListView.gearCard`.
    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.Deltiq.error)
    }
}
#endif
