#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Workout-completion review screen. Pushed onto the workout navigation stack from
/// `ActiveWorkoutView.finishWorkout()`. Session is already saved (`isCompleted=true`,
/// totals populated) — this view is a review surface plus the notes-entry surface,
/// not a "save vs cancel" gate.
@available(iOS 17.0, macOS 14.0, *)
public struct WorkoutSummaryView: View {

    @Bindable public var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    /// All ExerciseLogs across the model. Filtered in-memory for the PR-detection
    /// history. SwiftData `@Query` doesn't (yet) reliably support nested-relationship
    /// predicates like `$0.session?.isCompleted == true`, so we keep the predicate
    /// in Swift instead.
    @Query(sort: \ExerciseLog.date)
    private var allLogs: [ExerciseLog]

    /// DEL-158: Aktive Gears fuer den History-Gear-Picker (Schuhe/Fahrrad).
    /// Gespiegelt von `FinishWorkoutSheet`.
    @Query(filter: #Predicate<Gear> { $0.isActive == true },
           sort: \Gear.createdAt, order: .reverse)
    private var activeGears: [Gear]

    /// True when invoked from history (`WorkoutHistoryView`) — hides the finish-CTA,
    /// disables swipe-to-delete on sets, makes notes read-only, and re-enables the
    /// system back button so the user can return to the history list.
    public let isReadOnly: Bool

    /// DEL-032: Aktiviert via "Bearbeiten"-Toolbar-Button im isReadOnly-Mode.
    /// Im aktiven Edit-Mode werden Datum + Set-Werte (Gewicht/Reps/RIR) als
    /// TextField/Stepper editierbar. Notes immer editierbar in beiden Edit-Modi.
    @State private var isEditingHistory: Bool = false

    /// UX-202: gating fuer die Hero-Spring-In-Animation. Wird via .onAppear
    /// im Hero auf true gesetzt; im isReadOnly-Mode (History-Replay) sofort
    /// auf true, sodass das Celebration-Spring nur beim frischen Finish
    /// triggert.
    @State private var hasAppeared: Bool = false

    /// DEL-136 Part A: Confirm-Dialog-Gate fuer destruktives Delete-Session.
    @State private var showingDeleteSessionConfirm: Bool = false

    /// DEL-136 Part C: Sheet-Gate fuer Add-Exercise-Picker in History-Edit-Mode.
    @State private var showingAddExercisePicker: Bool = false

    /// DEL-136 Part B: Confirm-Dialog-Gate fuer Remove-Exercise-from-Session.
    /// Speichert den Exercise, der removed werden soll — wenn nil, dann ist
    /// kein Dialog offen.
    @State private var exerciseToRemove: Exercise?

    /// Audit-Fix (Save-Fehlerbehandlung): sichtbarer Hinweis statt stillem
    /// `try?`-Swallow fuer die diskreten Speicher-Aktionen unten (Edit-Mode
    /// verlassen, Satz/Uebung hinzufuegen/entfernen, Gear zuweisen). Bei
    /// einem Fehler wird NICHTS zurueckgerollt - die bereits mutierten
    /// Objekte bleiben im ModelContext pending, ein erneuter Versuch bzw.
    /// der naechste erfolgreiche Save (an dieser oder anderer Stelle) nimmt
    /// sie automatisch mit.
    @State private var saveErrorMessage: String?

    @Environment(\.dismiss) private var dismiss

    public init(session: WorkoutSession, isReadOnly: Bool = false) {
        self.session = session
        self.isReadOnly = isReadOnly
    }

    /// Werden Set-Werte als Eingabefelder gerendert?
    /// - New-Mode (post-finish): nein, totals werden vom finishWorkout-Flow
    ///   gesetzt
    /// - History-Detail: nein (default, Read-Only)
    /// - History-Edit (DEL-032): ja
    private var isEditingSets: Bool {
        isReadOnly && isEditingHistory
    }

    public var body: some View {
        // Signature-Geruest: eigene Kopfzone statt navigationTitle/Toolbar.
        // `List` bleibt Container - der History-Edit-Mode braucht .onDelete
        // fuer Saetze/Uebungen. Kein `onBack` im New-Mode (frisch beendete
        // Session): der User soll ueber den expliziten "Fertig"-Button statt
        // ueber Zurueck-Wischen zum Dashboard - identisch zum vorherigen
        // `.navigationBarBackButtonHidden(!isReadOnly)`.
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "summary.eyebrow", bundle: .module).uppercased(),
                title: navigationTitleText,
                onBack: isReadOnly ? { dismiss() } : nil,
                // DEL-032/DEL-136 Part A: History-Mode bekommt einen Edit-
                // Toggle + ein "..."-Loesch-Menu. Im New-Mode (post-finish)
                // unsichtbar - Edit macht dort keinen Sinn (totals werden
                // gerade erst geschrieben) und eine gerade gespeicherte
                // Session sofort wieder zu loeschen gibt's keinen Use-Case.
                actions: isReadOnly ? [
                    DeltiqHeaderAction(
                        systemImage: isEditingHistory ? "checkmark" : "pencil",
                        isHighlighted: isEditingHistory
                    ) {
                        if isEditingHistory {
                            // Beim Beenden vom Edit-Mode: leere Platzhalter-
                            // Zeilen aufraeumen (DEL-223), totals neu berechnen
                            // + persistieren, falls der User Set-Werte angefasst hat.
                            sweepEmptyPlaceholderLogs()
                            recalculateSessionTotals()
                            // Audit-Fix: ein fehlgeschlagener Save bleibt jetzt
                            // sichtbar UND der Edit-Mode bleibt offen (kein
                            // `isEditingHistory.toggle()`), statt dem User
                            // "Fertig" vorzutaeuschen - er kann den Checkmark
                            // erneut antippen, um es noch einmal zu versuchen.
                            do {
                                try modelContext.save()
                            } catch {
                                showSaveErrorToast()
                                return
                            }
                            // Bugfix (Audit): ohne dies blieb die Trophy Room
                            // nach einer History-Korrektur (z.B. ein falsch
                            // getipptes Gewicht oder eine falsche AMRAP-
                            // Rundenzahl) auf dem alten, jetzt fabrizierten
                            // PR-Stand stehen - PersonalRecordEntry wurde nur
                            // beim urspruenglichen Speichern geschrieben, nie
                            // erneut. `rebuild` ist die bereits vorhandene,
                            // korrekte "alles neu berechnen"-Operation (siehe
                            // "Aus History neu berechnen" im Trophy Room).
                            PersonalRecordSync.rebuild(in: modelContext)
                            do {
                                try modelContext.save()
                            } catch {
                                showSaveErrorToast()
                                return
                            }
                        }
                        isEditingHistory.toggle()
                    },
                    DeltiqHeaderAction(systemImage: "ellipsis", menu: {
                        Button(role: .destructive) {
                            showingDeleteSessionConfirm = true
                        } label: {
                            Label {
                                Text("summary.menu.deleteSession", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    })
                ] : []
            )

            List {
                heroSection
                // UX-202: Achievements ueber den Stats — der User soll erst den
                // Reward sehen, dann die Zahlen analysieren. Read-Only-Replay
                // ueberspringt die Sektion, weil die Achievements zum Frisch-
                // Finish-Moment gehoeren (heaviestOfWeek waere im Replay stale
                // sobald die naechste Session in derselben Woche kommt).
                if !isReadOnly, !achievements.isEmpty {
                    achievementsSection
                }
                if isEditingSets {
                    editMetaSection
                }
                // Nutzer-Feedback (7. August): Datum + Dauer liessen sich im
                // History-Edit-Mode bereits korrigieren, das Zeitformat-
                // ERGEBNIS selbst (Runden/Restwdh. bei AMRAP, geschaffte
                // Minuten bei EMOM, Zielzeit bei Auf Zeit) aber nicht -
                // `timedFormatCircuitSection` in breakdownSections blieb
                // unabhaengig vom Edit-Mode rein lesend.
                if isEditingSets, let format = session.timeFormatSnapshot {
                    editTimedResultSection(format)
                }
                if !personalRecords.isEmpty {
                    prSection
                }
                // DEL-052/053: Smart-Progression-Celebration nur im New-Mode, nicht
                // in History-Replays. Im History-Replay wuerden die Outcomes stale
                // sein (suggestedWeight wurde seither evtl. mehrfach weiter-geupdated).
                if !isReadOnly, !progressionOutcomes.isEmpty {
                    progressionSection
                }
                statsSection
                gearSection
                notesSection
                breakdownSections
                if !isReadOnly {
                    finishSection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift. NUR im
        // History-Mode aktiviert (isReadOnly), damit der frische Post-
        // Finish-Modus weiterhin zwingend ueber den "Fertig"-Button laeuft
        // und nicht per Wegwischen umgangen werden kann - identisch zum
        // `onBack: isReadOnly ? ... : nil` oben.
        .deltiqSwipeBackEnabled(isReadOnly)
        // DEL-223: Sicherheitsnetz gegen dauerhaft falsche Summen. Der
        // Edit-Mode rechnete `totalSets`/`totalVolumeKg` NUR im "Fertig"-
        // Toolbar-Button neu — im History-Mode ist der Zurueck-Chevron aber
        // sichtbar (siehe `onBack: isReadOnly ? ... : nil` oben). Wer den
        // Edit-Mode ueber Zurueck oder die Back-Swipe-Gestur verliess, behielt
        // fuer immer die Summen von VOR seiner Aenderung — in Dashboard,
        // Wochenvolumen und History.
        //
        // Bewusst nur ein Recompute und KEIN Platzhalter-Sweep: Recompute ist
        // idempotent und damit unkritisch, falls SwiftUI onDisappear
        // unerwartet feuert. Geloescht wird nur auf die explizite
        // "Fertig"-Aktion.
        .onDisappear {
            guard isReadOnly else { return }
            recalculateSessionTotals()
            // Audit-Fix: bekannte Grenze - eine View, die bereits verschwindet,
            // kann ihren eigenen Toast nicht zuverlaessig mehr anzeigen (die
            // Navigation ist zu diesem Zeitpunkt schon im Gang). Trotzdem kein
            // stilles `try?` mehr: bei einem Fehler bleiben die neu berechneten
            // Felder im ModelContext pending (kein Rollback) und werden vom
            // naechsten erfolgreichen Save andernorts automatisch mitgespeichert.
            do {
                try modelContext.save()
            } catch {
                showSaveErrorToast()
            }
        }
        // DEL-136 Part A: Confirmation-Dialog vor dem destruktiven Delete.
        // Default-Branch ist Cancel — User kann nicht versehentlich Workout-
        // Historie ausloeschen, sondern muss explizit "Loeschen" tappen.
        .confirmationDialog(
            Text("summary.deleteSession.confirmTitle", bundle: .module),
            isPresented: $showingDeleteSessionConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteEntireSession()
            } label: {
                Text("summary.deleteSession.confirmDelete", bundle: .module)
            }
            Button(role: .cancel) { } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("summary.deleteSession.confirmMessage", bundle: .module)
        }
        // DEL-136 Part B: Confirm-Dialog fuer Remove-Exercise-from-Session.
        // exerciseToRemove == nil → kein Dialog, sonst zeigt's den
        // Exercise-Namen im Message-Body.
        .confirmationDialog(
            Text("summary.removeExercise.confirmTitle", bundle: .module),
            isPresented: Binding(
                get: { exerciseToRemove != nil },
                set: { if !$0 { exerciseToRemove = nil } }
            ),
            titleVisibility: .visible,
            presenting: exerciseToRemove
        ) { exercise in
            Button(role: .destructive) {
                removeExerciseFromSession(exercise)
                exerciseToRemove = nil
            } label: {
                Text("summary.removeExercise.confirmRemove", bundle: .module)
            }
            Button(role: .cancel) {
                exerciseToRemove = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { exercise in
            Text(String(format: String(localized: "summary.removeExercise.confirmMessageFormat",
                                       bundle: .module),
                        exercise.displayName))
        }
        // DEL-136 Part C: Add-Exercise-Picker Sheet.
        .sheet(isPresented: $showingAddExercisePicker) {
            // DEL-210: einheitliche Übungs-Auswahl (= Bibliothek im
            // Picker-Modus).
            ExerciseLibraryPickerSheet(
                // Task #252 (TestFlight-Crash-Audit): `session` kann hier
                // eine BELIEBIGE, ggf. laengst vergangene Historien-Session
                // sein (`WorkoutHistoryView`/`PRHistoryView` oeffnen diese
                // Sheet-Variante u.a. im History-Edit-Modus, siehe
                // `isReadOnly && isEditingHistory` weiter unten) — exakt die
                // Art Objekt, die auf einem Bestandsgeraet eine laengst
                // verwaiste `.day`-Referenz tragen kann (siehe
                // `docs/TESTFLIGHT_CRASH_164.md`). Deshalb vorwaerts ueber
                // alle Plaene gesucht statt rueckwaerts `session.day?.plan`
                // gelesen — wie in `DashboardView.resumeOpenSession`.
                planEnvironment: owningPlanTargetEnvironment(for: session),
                onSelect: { template in
                    addExerciseToSession(from: template, isCustom: false)
                    showingAddExercisePicker = false
                },
                onCreateCustom: { draft in
                    addCustomExerciseToSession(draft)
                    showingAddExercisePicker = false
                }
            )
        }
        // Audit-Fix (Save-Fehlerbehandlung): sichtbarer Hinweis statt
        // stillem `try?`-Swallow, siehe `saveErrorMessage`-Doku oben.
        .overlay(alignment: .bottom) {
            if let saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.error)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Audit-Fix (Save-Fehlerbehandlung): gleiches Toast-Muster wie
    /// `ProfileEditorView.showAggregateToast`/`DayEditorView.showTransientToast`.
    private func showSaveErrorToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                saveErrorMessage = nil
            }
        }
    }

    private var navigationTitleText: String {
        if isReadOnly {
            return isEditingHistory
                ? String(localized: "summary.editTitle", bundle: .module)
                : String(localized: "summary.detailTitle", bundle: .module)
        }
        return String(localized: "summary.title", bundle: .module)
    }

    /// Eyebrow-Stil statt der nativen List-Section-Header-Konvention.
    /// `.textCase(nil)` verhindert, dass List den bereits grossgeschriebenen
    /// String noch einmal automatisch transformiert.
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Color.deltiqOrange)
            .textCase(nil)
    }

    /// Im Edit-Mode bekommt der User Datum + Dauer als editierbare Felder.
    /// Wird oben in der List eingeblendet, ueber statsSection.
    private var editMetaSection: some View {
        Section {
            DatePicker(selection: $session.startTime,
                       displayedComponents: [.date, .hourAndMinute]) {
                Text("summary.date", bundle: .module)
                    .font(.system(size: 15))
            }
            .listRowBackground(Color.Deltiq.surface)
            Stepper(value: $session.durationMinutes, in: 0...600, step: 5) {
                LabeledContent {
                    Text(String(format: String(localized: "summary.durationMinutes", bundle: .module), session.durationMinutes))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                } label: {
                    Text("summary.duration", bundle: .module)
                        .font(.system(size: 15))
                }
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader(String(localized: "summary.editMeta.header", bundle: .module))
        } footer: {
            Text("summary.editMeta.footer", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// Nutzer-Feedback (7. August): Zeitformat-ERGEBNIS im History-Edit-Mode
    /// editierbar machen - vorher liess sich nur Datum/Dauer (editMetaSection)
    /// korrigieren, `timedFormatCircuitSection` in breakdownSections blieb
    /// unabhaengig vom Edit-Mode rein lesend. Eigene Section statt Erweiterung
    /// von editMetaSection, weil sie nur bei Zeitformat-Sessions erscheint.
    @ViewBuilder
    private func editTimedResultSection(_ format: WorkoutTimeFormat) -> some View {
        Section {
            switch format {
            case .amrap:
                Stepper(value: roundsCompletedBinding, in: 0...999) {
                    LabeledContent {
                        Text(roundsCompletedValueText)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Text("summary.editResult.rounds", bundle: .module)
                            .font(.system(size: 15))
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            case .emom:
                // Nachtrag (Verifikation): reiner Fallback fuers geloeschte
                // Tag (`day == nil`) - existiert der Tag noch, gilt IMMER
                // sein echtes Minuten-Ziel als Obergrenze, nicht ein
                // kuenstlicher 60-Min-Mindestwert, der einen kurzen EMOM-
                // Deckel (z.B. 12 Min) sonst aushebeln wuerde.
                Stepper(value: completedMinuteCountBinding, in: 0...(session.contentSnapshotTimeCapMinutes ?? 60)) {
                    LabeledContent {
                        Text(String(format: String(localized: "summary.durationMinutes", bundle: .module),
                                    completedMinuteCountBinding.wrappedValue))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Text("summary.editResult.completedMinutes", bundle: .module)
                            .font(.system(size: 15))
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            case .forTime:
                Stepper(value: finishTimeSecondsBinding, in: 0...7200, step: 5) {
                    LabeledContent {
                        Text(PaceCalculator.formatDuration(finishTimeSecondsBinding.wrappedValue))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Text("summary.editResult.finishTime", bundle: .module)
                            .font(.system(size: 15))
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            case .circuit:
                // Gleiche Obergrenze wie EMOM oben: existiert der Tag noch,
                // ist seine tatsaechliche Rundenzahl die sinnvolle Grenze,
                // sonst ein grosszuegiger Fallback.
                Stepper(value: circuitRoundsCompletedBinding, in: 0...(session.contentSnapshotCircuitRounds ?? 20)) {
                    LabeledContent {
                        Text(circuitRoundsCompletedValueText)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Text("summary.editResult.circuitRounds", bundle: .module)
                            .font(.system(size: 15))
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            case .enduranceIntervals:
                // Paket 2: einzige sinnvoll manuell korrigierbare Groesse
                // ist die Anzahl abgeschlossener Runden - Phase/Skip-Flags
                // sind Ablaufzustand, keine nachtraeglich editierbaren
                // Ergebniswerte (anders als bei Zirkel/EMOM gibt es hier
                // keine kontinuierliche Groesse wie "Minuten"/"Rundenzahl
                // bei beliebiger Obergrenze").
                Stepper(value: enduranceRoundsCompletedBinding, in: 0...(session.contentSnapshotEnduranceIntervalRounds ?? 20)) {
                    LabeledContent {
                        Text(enduranceRoundsCompletedValueText)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Text("summary.editResult.enduranceRounds", bundle: .module)
                            .font(.system(size: 15))
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            }
        } header: {
            sectionHeader(String(localized: "summary.editResult.header", bundle: .module))
        } footer: {
            Text("summary.editResult.footer", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private var roundsCompletedBinding: Binding<Int> {
        Binding(
            get: { session.roundsCompleted ?? 0 },
            set: { session.roundsCompleted = $0 }
        )
    }

    private var roundsCompletedValueText: String {
        let rounds = session.roundsCompleted ?? 0
        let suffix = rounds == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "timedWorkout.amrap.rounds.\(suffix)")
        return String(localized: key, bundle: .module).replacingOccurrences(of: "%lld", with: "\(rounds)")
    }

    private var completedMinuteCountBinding: Binding<Int> {
        Binding(
            get: { session.completedMinuteCount ?? 0 },
            set: { session.completedMinuteCount = $0 }
        )
    }

    private var circuitRoundsCompletedBinding: Binding<Int> {
        Binding(
            get: { session.circuitRoundsCompleted ?? 0 },
            set: { session.circuitRoundsCompleted = $0 }
        )
    }

    private var circuitRoundsCompletedValueText: String {
        let rounds = session.circuitRoundsCompleted ?? 0
        guard let target = session.contentSnapshotCircuitRounds else { return "\(rounds)" }
        return "\(rounds) / \(target)"
    }

    private var enduranceRoundsCompletedBinding: Binding<Int> {
        Binding(
            get: { session.enduranceRoundsCompleted ?? 0 },
            set: { session.enduranceRoundsCompleted = $0 }
        )
    }

    private var enduranceRoundsCompletedValueText: String {
        let rounds = session.enduranceRoundsCompleted ?? 0
        guard let target = session.contentSnapshotEnduranceIntervalRounds else { return "\(rounds)" }
        return "\(rounds) / \(target)"
    }

    private var finishTimeSecondsBinding: Binding<Int> {
        Binding(
            get: { session.finishTimeSeconds ?? 0 },
            set: { session.finishTimeSeconds = $0 }
        )
    }

    /// Task #252 (TestFlight-Crash-Audit): liefert `targetEnvironment` des
    /// Plans, der `session` (ueber dessen Tag) tatsaechlich gehoert — OHNE
    /// `session.day?.plan` rueckwaerts zu lesen. `session` kann hier eine
    /// beliebige Historien-Session sein (siehe Aufrufer-Kommentar), fuer die
    /// `.day` auf einem Bestandsgeraet eine laengst verwaiste Referenz sein
    /// kann; `nil` (kein Treffer in `plan.days` irgendeines existierenden
    /// Plans) wird identisch zu einem echten Ad-hoc-Training behandelt — wie
    /// zuvor bei `day.plan == nil`, nur jetzt auch sicher bei einer
    /// verwaisten statt einer echten nil-Referenz.
    private func owningPlanTargetEnvironment(for session: WorkoutSession) -> EnvironmentType? {
        let allPlans = (try? modelContext.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        return DashboardView.owningPlan(forSessionID: session.persistentModelID, in: allPlans)?.targetEnvironment
    }

    /// DEL-136 Part B: Loescht ALLE Logs einer bestimmten Uebung aus dieser
    /// Session — die Uebung selbst (Plan-Side `Exercise`) bleibt fuer
    /// zukuenftige Sessions erhalten. Wenn die Uebung eine orphan-Uebung
    /// war (DEL-136 Part C, day=nil), loeschen wir sie mit, weil sie sonst
    /// nirgends mehr referenziert wird.
    private func removeExerciseFromSession(_ exercise: Exercise) {
        let exerciseID = exercise.persistentModelID
        let logsToDelete = session.logs.filter {
            $0.exercise?.persistentModelID == exerciseID
        }
        for log in logsToDelete {
            modelContext.delete(log)
        }
        // Orphan-Cleanup: wenn die Exercise ueberhaupt keinen Plan-Day-
        // Anker hat (war eine spontan-zugefuegte Session-Only-Uebung,
        // DEL-136 Part C), loeschen wir sie gleich mit. Plan-Side-
        // Uebungen (day != nil) bleiben erhalten.
        if exercise.day == nil {
            modelContext.delete(exercise)
        }
        // Totals neu berechnen, damit Dashboard/History stimmen.
        recalculateSessionTotals()
        do {
            try modelContext.save()
        } catch {
            showSaveErrorToast()
        }
    }

    /// DEL-136 Part C: Erstellt eine neue Exercise tied to session-only
    /// (day=nil) basierend auf einem ExerciseTemplate aus der Library,
    /// plus N leere ExerciseLog-Anker-Zeilen. orderIndex wird auf einen
    /// hohen Wert gesetzt, sodass die neue Uebung am Ende der Session
    /// erscheint.
    ///
    /// **UX-Iteration 2026-05-22**: vorher legte der Picker nur EINEN Log
    /// an — User musste fuer 3 Saetze 4-mal den Picker oeffnen oder im
    /// Workflow basteln. Jetzt:
    ///   * Strength + TimeBased: 3 Sätze default (typisches Anfangs-Set-
    ///     Count fuer eine planmaessige Uebung)
    ///   * Cardio: 1 Satz default (Cardio-Einheiten sind in der Regel
    ///     monolithisch — niemand laeuft "3 Sätze á 5 km")
    /// Ergaenzend bekommt jede Section eine "+ Satz hinzufügen"-Row im
    /// Edit-Mode (siehe `exerciseSection`), sodass mehr/weniger Sätze
    /// flexibel pro Übung gehandhabt werden koennen.
    ///
    /// `template.name` (deutscher Base-Key) wird als Exercise.name
    /// uebernommen — displayName-Extension macht die lokalisierte
    /// Anzeige automatisch via ExerciseLibraryData-Lookup.
    private func addExerciseToSession(from template: ExerciseTemplate, isCustom: Bool) {
        let nextOrder = (session.logs.compactMap { $0.exercise?.orderIndex }.max() ?? -1) + 1
        // DEL-157: Cardio + Time-Based → 1 Satz (vorher nur isCardio
        // beruecksichtigt). Plank/Wall-Sit als Verlaufs-Nachtrag bekommen
        // damit ebenfalls genau eine Zeile.
        let isSingleSetKind = template.isCardio || template.isTimeBased
        let exercise = Exercise(
            name: template.name,
            sets: isSingleSetKind ? 1 : 3,
            repsMin: template.isTimeBased ? 20 : 8,
            repsMax: template.isTimeBased ? 30 : 10,
            restSeconds: 90,
            orderIndex: nextOrder,
            isCardio: template.isCardio,
            isTimeBased: template.isTimeBased,
            day: nil   // orphan: kein Plan-Polluting fuer kuenftige Sessions
        )
        modelContext.insert(exercise)
        let defaultSetCount = isSingleSetKind ? 1 : 3
        for i in 0..<defaultSetCount {
            let log = ExerciseLog(
                setIndex: i,
                weight: 0,
                reps: 0,
                rir: 2,
                exercise: exercise,
                session: session
            )
            modelContext.insert(log)
        }
        do {
            try modelContext.save()
        } catch {
            showSaveErrorToast()
        }
    }

    /// DEL-136 Part C: Custom-Variante — User hat im Picker keinen Library-
    /// Pick, sondern einen freien Namen eingegeben. Erstellt eine generische
    /// Strength-Exercise mit dem User-Namen + 3 Default-Saetzen.
    private func addCustomExerciseToSession(_ draft: CustomExerciseDraft) {
        let nextOrder = (session.logs.compactMap { $0.exercise?.orderIndex }.max() ?? -1) + 1
        // DEL-159: Metadaten aus dem Erstell-Sheet übernehmen.
        let exercise = Exercise(
            name: draft.name,
            sets: 3,
            repsMin: 8,
            repsMax: 10,
            restSeconds: 90,
            orderIndex: nextOrder,
            isCardio: false,
            isTimeBased: false,
            isCompound: draft.isCompound,
            primaryMuscle: draft.primaryMuscle,
            equipment: draft.equipment,
            day: nil
        )
        modelContext.insert(exercise)
        for i in 0..<3 {
            let log = ExerciseLog(
                setIndex: i,
                weight: 0,
                reps: 0,
                rir: 2,
                exercise: exercise,
                session: session
            )
            modelContext.insert(log)
        }
        do {
            try modelContext.save()
        } catch {
            showSaveErrorToast()
        }
    }

    /// DEL-136 Part C-Iteration: Fuegt EINEN weiteren Satz zur Exercise
    /// in der aktuellen Session hinzu. Wird vom "+ Satz hinzufügen"-Button
    /// am Ende jeder exercise-Section im Edit-Mode getriggert. Defaults:
    /// weight 0, reps 0, rir 2 — User editiert via existierender Edit-
    /// Mode-Inputs. setIndex = max(existing)+1, sodass die neue Row am
    /// Ende der Section erscheint.
    // MARK: - DEL-158 Gear-Section (History)

    /// True wenn die Session mindestens eine Cardio-Uebung mit geloggter
    /// Distanz/Dauer enthaelt — unabhaengig von Mixed vs. pure Cardio.
    private var sessionHasCardio: Bool {
        session.logs.contains { log in
            log.resolvedIsCardio
            && (((log.distanceKm ?? 0) > 0) || ((log.durationSeconds ?? 0) > 0))
        }
    }

    /// Summe der Cardio-Distanz dieser Session (km). Basis fuer die Gear-
    /// Kilometer-Buchung. Strength-Logs tragen `distanceKm == nil` → 0 bei.
    private var sessionCardioDistanceKm: Double {
        // DEL-222: eine Summen-Funktion fuer alle Gear-relevanten Distanzen —
        // toleriert nil und ignoriert negative Ausreisser.
        GearOdometer.distanceKm(of: session)
    }

    /// Picker-Optionen: aktive Gears + das aktuell zugewiesene Gear, falls
    /// es inzwischen inaktiv ist (damit die Auswahl korrekt angezeigt wird).
    private var gearOptions: [Gear] {
        var list = activeGears
        if let g = session.gear,
           !list.contains(where: { $0.persistentModelID == g.persistentModelID }) {
            list.append(g)
        }
        return list
    }

    @ViewBuilder
    private var gearSection: some View {
        // Nur sinnvoll wenn Cardio dabei war. Im Read-Mode nur anzeigen, wenn
        // ein Gear zugewiesen ist; im Edit-Mode immer das Auswahl-Menu.
        if sessionHasCardio, !gearOptions.isEmpty || session.gear != nil {
            Section {
                if isEditingSets {
                    Menu {
                        Button {
                            assignGear(nil)
                        } label: {
                            if session.gear == nil {
                                Label { Text("summary.gear.none", bundle: .module) } icon: { Image(systemName: "checkmark") }
                            } else {
                                Text("summary.gear.none", bundle: .module)
                            }
                        }
                        ForEach(gearOptions) { gear in
                            Button {
                                assignGear(gear)
                            } label: {
                                if session.gear?.persistentModelID == gear.persistentModelID {
                                    Label { Text(gear.name) } icon: { Image(systemName: "checkmark") }
                                } else {
                                    Text(gear.name)
                                }
                            }
                        }
                    } label: {
                        LabeledContent {
                            Text(session.gear?.name ?? String(localized: "summary.gear.none", bundle: .module))
                                .foregroundStyle(Color.primary)
                                .font(.system(size: 15))
                        } label: {
                            Label {
                                Text("summary.gear.header", bundle: .module)
                                    .font(.system(size: 15))
                            } icon: {
                                Image(systemName: gearIcon(session.gear))
                                    .foregroundStyle(Color.deltiqOrange)
                            }
                        }
                    }
                    .listRowBackground(Color.Deltiq.surface)
                } else if let gear = session.gear {
                    LabeledContent {
                        Text(gear.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    } label: {
                        Label {
                            Text("summary.gear.header", bundle: .module)
                                .font(.system(size: 15))
                        } icon: {
                            Image(systemName: gearIcon(gear))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
            } header: {
                sectionHeader(String(localized: "summary.gear.header", bundle: .module))
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
    }

    private func gearIcon(_ gear: Gear?) -> String {
        switch gear?.type {
        case .bike: return "bicycle"
        case .shoe, .none: return "shoe"
        }
    }

    /// DEL-158: Weist `newGear` zu und bucht die Session-Cardio-Distanz um.
    /// Mutation-basierte Kilometer-Buchung (wie beim Finish): altes Gear
    /// bekommt die Distanz abgezogen, neues addiert. No-op wenn unveraendert.
    private func assignGear(_ newGear: Gear?) {
        let old = session.gear
        guard old?.persistentModelID != newGear?.persistentModelID else { return }
        // DEL-222: Umbuchung ueber GearOdometer statt zweier Handbuchungen
        // mit eigenem Clamp.
        GearOdometer.transfer(km: sessionCardioDistanceKm, from: old, to: newGear)
        session.gear = newGear
        do {
            try modelContext.save()
        } catch {
            showSaveErrorToast()
        }
    }

    private func addSet(to exercise: Exercise) {
        let existingIndices = session.logs
            .filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
            .map(\.setIndex)
        let nextIndex = (existingIndices.max() ?? -1) + 1
        let log = ExerciseLog(
            setIndex: nextIndex,
            weight: 0,
            reps: 0,
            rir: 2,
            exercise: exercise,
            session: session
        )
        modelContext.insert(log)
        recalculateSessionTotals()
        do {
            try modelContext.save()
        } catch {
            showSaveErrorToast()
        }
    }

    /// DEL-136 Part A: Loescht die komplette Session inkl. aller ExerciseLogs.
    /// Nach dem Delete dismissed der View — der User landet zurueck auf der
    /// History-Liste, in der die Session weg ist.
    ///
    /// PR-Eintraege werden bewusst NICHT mitgeloescht: das `PersonalRecord
    /// Entry.session`-Relationship ist `.nullify` (Bestandsentscheidung,
    /// siehe Model-Comment: "deleting a session doesn't lose the record's
    /// history"). Trophy-Room behaelt also den Rekord-Eintrag, auch wenn
    /// die definierende Session weg ist.
    ///
    /// HealthKit-Write der Session wird NICHT zurueckgenommen — Apple
    /// Health ist eine separate Datenquelle, der User kann dort selbst
    /// Workouts loeschen via Health-App.
    private func deleteEntireSession() {
        // 0. DEL-213: Gear-Kilometer zurueckbuchen — Spiegel der Credit-
        //    Buchung beim Finish (ActiveWorkoutView) bzw. in assignGear().
        //    Ohne das akkumuliert geloeschte Cardio-Distanz dauerhaft auf
        //    Schuh/Rad. Clamp auf 0, falls das Gear zwischenzeitlich
        //    manuell heruntergesetzt wurde.
        // DEL-222: Rueckbuchung ueber GearOdometer.
        GearOdometer.book(deltaKm: -sessionCardioDistanceKm, to: session.gear)
        // 1. Logs erst — vermeidet `nullify`-Pass auf bereits-deleted Session.
        //    Snapshot in Array kopieren, weil die Live-Relationship-Collection
        //    waehrend des Deletes mutiert.
        let logsCopy = Array(session.logs)
        for log in logsCopy {
            modelContext.delete(log)
        }
        // 2. Session selbst — PRs ueberleben via nullify.
        modelContext.delete(session)
        try? modelContext.save()
        // 3. View aufloesen.
        dismiss()
    }

    /// Setzt totalSets + totalVolumeKg aus den (eventuell vom User editierten)
    /// ExerciseLogs neu, damit Dashboard/History-Stats korrekt bleiben.
    ///
    /// DEL-221: delegiert an `recomputeTotals()` — den einen Schreiber der
    /// Aggregate. Die lokale Handrechnung war eine von fuenf Kopien derselben
    /// Formel.
    private func recalculateSessionTotals() {
        session.recomputeTotals()
    }

    /// DEL-223: Entfernt Satz-Zeilen, in die nie etwas eingetragen wurde.
    ///
    /// Wer im Edit-Mode eine Uebung nachtraegt, bekommt drei vorbereitete
    /// 0/0-Zeilen (`addExerciseToSession`). Traegt er nur einen Satz ein,
    /// blieben die anderen zwei fuer immer in der Datenbank — sie zaehlten als
    /// Satz in der Session-Summe und in der Muskel-Heatmap und tauchten in der
    /// Satz-Liste als "0 kg × 0" auf.
    ///
    /// Laeuft ausschliesslich beim expliziten Verlassen des Edit-Modes, nie
    /// automatisch: solange der User editiert, ist eine leere Zeile eine
    /// Einladung, sie auszufuellen, und kein Muell.
    ///
    /// Uebungen, die dadurch komplett ohne Logs zurueckbleiben, werden
    /// mitgeloescht. Diese Nachtrags-Uebungen haengen bewusst an keinem
    /// Trainingstag (`day: nil`), waeren also unerreichbare Waisen.
    private func sweepEmptyPlaceholderLogs() {
        let placeholders = session.logs.filter(\.isEmptyPlaceholder)
        guard !placeholders.isEmpty else { return }

        // Kandidaten VOR dem Delete festhalten und die zu loeschenden IDs
        // merken: nach dem Delete ist die Relationship-Sicht (`exercise.logs`)
        // innerhalb derselben Transaktion nicht verlaesslich, deshalb wird die
        // Rest-Menge explizit ueber IDs gefiltert statt auf `isDeleted` zu
        // vertrauen.
        let deletedIDs = Set(placeholders.map(\.persistentModelID))
        var candidates: [Exercise] = []
        for log in placeholders {
            guard let exercise = log.exercise else { continue }
            let known = candidates.contains { $0.persistentModelID == exercise.persistentModelID }
            if !known { candidates.append(exercise) }
        }

        for log in placeholders {
            modelContext.delete(log)
        }

        // Waisen-Uebungen aufraeumen: nur solche ohne Plan-Anbindung, bei denen
        // kein Log mehr uebrig bleibt.
        for exercise in candidates where exercise.day == nil {
            let remaining = exercise.logs.filter { !deletedIDs.contains($0.persistentModelID) }
            if remaining.isEmpty {
                modelContext.delete(exercise)
            }
        }
    }

    // MARK: Sections

    // MARK: - Personal Records

    private var personalRecords: [PersonalRecord] {
        PRDetector.detectPRs(sessionLifts: sessionLifts, history: historicalLifts)
    }

    /// DEL-051: snapshot-first. Logs ohne Snapshot UND ohne Live-Exercise
    /// werden uebersprungen, sonst greifen wir auf die persistierten Snapshot-
    /// Felder zu, sodass Plan-Side-Mutations die PR-Detection nicht stoeren.
    private var sessionLifts: [LiftAttempt] {
        session.logs.compactMap { log -> LiftAttempt? in
            guard let name = log.resolvedExerciseName else { return nil }
            return LiftAttempt(
                exerciseName: name,
                // Settings-Epic Phase 6 (EXLIB-07/09): stabile ID durchreichen,
                // damit diese Vorschau-Detection mit PersonalRecordSync
                // konsistent gruppiert (sonst koennte das Summary-Badge einem
                // spaeter persistierten Trophy-Room-Eintrag widersprechen).
                exerciseTemplateID: log.resolvedExerciseTemplateID,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: log.resolvedIsCardio,
                isTimeBased: log.resolvedIsTimeBased,
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds
            )
        }
    }

    /// All logs from completed sessions OTHER than this one — the baseline against
    /// which `PRDetector` measures. DEL-051: nutzt Snapshot-Felder.
    private var historicalLifts: [LiftAttempt] {
        let thisSessionID = session.persistentModelID
        return allLogs.compactMap { log -> LiftAttempt? in
            guard let name = log.resolvedExerciseName,
                  let logSession = log.session,
                  logSession.isCompleted,
                  logSession.persistentModelID != thisSessionID
            else { return nil }
            return LiftAttempt(
                exerciseName: name,
                exerciseTemplateID: log.resolvedExerciseTemplateID,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: log.resolvedIsCardio,
                isTimeBased: log.resolvedIsTimeBased,
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds
            )
        }
    }

    private var prSection: some View {
        Section {
            ForEach(personalRecords) { record in
                PRBadge(record: record)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            // Handoff 1.10 (ein Akzent): Trophaeen-Icon war Gelb, Section-
            // Header traegt jetzt ohnehin kein Icon mehr (kein anderer
            // Header im Geruest tut das) - die einzelnen PRBadges bleiben
            // ueber Icon-Form + Text unterscheidbar, siehe PRBadge.kindIcon
            // / .kindLabel.
            sectionHeader(String(localized: "summary.section.personalRecords", bundle: .module))
        } footer: {
            Text("summary.prFooter", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: - DEL-052/053 Smart Auto-Progression

    /// Read-only re-evaluation der Progression-Outcomes. Read-only weil
    /// `ActiveWorkoutView.finishWorkout` bereits den Mutating-Pass gemacht
    /// hat — wir wollen die Celebration hier nur RENDERN, nicht
    /// weiterschieben.
    private var progressionOutcomes: [ProgressionApplicator.ProgressionOutcome] {
        ProgressionApplicator.evaluateOnly(for: session)
    }

    private var progressionSection: some View {
        Section {
            ForEach(progressionOutcomes) { outcome in
                ProgressionBadge(outcome: outcome)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader(String(localized: "summary.section.progression", bundle: .module))
        } footer: {
            Text("summary.progressionFooter", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: - UX-202 Achievements (Workout-of-Week, Volume-of-Week, Streak)

    /// UX-202: nicht-PR Erfolge fuer den Reward-Moment. Read-only —
    /// `WorkoutAchievementDetector` macht alle Vergleiche aus den
    /// History-Sessions (`allLogs.compactMap(\.session)`) gegen die
    /// aktuelle Session.
    private var achievements: [WorkoutAchievementDetector.Achievement] {
        // History via Session-Set aus allLogs ableiten. Set-Dedup laeuft
        // ueber persistentModelID; minimaler Overhead, vermeidet einen
        // zweiten @Query.
        var seen: Set<PersistentIdentifier> = []
        var history: [WorkoutSession] = []
        for log in allLogs {
            guard let s = log.session,
                  !seen.contains(s.persistentModelID) else { continue }
            seen.insert(s.persistentModelID)
            history.append(s)
        }
        return WorkoutAchievementDetector.detect(
            session: session,
            history: history
        )
    }

    @ViewBuilder
    private var achievementsSection: some View {
        Section {
            ForEach(achievements) { ach in
                AchievementBadge(achievement: ach)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader(String(localized: "summary.achievements.section", bundle: .module))
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: -

    private var heroSection: some View {
        // UX-202: Reward-Moment-Hero. Vorher: 60pt-Checkmark, statisch. Jetzt:
        //   * 88pt-Checkmark mit weicher Spring-In-Skalierung beim ersten
        //     Render (0.4 -> 1.0 in einer dampedDamping=0.55 Feder).
        //   * Subtle Glow via `.shadow` mit DeltiqOrange-Tint — gibt dem Icon
        //     den "leuchtenden Trophaeen"-Look ohne in Confetti zu verfallen.
        //   * Title-Typo eine Stufe groesser (24pt/bold/rounded) damit die
        //     Hierarchie unten in den Stat-Hero-Numbers fortgesetzt wirkt.
        // Read-Only-Replay (History-Detail) ueberspringt das Spring, weil
        // die Anim nur zum frischen Finish gehoert — beim Replay wuerde es
        // jedes Mal triggern und nervt.
        Section {
            VStack(spacing: 12) {
                // README 2.11: ein vorzeitig gespeicherter Zeitformat-Lauf
                // feiert nicht wie ein vollstaendiger - gestrichelte Uhr statt
                // gruenem Siegel, kein Glow, `textSecondary` statt Erfolgsfarbe.
                Image(systemName: isEarlySaveTimedFormat ? "clock.badge.exclamationmark" : "checkmark.seal.fill")
                    .font(.system(size: 88))
                    .symbolRenderingMode(.hierarchical)   // DEL-059
                    // Handoff 1.10: bleibt Gruen - echtes Erfolgs-/Valenz-
                    // Signal (Completion), keine zweite Akzentfarbe. Ueber
                    // den Deltiq.success-Token statt hartem .green, damit
                    // eine spaetere Token-Praezisierung hier mitzieht.
                    .foregroundStyle(isEarlySaveTimedFormat ? Color.Deltiq.textSecondary : Color.Deltiq.success)
                    .shadow(color: Color.deltiqOrange.opacity(isEarlySaveTimedFormat ? 0 : 0.35),
                            radius: (hasAppeared && !isEarlySaveTimedFormat) ? 18 : 0,
                            x: 0, y: 0)
                    .scaleEffect(hasAppeared ? 1.0 : 0.4)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                Text(isEarlySaveTimedFormat ? "summary.hero.title.early" : "summary.hero.title", bundle: .module)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                if isEarlySaveTimedFormat {
                    DeltiqPill(
                        (session.displayDayName + " · " + earlySaveStatusText).uppercased(),
                        style: .neutral
                    )
                }
                // DEL-129: Day-Subtitle via Extension. Hier nur rendern wenn
                // session WIRKLICH einen Day-Bezug hat (entweder live-ref
                // oder Snapshot) — sonst wuerde der generische "Training"-
                // Fallback aus history.session.fallback erscheinen, was im
                // Summary-Hero unschoen wirkt. Bei vorzeitigem Speichern
                // steht der Tag schon in der Kapsel darueber.
                if !isEarlySaveTimedFormat, session.day != nil || session.dayName != nil {
                    Text(session.displayDayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .onAppear {
                // README 2.11: kein Spring, kein zweiter Feier-Haptik-Impuls
                // fuer einen vorzeitig gespeicherten Lauf - der erste Impuls
                // aus dem Speichern-Pfad bleibt, aber die Praesentation hier
                // ist bewusst nuechtern statt feiernd.
                if isReadOnly || isEarlySaveTimedFormat {
                    // Replay bzw. vorzeitig gespeichert: kein Spring, finaler Stand direkt.
                    hasAppeared = true
                    return
                }
                // Tiny 50ms delay damit das List-Layout zuerst settled — sonst
                // wirkt die Spring-Anim wie ein "schon-da-vor-dem-Render"-Pop.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.05)) {
                    hasAppeared = true
                }
                // UX-204: Extra PR-Celebration-Haptik VERSETZT zum
                // finishWorkout()-`.success`. Wenn dieser Workout neue PRs
                // gesetzt hat, schicken wir nach 0.4s einen zweiten
                // Success-Impuls hinterher — der erste war fuers Beenden,
                // der zweite markiert den Bonus-Moment "und du hast einen
                // Rekord gebrochen". Wenn keine PRs aber Achievements
                // vorhanden, fallback auf einen leiseren `.soft`-Impact.
                if !personalRecords.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        DeltiqHaptics.notify(.success)
                    }
                } else if !achievements.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        DeltiqHaptics.impact(.soft)
                    }
                }
            }
        }
    }

    /// UX-202: dreistufige Stat-Hierarchy.
    ///   * Hero-Stat: dominante Zahl (typisch Volumen-kg fuer Strength,
    ///     Distanz-km fuer Cardio). 56pt, rounded, monospacedDigit,
    ///     DeltiqOrange — der visuelle Anker der Karte.
    ///   * Sekundaer-Stats: Dauer + zweite Metrik als kleinere Geschwister-
    ///     Stats. Adaptive an `session.sessionCategory` (DEL-137):
    ///       - pureStrength → Dauer + Saetze
    ///       - mixed        → Dauer + Distanz
    ///       - pureCardio   → Dauer + Ø Pace
    ///     Vorher zeigte die Section IMMER "Dauer + Saetze", was bei reinen
    ///     Cardio-Sessions unsinnig wirkt ("1 Satz" fuer 5 km Lauf).
    private var statsSection: some View {
        Section {
            VStack(spacing: 20) {
                heroStatView
                // DEL-137: gleiche Divider-Konvention wie das statsCard-
                // Pendant in ActiveWorkoutView (bare Divider(), keine Custom-
                // Rectangle) - identische UI-Sprache fuer Live + Replay.
                Divider()
                HStack(spacing: 0) {
                    SummaryStat(label: String(localized: "active.stats.duration", bundle: .module),
                                value: formattedDuration)
                    statDivider
                    secondarySummaryStat
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader(String(localized: "summary.section.stats", bundle: .module))
        } footer: {
            // README 2.11: ordnet die Kennzahl ein, damit "4 Runden" nicht
            // faelschlich als Bestleistung gelesen wird.
            if isEarlySaveTimedFormat {
                Text("summary.early.footnote", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// DEL-137: zweite Sekundaer-Stat-Spalte. Drei-Wege-Branch identisch
    /// zum aktiven `statsCard` in ActiveWorkoutView — selbe UI-Sprache
    /// fuer Live + Replay.
    ///
    /// README 2.9: Zeitformat-Sessions haben keine `sessionCategory` (die
    /// liest aus `logs`, und Zeitformat-Tage loggen nie ExerciseLogs) -
    /// eigener Branch VOR dem Switch, sonst kippt das faelschlich auf
    /// `.pureStrength` (0 Saetze, siehe DEL-093-Praezedenzfall bei Ad-Hoc-
    /// Cardio fuer dasselbe Muster).
    @ViewBuilder
    private var secondarySummaryStat: some View {
        if let format = session.timeFormatSnapshot {
            timedFormatSecondaryStat(format)
        } else {
            switch session.sessionCategory {
            case .pureCardio:
                SummaryStat(label: String(localized: "active.stats.avgPace", bundle: .module),
                            value: formattedAvgPace)
            case .mixed:
                SummaryStat(label: String(localized: "active.stats.distance", bundle: .module),
                            value: formattedTotalDistance)
            case .pureStrength:
                SummaryStat(label: String(localized: "active.stats.sets", bundle: .module),
                            value: "\(session.totalSets)")
            }
        }
    }

    /// README 2.9: dritte Zeitformat-Metrik neben Dauer (Spalte 1, bleibt
    /// unveraendert) und dem Hero-Stat unten. AMRAP hat mit den Restwieder-
    /// holungen eine echte zweite Zahl; EMOM/Auf-Zeit haben das nicht (das
    /// Ergebnis IST schon der Hero-Stat) - EMOM zeigt darum den Minuten-
    /// Deckel als Kontext, Auf-Zeit die Anzahl Uebungen im Zirkel.
    @ViewBuilder
    private func timedFormatSecondaryStat(_ format: WorkoutTimeFormat) -> some View {
        switch format {
        case .amrap:
            // Nutzer-Feedback 6. August: "wie schnell pro Runde" ist die
            // eigentliche Leistungskennzahl bei AMRAP, nicht nur die
            // Rundenzahl selbst - dieselbe Pace-Denke wie beim Cardio-
            // Ø-Pace-Stat oben (`formattedAvgPace`), nur Runden statt km.
            SummaryStat(label: String(localized: "summary.amrap.avgPace", bundle: .module),
                        value: amrapAvgPaceText)
        case .emom:
            // P8 Stufe-2: Minuten-Deckel jetzt snapshot-first — der Tages-
            // Snapshot (`TrainingDayContentSnapshot.timeCapMinutes`) trägt
            // diesen Wert. Degradiert auf "—" nur noch, wenn für diese
            // Session gar nie ein Snapshot erfasst wurde UND der Tag
            // inzwischen gelöscht ist (Altbestand-Grenzfall).
            let target = session.contentSnapshotTimeCapMinutes
            SummaryStat(label: String(localized: "summary.stat.minuteTarget", bundle: .module),
                        value: target.map { "\($0)" } ?? "—")
        case .forTime:
            SummaryStat(label: String(localized: "summary.stat.exercises", bundle: .module),
                        value: "\(session.exerciseCount)")
        case .circuit:
            // P8 Stufe-2: siehe EMOM-Fall oben — jetzt snapshot-first.
            let restSeconds = session.contentSnapshotCircuitRestSeconds
            SummaryStat(label: String(localized: "summary.stat.circuitRest", bundle: .module),
                        value: restSeconds.map { "\($0)s" } ?? "—")
        case .enduranceIntervals:
            // Paket 2: wie der Zirkel-Fall oben - die konfigurierte
            // Erholungsdauer zwischen den Runden als Kontext.
            let restSeconds = session.contentSnapshotEnduranceRestDurationSeconds
            SummaryStat(label: String(localized: "summary.stat.circuitRest", bundle: .module),
                        value: restSeconds.map { "\($0)s" } ?? "—")
        }
    }

    /// Nutzer-Feedback 6. August: durchschnittliche Rundenzeit - wie
    /// schnell ein Athlet tatsaechlich pro Runde wird, nicht nur "wie viele
    /// Runden". Bezieht sich bewusst nur auf VOLLSTAENDIGE Runden (nicht
    /// anteilig auf eine angebrochene) - Standardkonvention beim Reporten
    /// von AMRAP-Rundenzeiten. `durationMinutes` (persistiert, ganzzahlig)
    /// ist die einzige verfuegbare Zeitbasis fuer eine gespeicherte Session
    /// - der Live-`elapsedSeconds`-Zaehler im Player wird nirgends
    /// persistiert. Verliert dadurch bis zu 59s Praezision, was bei
    /// ueblichen 10-20-Minuten-Laeufen ueber viele Runden vernachlaessigbar
    /// ist.
    private var amrapAvgPaceText: String {
        guard let rounds = session.roundsCompleted, rounds > 0 else { return "—:——" }
        let totalSeconds = session.durationMinutes * 60
        guard totalSeconds > 0 else { return "—:——" }
        let perRound = Int((Double(totalSeconds) / Double(rounds)).rounded())
        return String(format: "%d:%02d", perRound / 60, perRound % 60)
    }

    /// DEL-137: Gesamtdistanz aller Cardio-Sets in dieser Session. Format:
    /// "5 km" / "5,42 km" (Integer wenn ganzzahlig, sonst 2-Dezimal).
    private var formattedTotalDistance: String {
        let total = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        guard total > 0 else { return "—" }
        if total == total.rounded() {
            return "\(Int(total)) km"
        }
        return "\(total.truncated(to: 2).formattedTwoDecimals) km"
    }

    /// DEL-137: Durchschnitts-Pace ueber alle Cardio-Sets. "M:SS /km"
    /// via `PaceCalculator.minutesPerKm` — same Algo wie ActiveWorkoutView.
    private var formattedAvgPace: String {
        let totalKm = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        let totalSec = session.logs.compactMap(\.durationSeconds).reduce(0, +)
        guard totalKm > 0, totalSec > 0,
              let pace = PaceCalculator.minutesPerKm(distanceKm: totalKm, durationSeconds: totalSec)
        else { return "—:——" }
        let total = Int((pace * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    /// UX-202: Hero-Stat-Auswahl je nach Session-Kategorie.
    /// - Strength/Mixed → Volumen-kg (typischer Erfolgsindikator)
    /// - Cardio mit Distanz → km
    /// - Cardio ohne Distanz (Indoor-Bike, Time-only) → Minuten
    @ViewBuilder
    private var heroStatView: some View {
        let hero = heroStat
        VStack(spacing: 4) {
            Text(hero.value)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                // README 2.11: bei einem vorzeitig gespeicherten Zeitformat-
                // Lauf traegt die Zahl nicht die Akzentfarbe - "4 Runden"
                // liest sich sonst als Ergebnis statt als Zwischenstand.
                .foregroundStyle(isEarlySaveTimedFormat ? Color.Deltiq.textSecondary : Color.deltiqOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(hero.unit)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }

    /// README 2.11: `completedTarget` wird geschrieben und von der PR-
    /// Erkennung gelesen, aber vorher nirgends angezeigt - ein vorzeitig
    /// gespeicherter Lauf feierte wie ein vollstaendiger.
    private var isEarlySaveTimedFormat: Bool {
        session.timeFormatSnapshot != nil && !session.completedTarget
    }

    /// Praezise (sekundengenaue) Laufzeit aus den Zeitstempeln - anders als
    /// `session.durationMinutes` (auf ganze Minuten gerundet) reicht das fuer
    /// eine "8:37"-Anzeige, ohne ein neues Feld einzufuehren.
    private var elapsedTimeText: String {
        PaceCalculator.formatDuration(max(0, Int(session.endTime.timeIntervalSince(session.startTime))))
    }

    /// README 2.11: Kurzfassung "Tag · Stand" fuer die neutrale Kapsel im
    /// Vorzeitig-gespeichert-Hero, z.B. "8:37 VON 20:00" bei einem Zeit-
    /// Deckel bzw. nur die gelaufene Zeit ohne Deckel (Auf Zeit meist ohne).
    private var earlySaveStatusText: String {
        guard let capMinutes = session.contentSnapshotTimeCapMinutes else { return elapsedTimeText }
        return String(
            format: String(localized: "summary.early.progress", bundle: .module),
            elapsedTimeText, PaceCalculator.formatDuration(capMinutes * 60)
        )
    }

    /// Repräsentiert den Hero-Wert + sein Unit-Label. Als bereits aufgeloester
    /// `String` statt `LocalizedStringKey`, weil der vorzeitig-gespeichert-
    /// Fall die verstrichene Zeit dynamisch ins Unit-Label einsetzt (README
    /// 2.11) - das laesst sich mit einem reinen Catalog-Key nicht komponieren.
    private struct HeroStat {
        let value: String
        let unit: String
    }

    private var heroStat: HeroStat {
        if let format = session.timeFormatSnapshot {
            return timedFormatHeroStat(format)
        }
        switch session.sessionCategory {
        case .pureCardio:
            let km = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
            if km > 0 {
                let str = km == km.rounded()
                    ? "\(Int(km))"
                    : km.truncated(to: 2).formattedTwoDecimals
                return HeroStat(value: str, unit: String(localized: "summary.hero.unit.km", bundle: .module))
            }
            return HeroStat(value: "\(session.durationMinutes)",
                            unit: String(localized: "summary.hero.unit.minutes", bundle: .module))
        case .mixed, .pureStrength:
            return HeroStat(value: formattedVolume, unit: String(localized: "summary.hero.unit.volumeKg", bundle: .module))
        }
    }

    /// README 2.9: das Ergebnis selbst ist der Hero-Stat, analog zu Volumen-
    /// kg bei Strength bzw. km bei Cardio. Auf-Zeit nutzt `pillLabel` als
    /// Unit-Text ("Auf Zeit"/"For Time") statt eines eigenen Keys - identisch
    /// zur Kontextzeile im Player.
    ///
    /// README 2.11: bei einem vorzeitig gespeicherten AMRAP/EMOM wandert die
    /// verstrichene Zeit zusaetzlich ins Unit-Label ("RUNDEN GESCHAFFT IN
    /// 8:37") - "4 Runden" allein liest sich sonst als Ergebnis, nicht als
    /// Zwischenstand. Bei Auf Zeit ist die Hero-Zahl selbst schon die Zeit,
    /// eine zweite Zeitangabe waere redundant.
    private func timedFormatHeroStat(_ format: WorkoutTimeFormat) -> HeroStat {
        switch format {
        case .amrap:
            var unit = timedFormatHeroUnit("summary.hero.unit.rounds")
            // Nutzer-Feedback (13. August, zweite Runde): Teil-Wiederholungen
            // der angebrochenen Runde sind im Player wieder eingebbar
            // (`AMRAPPlayerView.finishBar`) - ohne diesen Zusatz wuerde der
            // eingetragene Wert hier kommentarlos verschwinden, obwohl er
            // korrekt gespeichert wurde (sichtbar bleibt er sonst nur in
            // `PRHistoryView`, und nur falls die Session ein PR war).
            if let partialReps = session.partialReps, partialReps > 0 {
                unit += " + \(partialReps) " + String(localized: "unit.reps.short", bundle: .module)
            }
            return HeroStat(value: "\(session.roundsCompleted ?? 0)", unit: unit)
        case .emom:
            return HeroStat(value: "\(session.completedMinuteCount ?? 0)", unit: timedFormatHeroUnit("summary.hero.unit.minutesDone"))
        case .forTime:
            return HeroStat(value: PaceCalculator.formatDuration(session.finishTimeSeconds ?? 0),
                            unit: String(localized: "timedWorkout.forTime.pillLabel", bundle: .module))
        case .circuit:
            // Anders als AMRAP (offene Rundenzahl) hat Zirkel ein festes
            // Rundenziel - "3/5" liest sich als Fortschritt, nicht nur als
            // Ergebnis, gerade beim vorzeitigen Speichern.
            let completed = session.circuitRoundsCompleted ?? 0
            let value = session.contentSnapshotCircuitRounds.map { "\(completed)/\($0)" } ?? "\(completed)"
            return HeroStat(value: value, unit: timedFormatHeroUnit("summary.hero.unit.circuitRounds"))
        case .enduranceIntervals:
            // Paket 2: wie Zirkel oben - "3/5" liest sich als Fortschritt.
            // Reuse desselben Unit-Texts ("RUNDEN") statt eines eigenen Keys -
            // bedeutet hier dasselbe (abgeschlossene Belastungs-/Erholungs-
            // Wiederholungen).
            let completed = session.enduranceRoundsCompleted ?? 0
            let value = session.contentSnapshotEnduranceIntervalRounds.map { "\(completed)/\($0)" } ?? "\(completed)"
            return HeroStat(value: value, unit: timedFormatHeroUnit("summary.hero.unit.circuitRounds"))
        }
    }

    private func timedFormatHeroUnit(_ key: String) -> String {
        let base = String(localized: String.LocalizationValue(key), bundle: .module)
        guard isEarlySaveTimedFormat else { return base }
        return String(format: String(localized: "summary.early.unitWithTime", bundle: .module), base, elapsedTimeText)
    }

    @ViewBuilder
    private var notesSection: some View {
        // Notes-Edit erlaubt in: New-Mode (post-finish-Summary, .isReadOnly=false)
        // + History-Edit-Mode (isReadOnly && isEditingHistory). Reine History-
        // Detail-Ansicht: nur Anzeige, keine Editier-Felder.
        let notesEditable = !isReadOnly || isEditingHistory
        if !notesEditable {
            // Hide the section entirely when there's no note — empty state is uglier
            // than a missing section in a history-detail view.
            if let notes = session.notes, !notes.isEmpty {
                Section {
                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.Deltiq.surface)
                } header: {
                    sectionHeader(String(localized: "summary.note.label", bundle: .module))
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
        } else {
            Section {
                TextField(
                    text: Binding(
                        get: { session.notes ?? "" },
                        set: { session.notes = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text("summary.note.placeholder", bundle: .module),
                    axis: .vertical
                ) {
                    Text("summary.note.label", bundle: .module)
                }
                .font(.system(size: 15))
                .lineLimit(3...8)
                .listRowBackground(Color.Deltiq.surface)
            } header: {
                sectionHeader(String(localized: "summary.note.label", bundle: .module))
            } footer: {
                Text("summary.note.footer", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
    }

    @ViewBuilder
    private var breakdownSections: some View {
        // README 2.9: Zeitformat-Sessions loggen nie ExerciseLogs (das
        // Ergebnis lebt in roundsCompleted/finishTimeSeconds/... statt
        // Set-Historie) - `exercisesWithLogs.isEmpty` waere hier IMMER
        // true und wuerde faelschlich "Keine Saetze geloggt." zeigen, als
        // waere etwas schiefgelaufen. Eigener Read-Only-Zirkel-Branch statt
        // des Leer-Zustands.
        if let format = session.timeFormatSnapshot {
            timedFormatCircuitSection(format)
        } else if exercisesWithLogs.isEmpty {
            Section {
                Text("summary.setsEmpty", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .font(.system(size: 13))
                    .listRowBackground(Color.Deltiq.surface)
            } header: {
                sectionHeader(String(localized: "summary.setsHeader", bundle: .module))
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        } else {
            ForEach(exercisesWithLogs) { group in
                switch group {
                case .live(let exercise, let logs):
                    exerciseSection(for: exercise, logs: logs)
                case .orphaned(_, let logs):
                    orphanedExerciseSection(logs: logs)
                }
            }
        }
        // DEL-136 Part C: "+ Übung hinzufügen" Section nur im History-Edit-
        // Mode. Im New-Mode (post-finish) macht das keinen Sinn — User ist
        // gerade fertig und soll nicht zurueck zu mehr Volumen geprompted
        // werden. Tap → ExercisePicker Sheet → onSelect erstellt eine
        // orphan Exercise (day=nil, kein Plan-Polluting) + N Default-Logs.
        // README 2.9: bei Zeitformaten ausgeblendet - es gibt kein Set-
        // basiertes Log, in das sich eine hinzugefuegte Uebung einreihen
        // koennte.
        if isReadOnly && isEditingHistory && session.timeFormatSnapshot == nil {
            Section {
                Button {
                    showingAddExercisePicker = true
                } label: {
                    Label {
                        Text("summary.addExercise.button", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.deltiqOrange)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.deltiqOrange)
                }
                .listRowBackground(Color.Deltiq.surface)
            } footer: {
                Text("summary.addExercise.hint", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
    }

    // P8 Stufe-2-Nachbesserung: `contentSnapshotFirst`/
    // `contentSnapshotTimeCapMinutes`/`contentSnapshotCircuitRounds`/
    // `contentSnapshotCircuitRestSeconds` sind jetzt eine geteilte
    // `WorkoutSession`-Extension (`FitnessAppData/
    // WorkoutSessionContentSnapshotFirst.swift`) — auch die Zeitformat-/
    // Zirkel-Player brauchen sie für die Wiederaufnahme-Isolation.

    /// P8 Stufe-2: einheitliche, leseseitige Sicht auf eine Zeitformat-/
    /// Zirkel-Übung für `timedFormatCircuitSection`. `orderIndex` ist der
    /// Identitäts-Schlüssel (nicht der Name) — zwei gleichnamige Übungen
    /// (z. B. zwei Zirkel-Stationen mit demselben Lift) bleiben dadurch
    /// unterscheidbar, genau wie im Snapshot selbst
    /// (`TrainingDayContentSnapshot.ExerciseEntry`-Dokumentation).
    private struct TimedFormatDisplayExercise {
        let orderIndex: Int
        let displayName: String
        let repsMin: Int
        let isTimeBased: Bool
        let sets: Int
    }

    /// P8 Stufe-2: liefert die Übungsliste für `timedFormatCircuitSection`.
    /// Bevorzugt IMMER den eingefrorenen Tages-Snapshot dieser Session —
    /// Reihenfolge/Namen/Ziele zum Zeitpunkt der Session, nicht den
    /// eventuell seither bearbeiteten oder gelöschten Live-Tag. Nur wenn
    /// für diese Session NIE ein Snapshot erfasst wurde (Altbestand vor
    /// diesem Feature), fällt es auf den Live-Tag zurück — unverändertes
    /// Verhalten von vorher für genau diesen Altbestand-Fall, aber
    /// `contentSnapshotUnverifiedNotice` macht das in der UI sichtbar.
    /// Ein BESCHÄDIGTER/nicht unterstützter Snapshot liefert explizit
    /// `nil` — wird NIE stillschweigend durch den Live-Tag ersetzt.
    private var timedFormatDisplayExercises: [TimedFormatDisplayExercise]? {
        switch session.contentSnapshotState {
        case .available(let snapshot):
            return snapshot.exercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { entry in
                    let name: String
                    if let custom = entry.customNameSnapshot, !custom.isEmpty {
                        name = custom
                    } else {
                        name = Exercise.resolvedDisplayName(forStoredName: entry.nameSnapshot)
                    }
                    return TimedFormatDisplayExercise(
                        orderIndex: entry.orderIndex, displayName: name,
                        repsMin: entry.repsMin, isTimeBased: entry.isTimeBased, sets: entry.sets
                    )
                }
        case .notCaptured:
            return (session.day?.activeExercises ?? [])
                .sorted { $0.orderIndex < $1.orderIndex }
                .map {
                    TimedFormatDisplayExercise(
                        orderIndex: $0.orderIndex, displayName: $0.displayName,
                        repsMin: $0.repsMin, isTimeBased: $0.isTimeBased, sets: $0.sets
                    )
                }
        case .unreadable:
            return nil
        }
    }

    /// Sichtbarer Hinweis, wenn die gezeigte Übungsliste NICHT der
    /// verifizierte historische Stand ist (Auftrag: "fehlende Historie
    /// sichtbar kennzeichnen" / "aktuelle Planinhalte niemals als
    /// historischen Stand ausgeben"). Greift nur für Altbestand vor P8
    /// (`.notCaptured`) — `.available` ist per Definition verifiziert,
    /// `.unreadable` zeigt stattdessen `contentSnapshotUnreadableNotice`.
    @ViewBuilder
    private var contentSnapshotUnverifiedNotice: some View {
        if case .notCaptured = session.contentSnapshotState {
            Text("summary.content.noHistoricalSnapshot", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    /// README 2.9: Read-only Referenzliste der Zirkel-Uebungen (Name +
    /// Wdh./Runden), damit man Wochen spaeter noch sieht, WAS man gemacht
    /// hat - ohne eine Set-Historie zu erfinden, die es fuer Zeitformate
    /// nie gab. Quelle ist der P8-Snapshot (siehe
    /// `timedFormatDisplayExercises`), NICHT mehr der Live-Tag — eine
    /// spätere Tag-Bearbeitung/-Löschung ändert diese Liste jetzt nicht
    /// mehr rückwirkend.
    @ViewBuilder
    private func timedFormatCircuitSection(_ format: WorkoutTimeFormat) -> some View {
        if case .unreadable = session.contentSnapshotState {
            Section {
                Text("summary.content.unreadable", bundle: .module)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
            } header: {
                sectionHeader(String(localized: "summary.stat.exercises", bundle: .module))
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        } else if let exercises = timedFormatDisplayExercises, !exercises.isEmpty {
            // Nutzer-Feedback 6. August: "15 Runden" allein beantwortet nicht
            // "wie viele Klimmzuege waren das insgesamt" - fuer AMRAP zeigt
            // die Zeile jetzt Gesamt-Wiederholungen statt nur dem Pro-Runde-
            // Ziel. EMOM/Auf-Zeit bleiben unveraendert (dort gibt es kein
            // sinnvolles "Gesamt" - EMOM ist pass/fail pro Minute, Auf Zeit
            // hat schon eine feste Rundenzahl als Ziel selbst).
            let amrapTotals = format == .amrap ? amrapExerciseTotals(exercises) : nil
            Section {
                ForEach(exercises, id: \.orderIndex) { exercise in
                    if let amrapTotals {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.displayName)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.primary)
                                Text(
                                    String(
                                        format: String(localized: "summary.amrap.perRound", bundle: .module),
                                        timedFormatTargetLabel(repsMin: exercise.repsMin, isTimeBased: exercise.isTimeBased)
                                    )
                                )
                                .font(.system(size: 12))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                            }
                            Spacer()
                            Text(amrapTotalValueText(exercise, totals: amrapTotals))
                                .font(.system(size: 15))
                                .fitnessNumberStyle()
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                        .listRowBackground(Color.Deltiq.surface)
                    } else {
                        HStack(spacing: 8) {
                            Text(exercise.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Text(circuitValueLabel(exercise, format: format))
                                .font(.system(size: 15))
                                .fitnessNumberStyle()
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                        .listRowBackground(Color.Deltiq.surface)
                    }
                }
            } header: {
                sectionHeader(String(localized: "summary.stat.exercises", bundle: .module))
            } footer: {
                contentSnapshotUnverifiedNotice
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
    }

    /// README (Nutzer-Feedback 6. August): Gesamt-Wiederholungen pro Uebung
    /// ueber die komplette Session - "15 Runden Cindy" heisst 75 Klimmzuege +
    /// 150 Liegestuetze + 225 Kniebeugen, nicht nur "15 Runden". `nil` wenn es
    /// nichts zu zeigen gibt (noch keine volle Runde geschafft und keine
    /// angebrochene Station).
    /// Wiederhergestellt (13. August, zweite Runde): `finishBar` befuellt
    /// `partialReps`/`partialRepsExerciseName` wieder - ohne diesen Zusatz
    /// wuerden die Uebungen VOR der angebrochenen Station in derselben Runde
    /// (schon fertig, bevor die Zeit ablief) und die angebrochene Station
    /// selbst hier stillschweigend unterzaehlt, waehrend die Hero-Zahl direkt
    /// darueber (`timedFormatHeroStat`) den vollen Stand korrekt zeigt.
    /// Namens- statt ID-Abgleich fuer `currentIndex`, weil
    /// `partialRepsExerciseName` ein Snapshot ist (gleiches Muster wie
    /// `dayName`), keine live Relationship.
    private func amrapExerciseTotals(_ exercises: [TimedFormatDisplayExercise]) -> [Int: Int]? {
        let rounds = session.roundsCompleted ?? 0
        let partial = session.partialReps ?? 0
        guard rounds > 0 || partial > 0 || session.partialRepsExerciseName != nil else { return nil }
        let currentIndex = session.partialRepsExerciseName.flatMap { name in
            exercises.firstIndex { $0.displayName == name }
        }
        var totals: [Int: Int] = [:]
        for (index, exercise) in exercises.enumerated() {
            var total = rounds * exercise.repsMin
            if let currentIndex {
                if index < currentIndex {
                    total += exercise.repsMin
                } else if index == currentIndex {
                    total += partial
                }
            }
            totals[exercise.orderIndex] = total
        }
        return totals
    }

    private func amrapTotalValueText(_ exercise: TimedFormatDisplayExercise, totals: [Int: Int]) -> String {
        let total = totals[exercise.orderIndex] ?? 0
        let unit = exercise.isTimeBased
            ? String(localized: "unit.seconds.short", bundle: .module)
            : String(localized: "unit.reps.short", bundle: .module)
        return "\(total) \(unit)"
    }

    /// Duenner Wrapper um das geteilte `timedFormatCircuitLabel`
    /// (TimedWorkoutPlayerView.swift) - siehe dort fuer die Begruendung.
    private func circuitValueLabel(_ exercise: TimedFormatDisplayExercise, format: WorkoutTimeFormat) -> String {
        timedFormatCircuitLabel(
            repsMin: exercise.repsMin, isTimeBased: exercise.isTimeBased,
            sets: exercise.sets, format: format
        )
    }

    private func exerciseSection(for exercise: Exercise, logs: [ExerciseLog]) -> some View {
        Section {
            // .onDelete only registers when the session is editable — entweder
            // im New-Mode (Post-Finish-Cleanup) oder im History-Edit-Mode
            // (DEL-032: Bearbeiten-Button getoggled).
            let editable = !isReadOnly || isEditingHistory
            if editable {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, isEditable: isEditingSets)
                }
                // .onDelete braucht DynamicViewContent (ForEach) - muss VOR
                // .listRowBackground stehen, sonst erased letzteres bereits
                // auf ein generisches View, das kein .onDelete mehr hat.
                .onDelete { offsets in
                    deleteSets(of: exercise, indices: offsets)
                }
                .listRowBackground(Color.Deltiq.surface)
                // DEL-136 Part C-Iteration: "+ Satz hinzufügen"-Row im
                // History-Edit-Mode. Nur isEditingHistory, NICHT im
                // New-Mode (post-finish) — dort gibt's keinen Use-Case
                // fuer nachtraegliche Sätze, der finishWorkout-Flow hat
                // gerade erst die totals geschrieben.
                if isReadOnly && isEditingHistory {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            addSet(to: exercise)
                        }
                    } label: {
                        Label {
                            Text("summary.addSet.button", bundle: .module)
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.deltiqOrange)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.Deltiq.surface)
                }
            } else {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, isEditable: false)
                }
                .listRowBackground(Color.Deltiq.surface)
            }

            // DEL-155: Cardio-Equipment pro Cardio-Uebung — unabhaengig davon,
            // ob die Session pure-Cardio oder mixed ist (Sichtbarkeit haengt
            // an exercise.isCardio, NICHT am Session-Typ). Editierbar im
            // New-Mode (post-finish) + History-Edit-Mode; sonst Read-Only-
            // Anzeige (nur wenn ein Equipment gesetzt ist).
            //
            // DEL-193: Bei Outdoor-Cardio ausblenden. Wenn die Session ein
            // Gear (Schuh/Bike) trägt, ist es eine Gear-basierte Outdoor-
            // Einheit — der Cardio-Geräte-Picker ("Laufband/Fahrrad/Kein
            // Gerät") ist dann redundantes Rauschen neben der "Ausrüstung"-
            // Zeile oben. Der Picker erscheint nur, wenn KEIN Gear gesetzt
            // ist (also Indoor/Maschine, wo Laufband vs Fahrrad relevant
            // für die PR-/Trend-Trennung ist).
            //
            // CardioEquipmentPicker/-DisplayRow bleiben unangetastet - ein
            // gemeinsam mit dem (out-of-scope) ExerciseEditorView genutztes
            // Shared-Component, analog zur DeltiqFormSection-Entscheidung.
            if exercise.isCardio && session.gear == nil {
                if editable {
                    CardioEquipmentPicker(selection: Binding(
                        get: { exercise.cardioEquipment },
                        set: { exercise.cardioEquipment = $0 }
                    ))
                    .listRowBackground(Color.Deltiq.surface)
                } else if exercise.cardioEquipment != .none {
                    CardioEquipmentDisplayRow(equipment: exercise.cardioEquipment)
                        .listRowBackground(Color.Deltiq.surface)
                }
            }
        } header: {
            HStack {
                // Handoff 1.5/1.6: Uebungsname bleibt Karten-Titel-prominent
                // statt Eyebrow-Stil - anders als kategorische Section-
                // Header (PRs, Achievements, ...) identifiziert er ein
                // konkretes Item, kein Themen-Cluster. Gleiche Gewichtung
                // wie ExerciseCard.header in ActiveWorkoutView.
                Text(exercise.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.primary)
                Spacer()
                // DEL-136 Part B: Im History-Edit-Mode bekommt jede Section
                // einen kleinen "..." Menu-Button, ueber den die ganze
                // Uebung aus der Session entfernt werden kann. Confirmation
                // verhindert dass User per Versehen alle Sets verliert.
                if isReadOnly && isEditingHistory {
                    Menu {
                        Button(role: .destructive) {
                            exerciseToRemove = exercise
                        } label: {
                            Label {
                                Text("summary.exercise.removeFromSession", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.deltiqOrange)
                    }
                    .textCase(nil)
                } else if let best = bestSet(in: logs) {
                    Text("\(String(localized: "summary.exercise.bestPrefix", bundle: .module)): \(formatSetSummary(best))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .textCase(nil)
                }
            }
        } footer: {
            Text(formatBreakdownFooter(setsCount: logs.count, volume: formatVolume(logs)))
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// P8 Stufe-2: Darstellung für Logs, deren `Exercise` inzwischen
    /// gelöscht wurde (orphan). Read-only, UNABHÄNGIG vom History-Edit-
    /// Mode — es gibt kein lebendes Objekt mehr, an das ein Satz-Delete,
    /// ein "+ Satz"-Insert oder der Cardio-Equipment-Picker sicher binden
    /// könnte. Das ist eine bewusste, kleine Einschränkung gegenüber dem
    /// lebenden Pfad: dieser Auftrag deckt die KORREKTE Zuordnung/Anzeige
    /// verwaister Sätze ab (sie verschwinden nicht mehr unsichtbar), nicht
    /// ihre nachträgliche Editierbarkeit.
    private func orphanedExerciseSection(logs: [ExerciseLog]) -> some View {
        let name = Exercise.resolvedDisplayName(forStoredName: logs.first?.resolvedExerciseName ?? "?")
        return Section {
            ForEach(logs) { log in
                SetSummaryRow(log: log, isEditable: false)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            HStack {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if let best = bestSet(in: logs) {
                    Text("\(String(localized: "summary.exercise.bestPrefix", bundle: .module)): \(formatSetSummary(best))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .textCase(nil)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatBreakdownFooter(setsCount: logs.count, volume: formatVolume(logs)))
                Text("summary.exercise.originalDeleted", bundle: .module)
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// DEL-126: i18n-Footer "X Satz/Sätze • Y kg Volumen". Plural-Branch wird
    /// via Namespace-Keys (`.one` / `.other`) statt Apple-Format-Pattern
    /// abgebildet — Xcode 26.4.1's `GenerateStringSymbols`-Step verschluckt
    /// sich an variations.plural in xcstrings (Build-Saga DEL-121).
    private func formatBreakdownFooter(setsCount: Int, volume: String) -> String {
        let key: String.LocalizationValue = setsCount == 1
            ? "summary.exercise.footer.one"
            : "summary.exercise.footer.other"
        let raw = String(localized: key, bundle: .module)
        return raw
            .replacingOccurrences(of: "%1$lld", with: "\(setsCount)")
            .replacingOccurrences(of: "%2$@",   with: volume)
    }

    private var finishSection: some View {
        Section {
            // Handoff 1.9: Primaerer Hero-CTA statt gruen-hinterlegter
            // Row - .deltiqButtonStyle() bringt Gradient/Glow/Rundung schon
            // mit, listRowBackground/-Insets werden geleert, damit Listens
            // eigenes Zeilen-Chrome die Button-Optik nicht doppelt umrahmt.
            Button {
                navigation.returnToDashboard()
            } label: {
                Label {
                    Text("summary.action.finish", bundle: .module)
                } icon: {
                    Image(systemName: "house.fill")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            Text("summary.finishFooter", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    // MARK: Derived

    /// Logs grouped by exercise, ordered by `Exercise.orderIndex` (matches
    /// the plan). Gruppierlogik ausgelagert nach `FitnessAppData.
    /// ExerciseLogGrouping` (Apple-CI-testbar, unabhängig von dieser View) —
    /// siehe dort für orphane Logs (gelöschte `Exercise`) und die
    /// Duplikat-Namen-Absicherung.
    private var exercisesWithLogs: [ExerciseLogGroup] {
        ExerciseLogGrouping.group(session.logs)
    }

    private var formattedDuration: String {
        // Genau auf die Sekunde ("25:56"), solange Beginn und Ende zur Dauer
        // passen; nach einer im Verlauf geaenderten Dauer nur die Minuten.
        if let exact = session.exactDurationText { return exact }
        let mins = session.durationMinutes
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        let minUnit = String(localized: "unit.minutes.short", bundle: .module)
        return "\(mins) \(minUnit)"
    }

    private var formattedVolume: String {
        session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals
    }

    private var statDivider: some View {
        Divider().frame(height: 32)
    }

    // MARK: Best-set / volume helpers — delegate to Core's WorkoutAnalytics

    /// Returns the ExerciseLog with the highest weight×reps volume. Same algorithm
    /// as `WorkoutAnalytics.bestSet`, but returns the @Model instance so the row
    /// view can read its full state. Inline `.max` mirrors the Core implementation.
    private func bestSet(in logs: [ExerciseLog]) -> ExerciseLog? {
        logs.max { lhs, rhs in
            lhs.weight * Double(lhs.reps) < rhs.weight * Double(rhs.reps)
        }
    }

    private func formatVolume(_ logs: [ExerciseLog]) -> String {
        let attempts = logs.map { LiftAttempt(exerciseName: "",
                                              weightKg: $0.weight,
                                              reps: $0.reps,
                                              date: $0.date) }
        return WorkoutAnalytics.totalVolume(in: attempts)
            .truncated(to: 0)
            .formattedTwoDecimals
    }

    /// P8 Stufe-2: braucht keine `Exercise` mehr — `log.resolvedIsCardio`/
    /// `resolvedIsTimeBased` sind snapshot-first und liefern denselben Wert
    /// wie vorher `exercise.isCardio`/`isTimeBased`, solange die Übung noch
    /// lebt, und bleiben auch nach ihrem Löschen korrekt (siehe
    /// `exercisesWithLogs`).
    private func formatSetSummary(_ log: ExerciseLog) -> String {
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        if log.resolvedIsCardio {
            return "\(log.reps) \(log.resolvedIsTimeBased ? secUnit : repUnit)"
        }
        if log.resolvedIsTimeBased {
            return "\(log.reps) \(secUnit)"
        }
        return "\(log.weight.formattedWholeOrTwoDecimals) kg × \(log.reps)"
    }

    // MARK: Delete + re-index

    /// Deletes specific logs of an exercise, then re-indexes the remaining sets so
    /// `setIndex` stays a contiguous 0..n-1. Re-indexing keeps the "Letztes: ..."
    /// hint logic correct in future workouts (it matches by `setIndex`).
    private func deleteSets(of exercise: Exercise, indices: IndexSet) {
        let logs = exercise.logs
            .filter { $0.session?.persistentModelID == session.persistentModelID }
            .sorted { $0.setIndex < $1.setIndex }

        // DEL-213: Gear-km der geloeschten Cardio-Logs zurueckbuchen, bevor
        // sie verschwinden — sonst bleibt die Distanz auf Schuh/Rad stehen.
        // DEL-222: Rueckbuchung ueber GearOdometer.
        let removedKm = GearDistance.total(of: indices.map { logs[$0].distanceKm })
        GearOdometer.book(deltaKm: -removedKm, to: session.gear)

        for index in indices {
            modelContext.delete(logs[index])
        }

        // Re-index remaining sets in this exercise.
        let remaining = exercise.logs
            .filter { $0.session?.persistentModelID == session.persistentModelID }
            .sorted { $0.setIndex < $1.setIndex }
        for (i, log) in remaining.enumerated() {
            log.setIndex = i
        }

        // Update session-level aggregates (DEL-221: ein Schreiber).
        session.recomputeTotals()
    }
}

// MARK: - Subviews

// MARK: - UX-204 Badge-Appear-Effect

/// Shared spring-in animation für PR-/Achievement-/Progression-Badges.
/// Subtile Skalierung 0.94 → 1.0 + Fade 0 → 1, mit kleinem Delay damit
/// die Badges leicht NACH dem Hero-Spring kommen — sequenzielles Reveal
/// statt simultaner Pop. Reduce-Motion respektiert: kein Spring, direkt
/// im Endzustand rendern.
@available(iOS 17.0, macOS 14.0, *)
private struct BadgeAppearEffect: ViewModifier {
    @State private var didAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(didAppear ? 1.0 : 0.94)
            .opacity(didAppear ? 1.0 : 0.0)
            .onAppear {
                if reduceMotion {
                    didAppear = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
                        didAppear = true
                    }
                }
            }
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
    fileprivate func badgeAppearEffect() -> some View {
        modifier(BadgeAppearEffect())
    }
}

// MARK: - PR Badge

@available(iOS 17.0, macOS 14.0, *)
private struct PRBadge: View {
    let record: PersonalRecord

    var body: some View {
        HStack(spacing: 12) {
            // UX-205: 36×36 Icon-Square via geteiltem `.deltiqIconBadge`-
            // Modifier. PRBadge + AchievementBadge + ProgressionBadge
            // teilen jetzt eine Single Source of Truth fuer das Icon-
            // Layout — vorher war derselbe 6-Zeiler 3x dupliziert.
            Image(systemName: kindIcon)
                .deltiqIconBadge(tint: Color.deltiqOrange)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-149: Snapshot-resolver — rendert den DE-Base ODER
                // einen vor-DEL-149 unter fremder Locale gespeicherten Namen
                // (z.B. "Koşu Bandı") via Reverse-Lookup in der aktuellen
                // Sprache.
                Text(Exercise.resolvedDisplayName(forStoredName: record.exerciseName))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(kindLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Text(detailLine)
                    .font(.system(size: 14))
                    .fitnessNumberStyle()
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            // DEL-064: fastestPace ist lower-is-better — die Verbesserung
            // ist ein negativer Delta. Wir zeigen sie als positiv-formatiertes
            // Improvement, sonst sieht der Trophy-Pill aus wie ein Rueckschritt.
            Text(improvementPill)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.Deltiq.success)
                .fitnessNumberStyle()
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    /// DEL-064: kind-aware Improvement-Prozent. Lower-is-better-Kinds
    /// (`.fastestPace`, `.fastestTime`) invertieren den Delta-Vorzug.
    private var improvementPill: String {
        let isLowerBetter: Bool = (record.kind == .fastestPace || record.kind == .fastestTime)
        let raw = record.deltaPercent
        let improvement = isLowerBetter ? -raw : raw
        return "+\(improvement.formattedPercentRounded)"
    }

    /// Handoff 1.10 (ein Akzent): unterscheidet die PR-Art jetzt allein ueber
    /// Icon-Form + `kindLabel`-Text - die fruehere `kindColor` (7 eigene
    /// Farben pro Art) ist entfallen, alle Badges teilen sich das Orange
    /// von `.deltiqIconBadge`.
    private var kindIcon: String {
        switch record.kind {
        case .estimated1RM:     "bolt.fill"
        case .heaviestWeight:   "scalemass.fill"
        case .bestSet:          "chart.bar.fill"
        case .maxReps:          "arrow.up.arrow.down"
        case .maxHoldSeconds:   "stopwatch.fill"
        // DEL-064 Cardio-PRs
        case .longestDistance:  "figure.run.circle.fill"
        case .fastestPace:      "hare.fill"
        // Zeitformate (README 2.9)
        case .mostRounds:       "repeat.circle.fill"
        case .fastestTime:      "stopwatch.fill"
        }
    }

    private var kindLabel: String {
        switch record.kind {
        case .estimated1RM:     String(localized: "pr.kind.estimated1RM",    bundle: .module)
        case .heaviestWeight:   String(localized: "pr.kind.heaviestWeight",  bundle: .module)
        case .bestSet:          String(localized: "pr.kind.bestSet",         bundle: .module)
        case .maxReps:          String(localized: "pr.kind.maxReps",         bundle: .module)
        case .maxHoldSeconds:   String(localized: "pr.kind.maxHoldSeconds",  bundle: .module)
        case .longestDistance:  String(localized: "pr.kind.longestDistance", bundle: .module)
        case .fastestPace:      String(localized: "pr.kind.fastestPace",     bundle: .module)
        case .mostRounds:       String(localized: "pr.kind.mostRounds",      bundle: .module)
        case .fastestTime:      String(localized: "pr.kind.fastestTime",     bundle: .module)
        }
    }

    /// Per-kind detail string. Three flavors:
    ///   - Weighted PRs: "X kg × Y → Z kg (vorher V kg)"  (or " kg-Vol" for bestSet)
    ///   - maxReps:      "Y Wdh → Y Wdh (vorher V Wdh)"   (weight always 0 here)
    ///   - maxHoldSeconds: "Y Sek → Y Sek (vorher V Sek)"
    private var detailLine: String {
        // DEL-126: alle Inline-Strings via xcstrings — Sek/Wdh/vorher/kg-Vol
        // mappen DE/EN/TR korrekt.
        let prev = String(localized: "pr.previousShort", bundle: .module)
        let volSfx = String(localized: "pr.volumeSuffix", bundle: .module)
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        switch record.kind {
        case .maxReps:
            let prevReps = Int(record.previousValue.rounded())
            return "\(record.reps) \(repUnit) (\(prev) \(prevReps) \(repUnit))"

        case .maxHoldSeconds:
            let prevSec = Int(record.previousValue.rounded())
            return "\(record.reps) \(secUnit) (\(prev) \(prevSec) \(secUnit))"

        case .estimated1RM, .heaviestWeight, .bestSet:
            let weightStr = record.weightKg.formattedWholeOrTwoDecimals
            let prevStr: String = {
                switch record.kind {
                case .bestSet:        return "\(record.previousValue.formattedWholeOrTwoDecimals) \(volSfx)"
                default:              return "\(record.previousValue.formattedWholeOrTwoDecimals) kg"
                }
            }()
            let nowStr: String = {
                switch record.kind {
                case .bestSet:        return "\(record.newValue.formattedWholeOrTwoDecimals) \(volSfx)"
                default:              return "\(record.newValue.formattedWholeOrTwoDecimals) kg"
                }
            }()
            return "\(weightStr) kg × \(record.reps) → \(nowStr) (\(prev) \(prevStr))"

        // DEL-064 Cardio-PRs
        case .longestDistance:
            return "\(record.newValue.formattedWholeOrTwoDecimals) km (\(prev) \(record.previousValue.formattedWholeOrTwoDecimals) km)"
        case .fastestPace:
            return "\(PaceCalculator.formatPace(record.newValue)) (\(prev) \(PaceCalculator.formatPace(record.previousValue)))"

        // Zeitformate (README 2.9)
        case .mostRounds:
            let prevRounds = Int(record.previousValue.rounded())
            // Bugfix (Teil-Wiederholungen entfernt): siehe PRHistoryView.swift
            // fuer die Begruendung des reps > 0-Gates.
            guard record.reps > 0 else {
                return "\(Int(record.newValue)) Runden (\(prev) \(prevRounds) Runden)"
            }
            return "\(Int(record.newValue)) Runden + \(record.reps) \(repUnit) (\(prev) \(prevRounds) Runden)"
        case .fastestTime:
            return "\(formatDuration(record.newValue)) (\(prev) \(formatDuration(record.previousValue)))"
        }
    }

    /// Formatiert Auf-Zeit-Ergebnisse (Sekunden). Wiederverwendet
    /// `PaceCalculator.formatDuration` statt eines eigenen mm:ss-Formatters
    /// (dieselbe Funktion ruft die Datei bereits an anderer Stelle, Z. 1923).
    private func formatDuration(_ totalSeconds: Double) -> String {
        PaceCalculator.formatDuration(Int(totalSeconds.rounded()))
    }
}

// MARK: - UX-202 Achievement Badge

/// Eine Zeile in der UX-202-Achievements-Section. Visuell baut sie auf
/// dem gleichen Frame wie PRBadge + ProgressionBadge auf (36×36 Icon-
/// Square mit gradientem Tint + Title + Subtitle) — Konsistenz im
/// Reward-Layout, sodass User die drei Zell-Typen sofort als Achievement-
/// Familie wiedererkennt.
@available(iOS 17.0, macOS 14.0, *)
private struct AchievementBadge: View {
    let achievement: WorkoutAchievementDetector.Achievement

    var body: some View {
        HStack(spacing: 12) {
            // UX-205: 36×36 Icon via geteiltem Modifier.
            Image(systemName: icon)
                .deltiqIconBadge(tint: Color.deltiqOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    /// Handoff 1.10 (ein Akzent): unterscheidet die Achievement-Art jetzt
    /// allein ueber Icon-Form + `title`/`subtitle` - die fruehere `tint`
    /// (4 verschiedene Semantic-Token-Farben) ist entfallen.
    private var icon: String {
        switch achievement.kind {
        case .weeklyMilestone:           return "flame.fill"
        case .heaviestOfWeek:            return "scalemass.fill"
        case .longestOfWeek:             return "clock.badge.checkmark"
        case .longestDistanceOfWeek:     return "figure.run"
        }
    }

    private var title: String {
        switch achievement.kind {
        case .weeklyMilestone(let count):
            let raw = String(localized: "summary.achievements.weeklyMilestone.titleFormat",
                             bundle: .module)
            // Direct %lld substitution — Apple-Plural-Pattern wuerde an
            // Xcode-26.4.1's GenerateStringSymbols ersticken (DEL-121).
            return raw.replacingOccurrences(of: "%lld", with: "\(count)")
        case .heaviestOfWeek:
            return String(localized: "summary.achievements.heaviestOfWeek.title", bundle: .module)
        case .longestOfWeek:
            return String(localized: "summary.achievements.longestOfWeek.title", bundle: .module)
        case .longestDistanceOfWeek:
            return String(localized: "summary.achievements.longestDistanceOfWeek.title", bundle: .module)
        }
    }

    private var subtitle: String {
        switch achievement.kind {
        case .weeklyMilestone:
            return String(localized: "summary.achievements.weeklyMilestone.subtitle", bundle: .module)
        case .heaviestOfWeek:
            return String(localized: "summary.achievements.heaviestOfWeek.subtitle", bundle: .module)
        case .longestOfWeek:
            return String(localized: "summary.achievements.longestOfWeek.subtitle", bundle: .module)
        case .longestDistanceOfWeek:
            return String(localized: "summary.achievements.longestDistanceOfWeek.subtitle", bundle: .module)
        }
    }
}

// MARK: - DEL-052/053 Progression Badge

/// Eine Zeile in der Smart-Progression-Section von WorkoutSummary. Pro
/// Uebung zeigt sie das alte/neue Ziel-Gewicht (oder "Deload"-Hinweis) plus
/// einen kurzen Motivations-Text. Hold-Outcomes landen nicht hier (sie
/// kommen nicht vom Applicator).
@available(iOS 17.0, macOS 14.0, *)
private struct ProgressionBadge: View {
    let outcome: ProgressionApplicator.ProgressionOutcome

    var body: some View {
        HStack(spacing: 12) {
            // UX-205: 36×36 Icon via geteiltem Modifier.
            Image(systemName: icon)
                .deltiqIconBadge(tint: Color.deltiqOrange)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-149: lokalisierter Display-Name via Snapshot-Resolver —
                // outcome.exerciseName ist ein DE-Base-Snapshot aus dem
                // ProgressionApplicator.
                Text(Exercise.resolvedDisplayName(forStoredName: outcome.exerciseName))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(headlineText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Text(detailText)
                    .font(.system(size: 14))
                    .fitnessNumberStyle()
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            deltaPill
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    /// Handoff 1.10 (ein Akzent): Icon-Tint war Orange(increase)/
    /// Grau(deload) - beide Faelle teilen sich jetzt dasselbe Orange;
    /// "runter" bleibt trotzdem eindeutig ueber Icon-Richtung (Pfeil runter)
    /// + das Minus-Vorzeichen in `deltaPill`.
    private var icon: String {
        switch outcome.action {
        case .increaseWeight: return "arrow.up.right.circle.fill"
        case .deload:         return "arrow.down.right.circle.fill"
        case .hold:           return "minus.circle.fill"   // unreachable
        }
    }

    private var headlineText: String {
        switch outcome.action {
        case .increaseWeight: return String(localized: "progression.headline.increase", bundle: .module)
        case .deload:         return String(localized: "progression.headline.deload",   bundle: .module)
        case .hold:           return ""
        }
    }

    /// Detail-Zeile: zeigt das neue Ziel-Gewicht plus den Delta-Hinweis.
    private var detailText: String {
        guard let newWeight = outcome.newSuggestedWeight else {
            // Defensive: ohne new-weight kann hoechstens "Schritt +X kg"
            // raus.
            return deltaString
        }
        return String(format: String(localized: "progression.detail.newTargetFormat", bundle: .module),
                      newWeight.formattedWholeOrTwoDecimals)
    }

    private var deltaPill: some View {
        Text(deltaString)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(outcome.action.weightDelta >= 0 ? Color.deltiqOrange : Color.Deltiq.textSecondary)
            .fitnessNumberStyle()
    }

    private var deltaString: String {
        let delta = outcome.action.weightDelta
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
        return "\(sign)\(abs(delta).formattedWholeOrTwoDecimals) kg"
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            // DEL-059: rounded-bold Zahl + winziges getrocknetes Label
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
            Text(label.uppercased()).deltiqLabel()
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, macOS 14.0, *)
/// P8 Stufe-2: braucht keine live `Exercise`-Referenz mehr — alle
/// internen Verzweigungen (Cardio/TimeBased/Strength-Layout) laufen über
/// `log.resolvedIsCardio`/`resolvedIsTimeBased` (DEL-051, snapshot-first,
/// identisch zum vorherigen `exercise.isCardio`/`isTimeBased` solange die
/// Übung noch lebt). Das macht diese Row auch für Logs korrekt
/// darstellbar, deren `Exercise` inzwischen gelöscht wurde (orphan, siehe
/// `exercisesWithLogs`).
private struct SetSummaryRow: View {
    @Bindable var log: ExerciseLog
    /// DEL-032: im History-Edit-Mode wird die Row zu editierbaren TextFields.
    let isEditable: Bool

    var body: some View {
        if isEditable {
            editRow
        } else {
            readOnlyRow
        }
    }

    /// Anzeigemodus — gleicher Text wie vor DEL-032.
    private var readOnlyRow: some View {
        HStack(spacing: 8) {
            Text(String(format: String(localized: "set.numberLabel", bundle: .module), log.setIndex + 1))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .frame(width: 64, alignment: .leading)

            Text(rowText)
                .font(.system(size: 15))
                .fitnessNumberStyle()
                .foregroundStyle(Color.primary)

            Spacer()
        }
    }

    /// DEL-032 Edit-Modus: Gewicht/Reps als TextField + RIR als Stepper.
    /// DEL-038 Layout-Fix: drei klar getrennte Spalten mit festen Frames,
    /// Spacer dazwischen statt der Overlay-Hack-Loesung von Welle 5.
    ///
    /// DEL-137 Cardio-Fix: drei-Wege-Branch je nach Exercise-Type. Vorher
    /// blieb fuer Cardio "Wdh + RIR" stehen, was bei einem Easy Run keinen
    /// Sinn macht (kein Reps-Konzept, kein RIR-Concept).
    ///   * Cardio    → Distanz-km + MM:SS-Dauer, kein Reps/RIR
    ///   * TimeBased → Sek-Dauer + RIR (Plank: "wie hart hat's sich an-
    ///                 gefuehlt" ist legitim)
    ///   * Strength  → Gewicht + Reps + RIR (Bestandsverhalten)
    @ViewBuilder
    private var editRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "set.numberLabel", bundle: .module), log.setIndex + 1))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
            HStack(spacing: 8) {
                if log.resolvedIsCardio {
                    cardioDistanceField
                    Divider().frame(height: 24)
                    cardioDurationFields
                    Spacer(minLength: 4)
                } else if log.resolvedIsTimeBased {
                    repsField   // labeled "Sek" via unit.seconds.short
                    Spacer(minLength: 12)
                    rirBlock
                } else {
                    weightField
                    Divider().frame(height: 24)
                    repsField
                    Spacer(minLength: 12)
                    rirBlock
                }
            }
        }
        .padding(.vertical, 6)
    }

    /// DEL-137: Distanz-Eingabe in km, optional Double-Bound.
    /// DEL-213: Bucht Distanz-Korrekturen als Delta direkt auf das Session-
    /// Gear um (Schuh/Rad-Kilometerstand). Delta-basiert, damit inkrementelle
    /// Eingaben ("1" → "12") korrekt komponieren; Clamp auf 0 als Schutz.
    private var cardioDistanceField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("km",
                      value: Binding(
                        get: { log.distanceKm },
                        set: { newValue in
                            // DEL-222: Delta-Buchung ueber GearOdometer.
                            GearOdometer.book(
                                deltaKm: (newValue ?? 0) - (log.distanceKm ?? 0),
                                to: log.session?.gear
                            )
                            log.distanceKm = newValue
                        }
                      ),
                      format: .number)
                .frame(width: 60)
                .multilineTextAlignment(.leading)
                .font(.system(size: 18, weight: .semibold))
                .fitnessNumberStyle()
                .decimalKeyboard()
            Text("km").font(.system(size: 10)).foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    /// DEL-137: Dauer als Zwei-Feld-Layout (Minuten + Sekunden). User-
    /// Erwartung "5 km in 40:30" laesst sich so direkt eintippen — eine
    /// kombinierte MM:SS-Parser-Logik (wie Active-Workout) waere im
    /// Edit-Mode overkill, weil der Eingangsstrom hier Korrektur statt
    /// Live-Logging ist. Computed-Bindings rechnen zwischen Sekunden-
    /// Storage und der zwei-Feld-UI.
    private var cardioDurationFields: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("min",
                          value: Binding(
                            get: { (log.durationSeconds ?? 0) / 60 },
                            set: { newMin in
                                let curSec = (log.durationSeconds ?? 0) % 60
                                log.durationSeconds = newMin * 60 + curSec
                            }
                          ),
                          format: .number)
                    .frame(width: 40)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 18, weight: .semibold))
                    .fitnessNumberStyle()
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("min").font(.system(size: 10)).foregroundStyle(Color.Deltiq.textSecondary)
            }
            Text(":")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .offset(y: -8)   // optisch zur Minuten-Zahl ausgerichtet, nicht zur Caption
            VStack(alignment: .leading, spacing: 2) {
                TextField("sec",
                          value: Binding(
                            get: { (log.durationSeconds ?? 0) % 60 },
                            set: { newSec in
                                let curMin = (log.durationSeconds ?? 0) / 60
                                // Clamp 0...59 — Eingabe ueber 59 rollt nicht in Minuten
                                let clamped = max(0, min(59, newSec))
                                log.durationSeconds = curMin * 60 + clamped
                            }
                          ),
                          format: .number)
                    .frame(width: 36)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 18, weight: .semibold))
                    .fitnessNumberStyle()
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("sec").font(.system(size: 10)).foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
    }

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("kg", value: $log.weight, format: .number)
                .frame(width: 56)
                .multilineTextAlignment(.leading)
                .font(.system(size: 18, weight: .semibold))
                .fitnessNumberStyle()
                .decimalKeyboard()
            Text("kg").font(.system(size: 10)).foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    private var repsField: some View {
        // DEL-126: i18n-Sek/Wdh-Labels.
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        let unit = log.resolvedIsTimeBased ? secUnit : repUnit
        return VStack(alignment: .leading, spacing: 2) {
            TextField(unit, value: $log.reps, format: .number)
                .frame(width: 48)
                .multilineTextAlignment(.leading)
                .font(.system(size: 18, weight: .semibold))
                .fitnessNumberStyle()
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Text(unit).font(.system(size: 10)).foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    /// RIR-Block: Label oben, Stepper darunter — kein Overlay-Trick mehr.
    private var rirBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("RIR \(log.rir.formattedRIR)")
                .font(.system(size: 12))
                .fitnessNumberStyle()
                .foregroundStyle(Color.Deltiq.textSecondary)
            Stepper(value: $log.rir, in: 0...10, step: 0.5) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private var rowText: String {
        if log.resolvedIsCardio {
            // DEL-058: Cardio-Set zeigt Distance / Duration / Pace statt
            // kg × reps. Auslassbar wenn keiner der Felder gefuellt.
            var parts: [String] = []
            if let d = log.distanceKm, d > 0 {
                let dStr = d == d.rounded() ? "\(Int(d))" : d.truncated(to: 2).formattedTwoDecimals
                parts.append("\(dStr) km")
            }
            if let s = log.durationSeconds, s > 0 {
                parts.append(PaceCalculator.formatDuration(s))
            }
            if let d = log.distanceKm, let s = log.durationSeconds, d > 0, s > 0 {
                parts.append(PaceCalculator.pace(distanceKm: d, durationSeconds: s))
            }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        }
        if log.resolvedIsTimeBased {
            let secUnit = String(localized: "unit.seconds.short", bundle: .module)
            return "\(log.reps) \(secUnit) (RIR \(log.rir.formattedRIR))"
        }
        return "\(log.weight.formattedWholeOrTwoDecimals) kg × \(log.reps) (RIR \(log.rir.formattedRIR))"
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Summary mit voller Push-Session") {
    SummaryPreviewWrapper()
        .modelContainer(PreviewSeed.activeSessionContainer)
        .environment(AppNavigation())
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryPreviewWrapper: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completed: [WorkoutSession]

    var body: some View {
        if let session = completed.first {
            NavigationStack {
                WorkoutSummaryView(session: session)
            }
        } else {
            Text("Keine abgeschlossene Session im Preview-Container")
        }
    }
}
#endif
#endif
