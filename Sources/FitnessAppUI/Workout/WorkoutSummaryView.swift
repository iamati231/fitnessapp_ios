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
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(navigationTitleText)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(!isReadOnly)
        // DEL-223: Sicherheitsnetz gegen dauerhaft falsche Summen. Der
        // Edit-Mode rechnete `totalSets`/`totalVolumeKg` NUR im "Fertig"-
        // Toolbar-Button neu — im History-Mode ist der System-Back-Button aber
        // sichtbar (siehe `navigationBarBackButtonHidden(!isReadOnly)` direkt
        // darueber). Wer den Edit-Mode ueber Zurueck oder die Back-Swipe-Gestur
        // verliess, behielt fuer immer die Summen von VOR seiner Aenderung — in
        // Dashboard, Wochenvolumen und History.
        //
        // Bewusst nur ein Recompute und KEIN Platzhalter-Sweep: Recompute ist
        // idempotent und damit unkritisch, falls SwiftUI onDisappear
        // unerwartet feuert. Geloescht wird nur auf die explizite
        // "Fertig"-Aktion.
        .onDisappear {
            guard isReadOnly else { return }
            recalculateSessionTotals()
            try? modelContext.save()
        }
        .toolbar {
            // DEL-032: History-Mode bekommt einen Edit-Toggle. Im New-Mode
            // unsichtbar (Edit dort macht keinen Sinn — totals werden gerade
            // erst geschrieben).
            if isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if isEditingHistory {
                            // Beim Beenden vom Edit-Mode: leere Platzhalter-
                            // Zeilen aufraeumen (DEL-223), totals neu berechnen
                            // + persistieren, falls der User Set-Werte angefasst hat.
                            sweepEmptyPlaceholderLogs()
                            recalculateSessionTotals()
                            try? modelContext.save()
                        }
                        isEditingHistory.toggle()
                    } label: {
                        Text(isEditingHistory
                             ? "summary.toolbar.done"
                             : "summary.toolbar.edit",
                             bundle: .module)
                    }
                }
                // DEL-136 Part A: "..." Menu mit destructive Delete-Workout-
                // Action. Nur im History-Mode (isReadOnly) sichtbar — im
                // New-Mode (post-finish) gibt's keine Notwendigkeit, eine
                // gerade erst gespeicherte Session sofort wieder zu loeschen.
                ToolbarItem(placement: .deltiqTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteSessionConfirm = true
                        } label: {
                            Label {
                                Text("summary.menu.deleteSession", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
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
                planEnvironment: session.day?.plan?.targetEnvironment,
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
    }

    private var navigationTitleText: String {
        if isReadOnly {
            return isEditingHistory
                ? String(localized: "summary.editTitle", bundle: .module)
                : String(localized: "summary.detailTitle", bundle: .module)
        }
        return String(localized: "summary.title", bundle: .module)
    }

    /// Im Edit-Mode bekommt der User Datum + Dauer als editierbare Felder.
    /// Wird oben in der List eingeblendet, ueber statsSection.
    private var editMetaSection: some View {
        Section {
            DatePicker(selection: $session.startTime,
                       displayedComponents: [.date, .hourAndMinute]) {
                Text("summary.date", bundle: .module)
            }
            Stepper(value: $session.durationMinutes, in: 0...600, step: 5) {
                LabeledContent {
                    Text(String(format: String(localized: "summary.durationMinutes", bundle: .module), session.durationMinutes))
                } label: {
                    Text("summary.duration", bundle: .module)
                }
            }
        } header: {
            Text("summary.editMeta.header", bundle: .module)
        } footer: {
            Text("summary.editMeta.footer", bundle: .module)
                .font(.footnote)
        }
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
        try? modelContext.save()
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
        try? modelContext.save()
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
        try? modelContext.save()
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
                                .foregroundStyle(.primary)
                        } label: {
                            Label {
                                Text("summary.gear.header", bundle: .module)
                            } icon: {
                                Image(systemName: gearIcon(session.gear))
                                    .foregroundStyle(Color.deltiqOrange)
                            }
                        }
                    }
                } else if let gear = session.gear {
                    LabeledContent {
                        Text(gear.name)
                    } label: {
                        Label {
                            Text("summary.gear.header", bundle: .module)
                        } icon: {
                            Image(systemName: gearIcon(gear))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                }
            } header: {
                Text("summary.gear.header", bundle: .module)
            }
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
        try? modelContext.save()
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
        try? modelContext.save()
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
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("summary.section.personalRecords", bundle: .module)
            }
        } footer: {
            Text("summary.prFooter", bundle: .module)
                .font(.footnote)
        }
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
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(Color.deltiqOrange)
                Text("summary.section.progression", bundle: .module)
            }
        } footer: {
            Text("summary.progressionFooter", bundle: .module)
                .font(.footnote)
        }
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
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.deltiqOrange)
                Text("summary.achievements.section", bundle: .module)
            }
        }
    }

    // MARK: -

    private var heroSection: some View {
        // UX-202: Reward-Moment-Hero. Vorher: 60pt-Checkmark, statisch. Jetzt:
        //   * 88pt-Checkmark mit weicher Spring-In-Skalierung beim ersten
        //     Render (0.4 -> 1.0 in einer dampedDamping=0.55 Feder).
        //   * Subtle Glow via `.shadow` mit DeltiqOrange-Tint — gibt dem Icon
        //     den "leuchtenden Trophaeen"-Look ohne in Confetti zu verfallen.
        //   * Title-Typo eine Stufe groesser (.title.weight(.bold)) damit die
        //     Hierarchie unten in den Stat-Hero-Numbers fortgesetzt wirkt.
        // Read-Only-Replay (History-Detail) ueberspringt das Spring, weil
        // die Anim nur zum frischen Finish gehoert — beim Replay wuerde es
        // jedes Mal triggern und nervt.
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 88))
                    .symbolRenderingMode(.hierarchical)   // DEL-059
                    .foregroundStyle(.green)
                    .shadow(color: Color.deltiqOrange.opacity(0.35),
                            radius: hasAppeared ? 18 : 0,
                            x: 0, y: 0)
                    .scaleEffect(hasAppeared ? 1.0 : 0.4)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                Text("summary.hero.title", bundle: .module)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                // DEL-129: Day-Subtitle via Extension. Hier nur rendern wenn
                // session WIRKLICH einen Day-Bezug hat (entweder live-ref
                // oder Snapshot) — sonst wuerde der generische "Training"-
                // Fallback aus history.session.fallback erscheinen, was im
                // Summary-Hero unschoen wirkt.
                if session.day != nil || session.dayName != nil {
                    Text(session.displayDayName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .onAppear {
                if isReadOnly {
                    // Replay: skip the celebration spring, render final state.
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
                Divider().opacity(0.6)
                HStack(spacing: 0) {
                    SummaryStat(label: String(localized: "active.stats.duration", bundle: .module),
                                value: formattedDuration)
                    statDivider
                    secondarySummaryStat
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("summary.section.stats", bundle: .module)
        }
    }

    /// DEL-137: zweite Sekundaer-Stat-Spalte. Drei-Wege-Branch identisch
    /// zum aktiven `statsCard` in ActiveWorkoutView — selbe UI-Sprache
    /// fuer Live + Replay.
    @ViewBuilder
    private var secondarySummaryStat: some View {
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
                .foregroundStyle(Color.deltiqOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(hero.unitKey, bundle: .module)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Repräsentiert den Hero-Wert + sein Unit-Label (lokalisiert).
    private struct HeroStat {
        let value: String
        let unitKey: LocalizedStringKey
    }

    private var heroStat: HeroStat {
        switch session.sessionCategory {
        case .pureCardio:
            let km = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
            if km > 0 {
                let str = km == km.rounded()
                    ? "\(Int(km))"
                    : km.truncated(to: 2).formattedTwoDecimals
                return HeroStat(value: str, unitKey: "summary.hero.unit.km")
            }
            return HeroStat(value: "\(session.durationMinutes)",
                            unitKey: "summary.hero.unit.minutes")
        case .mixed, .pureStrength:
            return HeroStat(value: formattedVolume, unitKey: "summary.hero.unit.volumeKg")
        }
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
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("summary.note.label", bundle: .module)
                }
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
                .lineLimit(3...8)
            } header: {
                Text("summary.note.label", bundle: .module)
            } footer: {
                Text("summary.note.footer", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var breakdownSections: some View {
        if exercisesWithLogs.isEmpty {
            Section {
                Text("summary.setsEmpty", bundle: .module)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } header: {
                Text("summary.setsHeader", bundle: .module)
            }
        } else {
            ForEach(exercisesWithLogs, id: \.exercise.persistentModelID) { entry in
                exerciseSection(for: entry.exercise, logs: entry.logs)
            }
        }
        // DEL-136 Part C: "+ Übung hinzufügen" Section nur im History-Edit-
        // Mode. Im New-Mode (post-finish) macht das keinen Sinn — User ist
        // gerade fertig und soll nicht zurueck zu mehr Volumen geprompted
        // werden. Tap → ExercisePicker Sheet → onSelect erstellt eine
        // orphan Exercise (day=nil, kein Plan-Polluting) + N Default-Logs.
        if isReadOnly && isEditingHistory {
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
                }
            } footer: {
                Text("summary.addExercise.hint", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    private func exerciseSection(for exercise: Exercise, logs: [ExerciseLog]) -> some View {
        Section {
            // .onDelete only registers when the session is editable — entweder
            // im New-Mode (Post-Finish-Cleanup) oder im History-Edit-Mode
            // (DEL-032: Bearbeiten-Button getoggled).
            let editable = !isReadOnly || isEditingHistory
            if editable {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise, isEditable: isEditingSets)
                }
                .onDelete { offsets in
                    deleteSets(of: exercise, indices: offsets)
                }
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
                                .foregroundStyle(Color.deltiqOrange)
                        }
                        .font(.callout)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise, isEditable: false)
                }
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
            if exercise.isCardio && session.gear == nil {
                if editable {
                    CardioEquipmentPicker(selection: Binding(
                        get: { exercise.cardioEquipment },
                        set: { exercise.cardioEquipment = $0 }
                    ))
                } else if exercise.cardioEquipment != .none {
                    CardioEquipmentDisplayRow(equipment: exercise.cardioEquipment)
                }
            }
        } header: {
            HStack {
                Text(exercise.displayName)
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
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                } else if let best = bestSet(in: logs) {
                    Text("\(String(localized: "summary.exercise.bestPrefix", bundle: .module)): \(formatSetSummary(best, exercise: exercise))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        } footer: {
            Text(formatBreakdownFooter(setsCount: logs.count, volume: formatVolume(logs)))
                .font(.footnote)
        }
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
            Button {
                navigation.returnToDashboard()
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("summary.action.finish", bundle: .module)
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                    .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 6)
                .foregroundStyle(.white)
            }
            .listRowBackground(Color.green)
        } footer: {
            Text("summary.finishFooter", bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: Derived

    /// Logs grouped by exercise, ordered by `Exercise.orderIndex` (matches the plan).
    private var exercisesWithLogs: [(exercise: Exercise, logs: [ExerciseLog])] {
        let grouped = Dictionary(grouping: session.logs) { $0.exercise?.persistentModelID }
        return grouped.compactMap { (_, logs) -> (Exercise, [ExerciseLog])? in
            guard let exercise = logs.first?.exercise else { return nil }
            return (exercise, logs.sorted { $0.setIndex < $1.setIndex })
        }
        .sorted { $0.0.orderIndex < $1.0.orderIndex }
    }

    private var formattedDuration: String {
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
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 32)
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

    private func formatSetSummary(_ log: ExerciseLog, exercise: Exercise) -> String {
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? secUnit : repUnit)"
        }
        if exercise.isTimeBased {
            return "\(log.reps) \(secUnit)"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps)"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
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
                .deltiqIconBadge(tint: kindColor)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-149: Snapshot-resolver — rendert den DE-Base ODER
                // einen vor-DEL-149 unter fremder Locale gespeicherten Namen
                // (z.B. "Koşu Bandı") via Reverse-Lookup in der aktuellen
                // Sprache.
                Text(Exercise.resolvedDisplayName(forStoredName: record.exerciseName))
                    .font(.body.weight(.semibold))
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detailLine)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Spacer()
            // DEL-064: fastestPace ist lower-is-better — die Verbesserung
            // ist ein negativer Delta. Wir zeigen sie als positiv-formatiertes
            // Improvement, sonst sieht der Trophy-Pill aus wie ein Rueckschritt.
            Text(improvementPill)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.Deltiq.success)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    /// DEL-064: kind-aware Improvement-Prozent. Lower-is-better-Kinds
    /// (`.fastestPace`) invertieren den Delta-Vorzug.
    private var improvementPill: String {
        let isLowerBetter: Bool = (record.kind == .fastestPace)
        let raw = record.deltaPercent
        let improvement = isLowerBetter ? -raw : raw
        return "+\(formatDelta(improvement))"
    }

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
        }
    }

    private var kindColor: Color {
        switch record.kind {
        case .estimated1RM:     .orange
        case .heaviestWeight:   .red
        case .bestSet:          .blue
        case .maxReps:          .purple
        case .maxHoldSeconds:   .yellow
        case .longestDistance:  Color.deltiqOrange
        case .fastestPace:      .green
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
            let weightStr = formatWeight(record.weightKg)
            let prevStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.previousValue)) \(volSfx)"
                default:              return "\(formatWeight(record.previousValue)) kg"
                }
            }()
            let nowStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.newValue)) \(volSfx)"
                default:              return "\(formatWeight(record.newValue)) kg"
                }
            }()
            return "\(weightStr) kg × \(record.reps) → \(nowStr) (\(prev) \(prevStr))"

        // DEL-064 Cardio-PRs
        case .longestDistance:
            return "\(formatKm(record.newValue)) km (\(prev) \(formatKm(record.previousValue)) km)"
        case .fastestPace:
            return "\(formatPace(record.newValue)) (\(prev) \(formatPace(record.previousValue)))"
        }
    }

    /// DEL-064: km-Formatter — Integer wenn ganzzahlig, sonst 2 Nachkommastellen.
    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 2).formattedTwoDecimals
    }

    /// DEL-064: Pace-Formatter (min/km Double → "5:42 /km"-String).
    private func formatPace(_ minutesPerKm: Double) -> String {
        guard minutesPerKm.isFinite, minutesPerKm > 0 else { return "—:——" }
        let total = Int((minutesPerKm * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatDelta(_ percent: Double) -> String {
        // Round to nearest %, integer display
        "\(Int((percent * 100).rounded())) %"
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
                .deltiqIconBadge(tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    private var icon: String {
        switch achievement.kind {
        case .weeklyMilestone:           return "flame.fill"
        case .heaviestOfWeek:            return "scalemass.fill"
        case .longestOfWeek:             return "clock.badge.checkmark"
        case .longestDistanceOfWeek:     return "figure.run"
        }
    }

    /// UX-205: Tint-Mapping nutzt Semantic-Color-Tokens — wenn die Palette
    /// jemals shifts, lesen Achievements das automatisch nach.
    private var tint: Color {
        switch achievement.kind {
        case .weeklyMilestone:           return .orange
        case .heaviestOfWeek:            return Color.Deltiq.primary
        case .longestOfWeek:             return Color.Deltiq.info
        case .longestDistanceOfWeek:     return Color.Deltiq.success
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
                .deltiqIconBadge(tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-149: lokalisierter Display-Name via Snapshot-Resolver —
                // outcome.exerciseName ist ein DE-Base-Snapshot aus dem
                // ProgressionApplicator.
                Text(Exercise.resolvedDisplayName(forStoredName: outcome.exerciseName))
                    .font(.body.weight(.semibold))
                Text(headlineText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detailText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Spacer()
            deltaPill
        }
        .padding(.vertical, 4)
        .badgeAppearEffect()   // UX-204: subtiles Spring-In auf Badge-Erscheinen
    }

    private var icon: String {
        switch outcome.action {
        case .increaseWeight: return "arrow.up.right.circle.fill"
        case .deload:         return "arrow.down.right.circle.fill"
        case .hold:           return "minus.circle.fill"   // unreachable
        }
    }

    private var tint: Color {
        switch outcome.action {
        case .increaseWeight: return Color.deltiqOrange
        case .deload:         return .gray
        case .hold:           return .secondary
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
                      formatWeight(newWeight))
    }

    private var deltaPill: some View {
        Text(deltaString)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(outcome.action.weightDelta >= 0 ? Color.deltiqOrange : .secondary)
            .monospacedDigit()
    }

    private var deltaString: String {
        let delta = outcome.action.weightDelta
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
        let absVal = abs(delta)
        let valStr = absVal == absVal.rounded()
            ? "\(Int(absVal))"
            : absVal.truncated(to: 2).formattedTwoDecimals
        return "\(sign)\(valStr) kg"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
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
private struct SetSummaryRow: View {
    @Bindable var log: ExerciseLog
    let exercise: Exercise
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
                .font(.subheadline.weight(.semibold))
                .frame(width: 64, alignment: .leading)

            Text(rowText)
                .font(.callout)
                .monospacedDigit()

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
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                if exercise.isCardio {
                    cardioDistanceField
                    Divider().frame(height: 24)
                    cardioDurationFields
                    Spacer(minLength: 4)
                } else if exercise.isTimeBased {
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
                .font(.title3.monospacedDigit())
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("km").font(.caption2).foregroundStyle(.secondary)
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
                    .font(.title3.monospacedDigit())
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("min").font(.caption2).foregroundStyle(.secondary)
            }
            Text(":")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
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
                    .font(.title3.monospacedDigit())
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("sec").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("kg", value: $log.weight, format: .number)
                .frame(width: 56)
                .multilineTextAlignment(.leading)
                .font(.title3.monospacedDigit())
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("kg").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var repsField: some View {
        // DEL-126: i18n-Sek/Wdh-Labels.
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        let unit = exercise.isTimeBased ? secUnit : repUnit
        return VStack(alignment: .leading, spacing: 2) {
            TextField(unit, value: $log.reps, format: .number)
                .frame(width: 48)
                .multilineTextAlignment(.leading)
                .font(.title3.monospacedDigit())
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// RIR-Block: Label oben, Stepper darunter — kein Overlay-Trick mehr.
    private var rirBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("RIR \(formatRIR(log.rir))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Stepper(value: $log.rir, in: 0...10, step: 0.5) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private var rowText: String {
        if exercise.isCardio {
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
        if exercise.isTimeBased {
            let secUnit = String(localized: "unit.seconds.short", bundle: .module)
            return "\(log.reps) \(secUnit) (RIR \(formatRIR(log.rir)))"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps) (RIR \(formatRIR(log.rir)))"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatRIR(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
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
