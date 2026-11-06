#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

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
    /// Gemeinsamer Setup-Entwurf (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt): ersetzt die
    /// fuenf vormals getrennten `draftCardioGoal`/`draftCardioRaceDate`/`draftWeeklyBaseVolumeKm`/
    /// `draftMaxHeartRateBpm`/`draftFiveKReferenceText`-Vars - identische Felder, jetzt EIN Wert,
    /// geteilt mit Onboarding/PlanBuilder ueber `CardioCoachSetupFields`.
    @State private var cardioSetupDraft: CardioCoachSetupDraft

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
        _cardioSetupDraft = State(initialValue: CardioCoachSetupDraft(
            goal: profile.cardioGoal,
            raceDate: profile.cardioRaceDate,
            weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm,
            maxHeartRateBpm: profile.maxHeartRateBpm,
            fiveKReferenceText: profile.current5kReferenceSeconds.map(PaceCalculator.formatDuration) ?? ""
        ))
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
                            // parseFiveKReferenceSeconds`) statt den Nutzer auf den
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
                    // Fix-Runde 1 (Befund 3): `try?` verschluckte den Fehler
                    // bisher komplett -- `dismiss()` lief unconditional, der
                    // Nutzer sah "Coach aus", obwohl die Aenderung evtl. nie
                    // persistiert wurde. Gleiches Muster wie `save()` oben
                    // (kein Rollback der `profile`-Mutation bei Fehler -- wie
                    // ueberall sonst in dieser Datei).
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                    }
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
            || cardioSetupDraft.goal != profile.cardioGoal
            || cardioSetupDraft.raceDate != profile.cardioRaceDate
            || cardioSetupDraft.weeklyBaseVolumeKm != profile.weeklyBaseVolumeKm
            || cardioSetupDraft.maxHeartRateBpm != profile.maxHeartRateBpm
            || cardioSetupDraft.fiveKReferenceText != (profile.current5kReferenceSeconds.map(PaceCalculator.formatDuration) ?? "")
    }

    /// Task 5 (d): gate fuer das Save-Haekchen — das einzige Freitext-
    /// Zahlenfeld dieses Editors (`draftFiveKReferenceText`, MM:SS) muss
    /// entweder leer (keine Referenzzeit) oder ueber `PaceCalculator.
    /// parseFiveKReferenceSeconds` parsbar sein. Fund B (Geraete-Nachtest):
    /// bewusst NICHT `parseDurationToSeconds` — dessen "bare Zahl = Minuten"-
    /// Fallback liess eine Eingabe wie "2500" (ohne Doppelpunkt) als 2500
    /// Minuten durchgehen statt abgelehnt zu werden. Die uebrigen Zahlenfelder
    /// (`draftWeeklyBaseVolumeKm`/`draftMaxHeartRateBpm`) sind bereits ueber
    /// typisierte `TextField(value:)`-Bindings gegen ungueltige Eingaben
    /// geschuetzt und brauchen keine zusaetzliche Pruefung hier.
    private var canSave: Bool {
        guard draftCardioCoachingEnabled else { return true }
        let text = cardioSetupDraft.fiveKReferenceText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty || PaceCalculator.parseFiveKReferenceSeconds(text) != nil
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        // Finding 3 (Laufcoaching-Audit): Schnappschuss ALLER sieben Felder,
        // die gleich mutiert werden - inklusive der beiden, die
        // `setEnduranceModality` selbst anfasst (siehe dortige Doku:
        // `enduranceModality` UND `cardioCoachingEnabled` zusammen), nicht
        // nur die fuenf direkt sichtbaren Zeilen darunter. Ohne das blieb
        // `profile` nach einem fehlgeschlagenen `context.save()` mit den nie
        // bestaetigten Entwurfswerten stehen - `isDirty` oben haette den
        // Editor faelschlich als "sauber" gelesen (Vergleich gegen das
        // bereits mutierte `profile`), und ein spaeterer, unabhaengiger Save
        // haette diese Werte versehentlich mitpersistiert.
        let originalEnduranceModality = profile.enduranceModality
        let originalCardioCoachingEnabled = profile.cardioCoachingEnabled
        let originalCardioGoal = profile.cardioGoal
        let originalCardioRaceDate = profile.cardioRaceDate
        let originalWeeklyBaseVolumeKm = profile.weeklyBaseVolumeKm
        let originalMaxHeartRateBpm = profile.maxHeartRateBpm
        let originalCurrent5kReferenceSeconds = profile.current5kReferenceSeconds

        profile.setEnduranceModality(draftEnduranceModality, runCoachEnabled: draftCardioCoachingEnabled)
        profile.cardioGoal = cardioSetupDraft.goal
        profile.cardioRaceDate = cardioSetupDraft.raceDate
        profile.weeklyBaseVolumeKm = cardioSetupDraft.weeklyBaseVolumeKm
        profile.maxHeartRateBpm = cardioSetupDraft.maxHeartRateBpm
        profile.current5kReferenceSeconds = cardioSetupDraft.current5kReferenceSeconds
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
            // Finding 3: KEIN `modelContext.rollback()` - das wuerde auch
            // andere, unabhaengige, noch ausstehende Aenderungen im
            // (typischerweise app-weit geteilten) Context verwerfen. Gezielte
            // Feld-fuer-Feld-Wiederherstellung aus dem Schnappschuss oben
            // bleibt stattdessen auf genau diese sieben Felder beschraenkt.
            profile.enduranceModality = originalEnduranceModality
            profile.cardioCoachingEnabled = originalCardioCoachingEnabled
            profile.cardioGoal = originalCardioGoal
            profile.cardioRaceDate = originalCardioRaceDate
            profile.weeklyBaseVolumeKm = originalWeeklyBaseVolumeKm
            profile.maxHeartRateBpm = originalMaxHeartRateBpm
            profile.current5kReferenceSeconds = originalCurrent5kReferenceSeconds
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            isSaving = false
            return
        }

        // Bugfix ("Änderung des Laufziels muss den aktiven Trainingsplan
        // aktualisieren"): ob Aktivieren des Coachs ODER ein reiner
        // Zielwechsel bei bereits aktivem Coach die Anpassungsvorschau
        // ausloesen soll, entscheidet `ActivePlanResolver.
        // planRequiringAdjustment` (siehe dortige Doku) - extrahiert aus
        // dieser View, damit die Entscheidung selbst unabhaengig von SwiftUI
        // testbar ist, nicht nur per Source-Introspection.
        if let plan = ActivePlanResolver.planRequiringAdjustment(
            coachWasEnabled: originalCardioCoachingEnabled, coachWillBeEnabled: draftCardioCoachingEnabled,
            oldGoal: originalCardioGoal, newGoal: cardioSetupDraft.goal, among: activePlans
        ) {
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
                // Gemeinsamer Setup-Feldsatz (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt):
                // dieselbe View wie im Onboarding/PlanBuilder-Setup-Schritt, siehe dortige Doku.
                CardioCoachSetupFields(draft: $cardioSetupDraft)
            }
            hintRow(String(localized: "profile.cardio.footer", bundle: .module))
        }
    }

    // MARK: - DEL-251 Retro-Sync (auf den lokalen Draft statt `profile`)

    private func cardioLogs(sinceDaysAgo days: Int) -> [ExerciseLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return completedSessions
            .filter { $0.isRealWorkout && $0.startTime >= cutoff }
            .flatMap(\.logs)
            .filter(\.resolvedIsCardio)
    }

    private func cardioTimestampedEntries(sinceDaysAgo days: Int) -> [CardioBaselineCalculator.TimestampedEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return completedSessions
            .filter { $0.isRealWorkout && $0.startTime >= cutoff }
            .flatMap { session in
                session.logs
                    .filter(\.resolvedIsCardio)
                    .filter { CardioBaselineCalculator.isRunningEquipment($0.resolvedCardioEquipment) }
                    .compactMap { log -> CardioBaselineCalculator.TimestampedEntry? in
                        guard let km = log.distanceKm else { return nil }
                        return CardioBaselineCalculator.TimestampedEntry(date: session.startTime, distanceKm: km)
                    }
            }
    }

    private func computeCardioBaseline() -> CardioBaselineCalculator.Result {
        let volumeEntries = cardioTimestampedEntries(sinceDaysAgo: CardioBaselineCalculator.classificationWindowDays)
        let (volumeCategory, suggestedKm) = CardioBaselineCalculator.classifyWeeklyVolume(entries: volumeEntries)
        let referenceRuns = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.referenceWindowDays)
            .compactMap { log -> CardioBaselineCalculator.RunSample? in
                guard let distanceKm = log.distanceKm, let durationSeconds = log.durationSeconds else { return nil }
                return CardioBaselineCalculator.RunSample(distanceKm: distanceKm, durationSeconds: durationSeconds)
            }
        let fiveKmRuns = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.fiveKmMedianWindowDays)
            .compactMap { log -> CardioBaselineCalculator.RunSample? in
                guard let distanceKm = log.distanceKm, let durationSeconds = log.durationSeconds else { return nil }
                return CardioBaselineCalculator.RunSample(distanceKm: distanceKm, durationSeconds: durationSeconds)
            }
        return CardioBaselineCalculator.Result(
            weeklyVolumeKm: suggestedKm,
            volumeCategory: volumeCategory,
            referenceSeconds: CardioBaselineCalculator.fastestReferenceSeconds(from: referenceRuns),
            median5kSeconds: CardioBaselineCalculator.medianFiveKmSeconds(from: fiveKmRuns)
        )
    }

    private func applyCardioBaseline(_ result: CardioBaselineCalculator.Result) {
        var weeklyBaseVolumeKm = cardioSetupDraft.weeklyBaseVolumeKm
        var fiveKReferenceText = cardioSetupDraft.fiveKReferenceText
        if let weeklyVolumeKm = result.weeklyVolumeKm {
            // Auf 0,5-km-Schritt runden; kein kuenstliches Ziel-Minimum (spec: DEL-251-v2).
            weeklyBaseVolumeKm = (weeklyVolumeKm * 2).rounded() / 2
        }
        if let referenceSeconds = result.median5kSeconds ?? result.referenceSeconds {
            fiveKReferenceText = PaceCalculator.formatDuration(referenceSeconds)
        }
        cardioSetupDraft = CardioCoachSetupDraft(
            goal: cardioSetupDraft.goal, raceDate: cardioSetupDraft.raceDate,
            weeklyBaseVolumeKm: weeklyBaseVolumeKm, maxHeartRateBpm: cardioSetupDraft.maxHeartRateBpm,
            fiveKReferenceText: fiveKReferenceText
        )
    }

    private func cardioBaselineMessage(_ result: CardioBaselineCalculator.Result) -> String {
        let prefix: String
        if let category = result.volumeCategory {
            switch category {
            case .activeRunner:
                prefix = String(localized: "profile.cardio.retroSync.sourceActiveRunner", bundle: .module)
            case .returningRunner(let weeks):
                prefix = String(format: String(localized: "profile.cardio.retroSync.sourceReturning", bundle: .module), weeks)
            case .insufficientData:
                prefix = String(localized: "profile.cardio.retroSync.sourceInsufficient", bundle: .module)
            case .beginner:
                prefix = String(localized: "profile.cardio.retroSync.sourceBeginner", bundle: .module)
            }
        } else {
            prefix = String(localized: "profile.cardio.retroSync.sourceBeginner", bundle: .module)
        }
        let volumeText = result.weeklyVolumeKm.map(\.formattedOneDecimal)
        let paceText = (result.median5kSeconds ?? result.referenceSeconds)
            .flatMap(PaceZoneCalculator.racePaceMinutesPerKm)
            .map(PaceCalculator.formatPace)
        let detail: String
        switch (volumeText, paceText) {
        case let (.some(v), .some(p)):
            detail = String(format: String(localized: "profile.cardio.retroSync.messageBoth", bundle: .module), v, p)
        case let (.some(v), nil):
            detail = String(format: String(localized: "profile.cardio.retroSync.messageVolumeOnly", bundle: .module), v)
        case let (nil, .some(p)):
            detail = String(format: String(localized: "profile.cardio.retroSync.messagePaceOnly", bundle: .module), p)
        case (nil, nil):
            return prefix
        }
        return prefix + "\n" + detail
    }

    // MARK: - Fields (identisch zu ProfileEditorView, DEL-250-Muster)

    /// Task 5: identisches Inline-Fehler-Muster wie `GearListView.gearCard`.
    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.Deltiq.error)
    }
}
#endif
