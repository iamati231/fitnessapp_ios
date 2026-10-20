#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Edits a single `TrainingDay`: name, weekday, type, intensity, plus the ordered list
/// of exercises. Hosts the "Training starten" action — creates a `WorkoutSession` and
/// navigates straight into `ActiveWorkoutView`.
@available(iOS 17.0, macOS 14.0, *)
public struct DayEditorView: View {

    @Bindable public var day: TrainingDay
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss

    // `editMode` ist auf macOS/watchOS unavailable (SwiftUI.EnvironmentValues.
    // editMode). Das Package deklariert macOS 14 als Mindestversion, damit
    // `swift test` auf dem macOS-CI-Runner baut - eine echte macOS-Deployment
    // dieser View gibt es nicht. Guard reicht daher als reiner Compile-Fix.
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif

    @State private var showingPicker = false
    @State private var exerciseToEdit: Exercise?

    // DEL-048: Bottom-Up Konflikt-Detection. Wenn der User eine Uebung aus
    // dem Picker waehlt, deren Equipment im aktuellen Plan-Env nicht
    // funktioniert (z.B. Beinpresse in einem Bodyweight-Plan), halten wir
    // sie hier zwischen und zeigen einen Confirmation-Dialog.
    @State private var pendingEquipmentConflict: PendingEquipmentConflict?
    @State private var swapResultToast: String?

    private struct PendingEquipmentConflict: Equatable {
        let template: ExerciseTemplate
        let requiredEnv: EnvironmentType   // minimal-fitting env (.gym oder .homeGym)
        let planEnv: EnvironmentType
    }

    /// DEL-042: laeuft eine WorkoutSession noch im Hintergrund (z.B. wegen
    /// App-Crash oder vergessenes Speichern)? Wenn ja, blockiert ein Confirm-
    /// Dialog den Direktstart und gibt dem User drei Optionen.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == false && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var openSessions: [WorkoutSession]

    @State private var showingOpenSessionDialog = false

    /// DEL-238/239: Deload-Automatik + Absenz-Rueckfrage. Gleiche Semantik wie
    /// im Dashboard; der Schalter gated nur die Frage, nie einen laufenden
    /// Deload.
    @AppStorage("pref_deload_enabled") private var deloadEnabled: Bool = true
    @State private var comebackAssessment: AbsenceDeload.Assessment?
    @State private var pendingComebackStart: (() -> Void)?

    /// README 2.35: schuetzt einen Ad-Hoc-Zeitformat-Tag (`day.plan == nil`)
    /// vor `sweepAbandonedAdHocDayIfNeeded()`, sobald `actuallyStartNewSession()`
    /// tatsaechlich eine Session angelegt hat - analog zu
    /// `ActiveWorkoutView.sweepEmptyAdHocSession()`s `!session.isCompleted`-
    /// Check: `.onDisappear` feuert auch dann, wenn dieser Editor nur von
    /// `TimedWorkoutPlayerView` UEBERDECKT (nicht wirklich vom Stack
    /// entfernt) wird - dieses Flag unterscheidet "erfolgreich gestartet"
    /// von "abgebrochen".
    @State private var didStartSessionForAdHocDay = false

    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): Zustand der
    /// `metaSection`-Felder beim Oeffnen — siehe `TrainingDaySnapshot`. Die
    /// Uebungsliste (Hinzufuegen/Loeschen/Reorder/Training starten) bleibt
    /// bewusst ausserhalb: das sind eigene, sofort wirksame Aktionen ohne
    /// Save/Cancel-Konzept, kein Teil dieses "Formulars".
    @State private var snapshot: TrainingDaySnapshot

    /// UI-Refactor (Korrektur V1): `orderIndex` pro Uebung beim Oeffnen, NUR
    /// fuer die Reihenfolge-Erkennung — analog zu `PlanEditorView.
    /// dayWeekdayAtOpen`. `day.activeExercises` ist ueber den direkten
    /// `day`-Init-Parameter (kein `@Query`) schon in `init` verfuegbar.
    /// Intersection-basiert: neu hinzugefuegte/geloeschte Uebungen haben
    /// keinen Eintrag und werden beim Verwerfen nicht angefasst — Hinzufuegen/
    /// Loeschen bleiben eigene, sofort wirksame Aktionen ohne Save/Cancel-
    /// Konzept (siehe `snapshot`-Doc oben).
    @State private var exerciseOrderIndexAtOpen: [PersistentIdentifier: Int]

    public init(day: TrainingDay) {
        self.day = day
        _snapshot = State(initialValue: TrainingDaySnapshot.capture(from: day))
        _exerciseOrderIndexAtOpen = State(initialValue: Dictionary(
            uniqueKeysWithValues: day.activeExercises.map { ($0.persistentModelID, $0.orderIndex) }
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: aus dem Plan-Tab gepusht - "alles im
            // Plan-Tab bekommt tab.plan" (OFFENE-VIEWS.md), auch wenn der
            // unmittelbare Aufrufer PlanEditorView ist.
            DeltiqHeader(
                eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                title: day.name.isEmpty ? String(localized: "day.editor.untitled", bundle: .module) : day.displayName,
                onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                actions: headerActions
            )

            if isRestDay {
                // Ruhetag bekommt eine drastisch reduzierte Layout-Variante
                // (DEL-015) — keine Picker, keine Übungen-Section, nur Hero-
                // Icon + Skip-Button. Vermeidet die irritierenden "0 Übungen"-
                // und "Intensität: Keine"-Eintraege.
                restDayLayout
            } else {
                // Signature-Geruest: `List` bleibt Container - .onMove/.onDelete
                // fuer die Uebungs-Reihenfolge sowie die Superset-Swipe-Action
                // brauchen ihn (siehe PlanEditorView/WorkoutSummaryView, gleiches
                // Prinzip). .scrollContentBackground(.hidden) + .listRowBackground
                // je Zeile machen daraus optisch eine Deltiq-Karten-Reihe.
                List {
                    metaSection
                    startSection
                    exercisesSection
                    // DEL-142: Tagesanalyse-Card UNTER der Übungs-Liste.
                    // Empty-State wenn keine Übungen, sonst die berechnete
                    // Analyse aus dem `DayAnalyzer`. SwiftUI re-evaluiert
                    // `dayAnalysisSection` bei jeder Re-Render-Pass des
                    // Forms — sobald der User Übungen mutate (add/remove,
                    // sets/reps-changes via Editor), kommt die nächste
                    // Pass mit aktualisierten Werten.
                    dayAnalysisSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        // UI-Refactor (Korrektur, Punkt 4): bei Aenderungen bleibt die Geste
        // bewusst AUS — die Wisch-Geste ist sonst ein ungesicherter
        // Verlassen-Weg, der am Discard-Dialog vorbeigeht. Ohne Aenderungen
        // (`!isDirty`) funktioniert sie weiter normal (direktes Schliessen).
        .deltiqSwipeBackEnabled(!isDirty)
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            revertToSnapshot()
        }
        .sheet(isPresented: $showingPicker) {
            // DEL-210: einheitliche Übungs-Auswahl — dieselbe View wie die
            // Bibliothek unter Einstellungen, im Picker-Modus.
            ExerciseLibraryPickerSheet(
                planEnvironment: day.plan?.targetEnvironment,
                onSelect: { template in handleExerciseSelection(template) },
                onCreateCustom: { draft in addCustomExercise(draft) }
            )
        }
        // DEL-048: Equipment-Konflikt-Confirmation. Wenn der User mit Filter
        // OFF eine inkompatible Uebung gewaehlt hat, fragen wir hier nach.
        .confirmationDialog(
            Text("day.editor.equipmentConflict.title", bundle: .module),
            isPresented: Binding(
                get: { pendingEquipmentConflict != nil },
                set: { if !$0 { pendingEquipmentConflict = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEquipmentConflict
        ) { conflict in
            // Option A: Plan-Env auf Gym/Home umstellen UND Uebung adden.
            Button(String(format: String(localized: "day.editor.equipmentConflict.switchPlan", bundle: .module), environmentLabel(conflict.requiredEnv))) {
                switchPlanEnvAndAdd(conflict: conflict)
                pendingEquipmentConflict = nil
            }
            // Option B: Trotzdem adden, Plan-Env unveraendert lassen. Die
            // Uebung wird vermutlich beim ersten Workout-Start als "kein
            // Equipment vorhanden" stossen, aber der User hat die freie Wahl.
            Button {
                addExercise(from: conflict.template)
                pendingEquipmentConflict = nil
            } label: {
                Text("day.editor.equipmentConflict.justAdd", bundle: .module)
            }
            Button(role: .cancel) {
                pendingEquipmentConflict = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { conflict in
            let template = String(localized: "day.editor.equipmentConflict.message", bundle: .module)
            Text(template
                .replacingOccurrences(of: "%1$@", with: conflict.template.name)
                .replacingOccurrences(of: "%2$@", with: environmentLabel(conflict.planEnv)))
        }
        .overlay(alignment: .bottom) {
            if let msg = swapResultToast {
                Label(msg, systemImage: "arrow.triangle.2.circlepath")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $exerciseToEdit) { exercise in
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
        // DEL-239: Absenz-Deload-Rueckfrage (siehe `actuallyStartNewSession`).
        .sheet(item: $comebackAssessment) { assessment in
            ComebackPromptSheet(assessment: assessment) { factor in
                let pending = comebackAssessment
                comebackAssessment = nil
                if let factor {
                    // Fehler geschluckt: ein fehlgeschlagener Schreibvorgang
                    // darf den Start nicht blockieren — dann trainiert der
                    // Nutzer mit unveraenderten Gewichten weiter.
                    try? AbsenceDeload.apply(in: modelContext, factor: factor)
                } else if let pending {
                    AbsenceDeload.remember(declinedAtGapDays: pending.gapDays)
                }
                let start = pendingComebackStart
                pendingComebackStart = nil
                start?()
            }
        }
        // DEL-042: Open-Session-Recovery-Dialog. Triggered von startSession()
        // wenn eine ungespeicherte Session existiert. Drei Optionen plus Cancel.
        .confirmationDialog(
            Text("plans.active.title", bundle: .module),
            isPresented: $showingOpenSessionDialog,
            titleVisibility: .visible
        ) {
            Button { resumeOpenSession() } label: {
                Text("session.recovery.resume", bundle: .module)
            }
            Button { completeOpenSessionAndStartNew() } label: {
                Text("session.recovery.saveAndRestart", bundle: .module)
            }
            Button(role: .destructive) { discardOpenSessionAndStartNew() } label: {
                Text("session.recovery.discardAndRestart", bundle: .module)
            }
            Button(role: .cancel) { } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            if let open = openSessions.first {
                // DEL-129: displayDayName liefert hier den lokalisierten
                // Day-Title, sodass der Recovery-Dialog im EN/TR-Mode den
                // richtigen Namen statt eines stale DE-Snapshots zeigt.
                let dayName = (open.day != nil || open.dayName != nil)
                    ? open.displayDayName
                    : String(localized: "session.recovery.dayName.unknown", bundle: .module)
                let stamp = open.startTime.formatted(.relative(presentation: .named))
                let template = String(localized: "session.recovery.message.withInfo", bundle: .module)
                Text(template
                    .replacingOccurrences(of: "%1$@", with: dayName)
                    .replacingOccurrences(of: "%2$@", with: stamp))
            } else {
                Text("session.recovery.message.fallback", bundle: .module)
            }
        }
        // Nutzer-Feedback (README 2.35): der Ad-Hoc-Zeitformat-Start
        // (`DashboardView.beginTimedAdHocWorkout`) legt den Tag OHNE Session
        // an und navigiert direkt hierher - anders als jeder bisherige Weg
        // zu diesem Editor (immer ein bereits bestehender Plan-Tag).
        // Verlaesst der User diesen Editor, BEVOR "Training starten"
        // erfolgreich lief (Zurueck-Chevron, Swipe-Back, App-Beendigung),
        // bliebe der eingefuegte Tag sonst fuer immer verwaist im Store - er
        // taucht in keiner PlansListView/keinem PlanEditor auf, es gibt
        // keinen anderen Weg zurueck zu ihm. Gleiches Muster wie
        // `ActiveWorkoutView.sweepEmptyAdHocSession()`.
        .onDisappear {
            sweepAbandonedAdHocDayIfNeeded()
        }
    }

    /// UI-Refactor (Korrektur): der Save-Checkmark muss auf jedem
    /// bearbeitbaren Formular immer ganz rechts erreichbar sein — er darf
    /// weder durch den 2-Action-Cap von `DeltiqHeader` verdraengt werden
    /// noch (waehrend des Reorder-Modus) dasselbe Icon/dieselbe Position
    /// wie ein "Reorder fertig"-Haekchen teilen (eindeutige Bedeutung,
    /// stabile Position). Deshalb wandert der bisherige Top-Level-Reorder-
    /// Toggle (DEL-095, Ersatz fuer EditButton()) in ein Ellipsis-Menu —
    /// Start UND Ende des Reorder-Modus sind beides Menu-Eintraege, nie der
    /// Save-Slot selbst. `saveAction` ist dadurch immer genau 1 der
    /// hoechstens 2 Actions und immer die LETZTE (= am weitesten rechts,
    /// `ForEach(actions)` rendert in Array-Reihenfolge, siehe Theme.swift).
    private var headerActions: [DeltiqHeaderAction] {
        var actions: [DeltiqHeaderAction] = []
        #if os(iOS)
        if !isReadOnly, !day.activeExercises.isEmpty, !isRestDay {
            actions.append(reorderMenuAction)
        }
        #endif
        actions.append(saveAction)
        return actions
    }

    #if os(iOS)
    /// UI-Refactor (Korrektur): Reorder-Start/-Ende als EIN stabiler
    /// Ellipsis-Menu-Eintrag statt eines eigenen Top-Level-Icons — das
    /// Menu selbst traegt immer dasselbe `"ellipsis"`-Icon (Konvention
    /// dieses Repos, siehe z.B. `WorkoutSummaryView`/`PRHistoryView`),
    /// nur der Eintrag darin wechselt Label/Icon je nach `editMode`.
    private var reorderMenuAction: DeltiqHeaderAction {
        let isEditing = editMode?.wrappedValue.isEditing == true
        return DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button {
                withAnimation {
                    editMode?.wrappedValue = isEditing ? .inactive : .active
                }
            } label: {
                Label {
                    Text(isEditing
                         ? "editor.reorder.done"
                         : "editor.reorder.start",
                         bundle: .module)
                } icon: {
                    Image(systemName: isEditing ? "checkmark" : "arrow.up.arrow.down")
                }
            }
        })
    }
    #endif

    /// UI-Refactor (DeltiqHeader-Muster): Autosave-Screen (siehe
    /// `ExerciseEditorView`). Kein Validitaets-Gate auf diesem Screen → kein
    /// `isDisabled`. Ruft seit dem Day-Editor-Persistenzbugfix `saveAndDismiss()`
    /// auf (siehe dortige Dokumentation) — vorher war das ein reines "Fertig"
    /// ohne eigenen Speicher-Schritt.
    private var saveAction: DeltiqHeaderAction {
        DeltiqHeaderAction(
            systemImage: "checkmark",
            accessibilityLabel: String(localized: "common.done", bundle: .module)
        ) {
            saveAndDismiss()
        }
    }

    /// Bugfix (Day-Editor-Persistenzbug, Tag-Level-Stepper/Picker): die
    /// `metaSection`-Felder (u.a. `timeFormat`/`circuitRounds`/
    /// `circuitRestSeconds`, siehe `TrainingDaySnapshot`) galten laut
    /// Typ-Doku als "autosaved direkt in SwiftData" ueber `@Bindable` —
    /// tatsaechlich mutiert `@Bindable` nur den LIVE-Objektgraphen im
    /// Speicher, ohne selbst `context.save()` aufzurufen. Ein reines
    /// `dismiss()` verliess sich bislang komplett auf SwiftDatas impliziten
    /// Autosave, der nach einem direkt anschliessenden App-Kaltstart nicht
    /// zuverlaessig schon gelaufen sein muss (derselbe Musterfehler wie bei
    /// `deleteExercises`, siehe dortige Dokumentation). Ein fehlgeschlagener
    /// Save dismisst jetzt NICHT mehr — der User soll nicht glauben, seine
    /// Aenderung sei gesichert, waehrend sie es nicht ist (sichtbarer
    /// Fehlerhinweis statt irrefuehrendem "Fertig").
    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            showTransientToast(String(localized: "day.editor.save.failed", bundle: .module))
        }
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

    /// Hero-Card-Layout fuer Ruhetage: grosses Sofa-Icon, klare Botschaft,
    /// prominenter "Abschliessen"-Button. Versteckt alle Editor-Metadaten,
    /// die fuer einen "Tag-ohne-Training" sinnlos sind.
    @ViewBuilder
    private var restDayLayout: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 96))
                .foregroundStyle(.white)
                .frame(width: 140, height: 140)
                .background(Color.deltiqOrange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 8) {
                Text(day.name.isEmpty ? String(localized: "day.restDay.title", bundle: .module) : day.displayName)
                    .font(.title.weight(.bold))
                Text("day.restDay.heroMessage", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                markRestDaySkipped()
            } label: {
                Label {
                    Text("day.restDay.complete.button", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sections

    /// True wenn der Tag aus einem Template-basierten Plan stammt
    /// (`plan.isTemplate`). Editor-Felder werden dann disabled um die
    /// kuratierte Library-Struktur nicht versehentlich zu zerschiessen.
    /// Custom-Plaene bleiben editierbar (DEL-013-Fix).
    private var isReadOnly: Bool {
        day.plan?.isTemplate ?? false
    }

    /// True nur wenn der Tag explizit als `.rest` markiert ist. Frueher
    /// haben wir `exercises.isEmpty` als Fallback genommen, was leere Tage
    /// faelschlich als Ruhetag detektierte — User konnte gar keinen
    /// Trainingstag mehr anlegen. Jetzt strikt nach Typ (DEL-021/023).
    private var isRestDay: Bool {
        day.type == .rest
    }

    /// UI-Refactor (DeltiqHeader-Muster): Vergleich gegen `TrainingDaySnapshot`
    /// vom Oeffnen des Sheets — nur die `metaSection`-Felder, siehe dort. Plus
    /// (Korrektur V1) die Uebungs-Reihenfolge, die ein reiner Feld-Vergleich
    /// nicht sieht.
    private var isDirty: Bool {
        snapshot != TrainingDaySnapshot.capture(from: day) || isExerciseOrderDirty
    }

    /// UI-Refactor (Korrektur V1): true, wenn mindestens eine beim Oeffnen
    /// vorhandene Uebung seitdem einen anderen `orderIndex` bekommen hat
    /// (Drag&Drop-Reorder, siehe `moveExercises`). Neue/geloeschte Uebungen
    /// zaehlen bewusst nicht mit (siehe `exerciseOrderIndexAtOpen`-Doc).
    /// Live-Property reicht nur `exerciseOrderIndexAtOpen` durch — die
    /// eigentliche Pruefung steckt in der `internal` Funktion darunter, die
    /// ohne `@State`-Zugriff direkt testbar ist (siehe Tests/FitnessAppUITests).
    private var isExerciseOrderDirty: Bool {
        exerciseOrderIsDirty(comparedTo: exerciseOrderIndexAtOpen)
    }

    /// UI-Refactor (Korrektur V1): reine Pruef-Logik mit explizitem
    /// `orderIndexAtOpen`-Parameter statt direktem `@State`-Zugriff — testbar
    /// ohne lebende SwiftUI-Umgebung. Bewusst NICHT `isExerciseOrderDirty`
    /// genannt (anderer Name als die Property direkt darueber), um jede
    /// Zweideutigkeit zwischen Property- und Funktionsreferenz zu vermeiden.
    internal func exerciseOrderIsDirty(comparedTo orderIndexAtOpen: [PersistentIdentifier: Int]) -> Bool {
        day.activeExercises.contains { exercise in
            guard let original = orderIndexAtOpen[exercise.persistentModelID] else { return false }
            return original != exercise.orderIndex
        }
    }

    private var metaSection: some View {
        Section {
            // DEL-125: customName + localizedSystemName-Placeholder.
            TextField(
                text: Binding(
                    get: { day.customName ?? "" },
                    set: { day.customName = $0.isEmpty ? nil : $0 }
                ),
                prompt: Text(day.localizedSystemName)
            ) {
                Text("day.editor.field.name", bundle: .module)
            }
                .disabled(isReadOnly)
                .listRowBackground(Color.Deltiq.surface)

            Picker(selection: $day.weekday) {
                ForEach(weekdayOptions, id: \.self) { weekday in
                    Text(weekdayName(weekday)).tag(weekday)
                }
            } label: {
                Text("day.editor.field.weekday", bundle: .module)
            }
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)

            Picker(selection: $day.type) {
                ForEach(DayType.allCases, id: \.self) { type in
                    Text(typeLabel(type)).tag(type)
                }
            } label: {
                Text("day.editor.field.type", bundle: .module)
            }
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)

            Picker(selection: $day.nextIntensity) {
                Text("day_intensity.light", bundle: .module).tag(DayIntensity.light)
                Text("day_intensity.normal", bundle: .module).tag(DayIntensity.normal)
                Text("day_intensity.heavy", bundle: .module).tag(DayIntensity.heavy)
            } label: {
                Text("day.editor.field.nextIntensity", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)

            // README 2.35 (43a): eigene Trainings konnten `timeFormat` bisher
            // gar nicht setzen - nur die kuratierten Templates (Cindy,
            // CrossFit/Kettlebell) tragen es. Gleiches Picker-Muster wie Typ/
            // Intensitaet direkt darueber, inklusive derselben (in der Praxis
            // wirkungslosen) `isReadOnly`-Sperre: `day.plan?.isTemplate` ist
            // seit `ProgramInstantiator.instantiate` durchgehend `false`,
            // auch fuer adoptierte kuratierte Plaene (siehe `isReadOnly`-
            // Kommentar in `PlanEditorView.swift`) - kein neues Problem
            // dieses Pickers, nur keine echte Sperre, obwohl der Name das
            // suggeriert. Die Dauer-/Zeit-Deckel-Zeile direkt darunter
            // reagiert bereits automatisch auf `day.timeFormat`.
            Picker(selection: $day.timeFormat) {
                Text("day.editor.field.structure.sets", bundle: .module).tag(nil as WorkoutTimeFormat?)
                // Paket 2: `.enduranceIntervals` bewusst NICHT hier anbieten
                // - dieser Editor hat noch keine Eingabefelder fuer
                // Einlauf-/Auslaufdauer, Rundenzahl, Belastungs-/Erholungs-
                // ziel. Erst anbieten, wenn die zugehoerige Konfigurations-
                // UI existiert (naechster Paket-2-Schritt), sonst waere das
                // Ergebnis ein Tag mit gesetztem Format, aber ohne jede
                // Konfiguration.
                ForEach(WorkoutTimeFormat.allCases.filter { $0 != .enduranceIntervals }, id: \.self) { format in
                    Text(timedFormatDisplayName(format)).tag(format as WorkoutTimeFormat?)
                }
            } label: {
                Text("day.editor.field.structure", bundle: .module)
            }
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)

            // Feature (Dauer/Time-Cap konfigurierbar): AMRAP/EMOM brauchen
            // eine feste Dauer fuer den Countdown, Auf Zeit dagegen nur ein
            // OPTIONALES Abbruch-Cap (0 = kein Limit, der bisherige
            // Bestandsfall fuer alle bisherigen Auf-Zeit-Tage).
            if let format = day.timeFormat {
                switch format {
                case .amrap, .emom:
                    Stepper(value: Binding(
                        get: { day.timeCapMinutes ?? defaultTimedFormatDurationMinutes(for: format) },
                        set: { day.timeCapMinutes = $0 }
                    ), in: 5...60) {
                        LabeledContent {
                            Text("\(day.timeCapMinutes ?? defaultTimedFormatDurationMinutes(for: format)) " + String(localized: "unit.minutes.short", bundle: .module))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        } label: {
                            Text("day.editor.field.duration", bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    .listRowBackground(Color.Deltiq.surface)
                case .forTime:
                    Stepper(value: Binding(
                        get: { day.timeCapMinutes ?? 0 },
                        set: { day.timeCapMinutes = $0 > 0 ? $0 : nil }
                    ), in: 0...60, step: 5) {
                        LabeledContent {
                            Text(day.timeCapMinutes.map { "\($0) " + String(localized: "unit.minutes.short", bundle: .module) }
                                ?? String(localized: "day.editor.field.timeCap.noLimit", bundle: .module))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        } label: {
                            Text("day.editor.field.timeCap", bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    .listRowBackground(Color.Deltiq.surface)
                case .circuit:
                    // Zirkel hat kein Minuten-Dauer-Konzept - stattdessen
                    // Rundenzahl, Pause zwischen den Runden, und der Modus
                    // (feste Wdh. je Runde vs. bis zur Ausbelastung).
                    Stepper(value: Binding(
                        get: { day.circuitRounds ?? defaultCircuitRounds() },
                        set: { day.circuitRounds = $0 }
                    ), in: 1...20) {
                        LabeledContent {
                            Text("\(day.circuitRounds ?? defaultCircuitRounds())")
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        } label: {
                            Text("day.editor.field.circuitRounds", bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    .listRowBackground(Color.Deltiq.surface)

                    Stepper(value: Binding(
                        get: { day.circuitRestSeconds ?? defaultCircuitRestSeconds() },
                        set: { day.circuitRestSeconds = $0 }
                    ), in: 10...300, step: 5) {
                        LabeledContent {
                            Text("\(day.circuitRestSeconds ?? defaultCircuitRestSeconds())" + String(localized: "unit.seconds.short", bundle: .module))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        } label: {
                            Text("day.editor.field.circuitRest", bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    .listRowBackground(Color.Deltiq.surface)

                    Picker(selection: Binding(
                        get: { day.circuitMode ?? .fixedReps },
                        set: { day.circuitMode = $0 }
                    )) {
                        Text("day.editor.field.circuitMode.fixedReps", bundle: .module).tag(CircuitRoundMode.fixedReps)
                        Text("day.editor.field.circuitMode.toFailure", bundle: .module).tag(CircuitRoundMode.toFailure)
                    } label: {
                        Text("day.editor.field.circuitMode", bundle: .module)
                    }
                    .disabled(isReadOnly)
                    .listRowBackground(Color.Deltiq.surface)
                case .enduranceIntervals:
                    // Paket 2: strukturell unerreichbar - der Picker oben
                    // bietet dieses Format bewusst nicht an (siehe dortiger
                    // Kommentar), solange keine Konfigurations-UI existiert.
                    EmptyView()
                }
            }
        } header: {
            sectionHeader(String(localized: "day.editor.section.info", bundle: .module))
        } footer: {
            if isReadOnly {
                Text("day.editor.templateLocked.footer", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    @ViewBuilder
    private var startSection: some View {
        if isRestDay {
            Section {
                Button {
                    markRestDaySkipped()
                } label: {
                    HStack {
                        Spacer()
                        Label {
                            Text("day.restDay.complete.button", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                            .font(.headline)
                        Spacer()
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            } footer: {
                Text("day.restDay.complete.footer", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        } else {
            // DEL-127: Adaptive Start-CTA. Wenn fuer diesen Day bereits eine
            // offene Session existiert (App-Crash, vergessenes Speichern,
            // oder User hat das Workout abgebrochen ohne zu finishen), zeigen
            // wir "Training fortsetzen" statt "Training starten" — analog zum
            // DashboardView-PlanDayCard-Pattern. Klick fuehrt direkt in die
            // bestehende Session, ohne Recovery-Dialog.
            adaptiveStartSection
        }
    }

    /// DEL-127: ausgelagerter Builder fuer den adaptiven Start-CTA. Wird in
    /// eine eigene @ViewBuilder-Property gezogen, damit das `let openForThisDay`
    /// nicht in einem if-else-Branch der parent-ViewBuilder steht (Swift-5.9-
    /// ResultBuilder-Quirk — Bindings innerhalb verschachtelter Branches
    /// koennen je nach Build-Konfiguration zicken).
    @ViewBuilder
    private var adaptiveStartSection: some View {
        let openForThisDay = openSessionForCurrentDay
        Section {
            // Handoff 1.9: Primaerer Hero-CTA statt gruen-hinterlegter Row -
            // .deltiqButtonStyle() bringt Gradient/Glow/Rundung schon mit,
            // listRowBackground/-Insets werden geleert, damit Listens eigenes
            // Zeilen-Chrome die Button-Optik nicht doppelt umrahmt.
            Button {
                // UX-204: Medium-Impact-Haptik — der "Training starten"-
                // Klick ist ein bewusster Commitment-Schritt, das verdient
                // ein satteres haptisches Feedback als ein Set-Tap.
                DeltiqHaptics.impact(.medium)
                if let open = openForThisDay {
                    resumeOpenSession(open)
                } else {
                    startSession()
                }
            } label: {
                Label {
                    Text(openForThisDay != nil
                         ? "day.editor.start.resume"
                         : "day.editor.start.button",
                         bundle: .module)
                } icon: {
                    Image(systemName: openForThisDay != nil
                        ? "play.circle.fill"
                        : "play.fill")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .disabled(day.activeExercises.isEmpty)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            if day.activeExercises.isEmpty {
                Text("day.editor.start.hintEmpty", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            } else if openForThisDay != nil {
                Text("day.editor.start.resumeHint", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// DEL-127: liefert die offene Session, deren `.day` mit dem aktuell
    /// editierten Tag uebereinstimmt. Wenn nil → kein Resume-Pfad,
    /// regulaerer Start-Button wird gerendert.
    private var openSessionForCurrentDay: WorkoutSession? {
        openSessions.first { $0.day?.persistentModelID == day.persistentModelID }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        Section {
            if day.activeExercises.isEmpty {
                Text(isRestDay
                     ? "day.editor.exercises.restDayEmpty"
                     : "day.editor.exercises.empty",
                     bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .font(.callout)
                    .listRowBackground(Color.Deltiq.surface)
            } else if isReadOnly {
                // Template — Reorder/Delete deaktiviert. Einzelne Übung tappen
                // führt weiterhin in den ExerciseEditor (der seinerseits read-
                // only ist und nur die Trainings-Parameter sichtbar macht).
                ForEach(orderedExercises) { exercise in
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.Deltiq.surface)
                }
            } else {
                ForEach(Array(orderedExercises.enumerated()), id: \.element.forEachIdentity) { idx, exercise in
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        ExerciseRow(exercise: exercise, isInSuperset: exercise.supersetId != nil)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.Deltiq.surface)
                    // DEL-083: Swipe-Action "Mit oberer verbinden" / "Trennen".
                    // Nur sinnvoll ab Index 1 (es muss eine Uebung darueber
                    // existieren). Toggle-Verhalten: angeklickt → verbinden,
                    // erneut angeklickt → wieder aus Superset rausnehmen.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if idx > 0 {
                            Button {
                                toggleSupersetWithPrevious(at: idx)
                            } label: {
                                Label {
                                    Text(exercise.supersetId == nil
                                         ? "day.editor.superset.link"
                                         : "day.editor.superset.unlink",
                                         bundle: .module)
                                } icon: {
                                    Image(systemName: exercise.supersetId == nil
                                        ? "link"
                                        : "link.badge.plus")
                                }
                            }
                            .tint(Color.deltiqOrange)
                        }
                    }
                }
                .onMove(perform: moveExercises)
                .onDelete(perform: deleteExercises)
            }
        } header: {
            HStack {
                sectionHeader(String(localized: "day.editor.section.exercises", bundle: .module))
                // README 2.10/19c-19d: Format + Deckel als neutrale Kapsel
                // neben dem Section-Header, statt dass die Zeilen darunter
                // eine erfundene Pausen-Angabe zeigen.
                if let format = day.timeFormat {
                    DeltiqPill(timedFormatPillText(format), style: .neutral)
                }
                Spacer()
                if !isReadOnly {
                    Button {
                        showingPicker = true
                    } label: {
                        Label {
                            Text("common.add", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                            .labelStyle(.iconOnly)
                    }
                    .foregroundStyle(Color.deltiqOrange)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                // README 2.10/19c-19d: ersetzt die (bei Zeitformaten
                // erfundene) Pausen-Angabe durch einen ehrlichen Fusshinweis.
                if let format = day.timeFormat {
                    Text(String(localized: String.LocalizationValue(timedFormatHintKey(for: format)), bundle: .module))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                if isReadOnly {
                    Text("day.editor.templateLocked.exercises", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                } else if !day.activeExercises.isEmpty {
                    Text("day.editor.exercises.editHint", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: - DEL-142 Tagesanalyse

    /// Form-Section um die `DayAnalysisCard`. Drei Branches:
    ///   * Übungs-Liste leer → `.empty`-Card mit Hint
    ///   * `DayAnalyzer.analyze(...)` liefert nil (Edge-Case, wenn alle
    ///     Übungen archived oder Warmup/Cooldown) → ebenfalls `.empty`
    ///   * Sonst → `.analysis(...)`-Card mit den berechneten Werten
    ///
    /// Section-Header bleibt leer — die Card hat ihren eigenen Header
    /// mit Icon + Titel. listRowInsets removed so the Bento-Card-Look
    /// dasselbe Padding-System hat wie auf dem Dashboard.
    ///
    /// README 2.13 (hebt README 2.10/19f auf): `DayAnalyzer` rechnet fuer
    /// Zeitformat-Tage aus der Dauer statt aus Saetzen × Wdh × Pause - die
    /// Karte war deshalb frueher fuer diese Tage komplett unterdrueckt
    /// (falsche Aussage schlimmer als keine), das ist mit der dauer-
    /// basierten Berechnung nicht mehr noetig.
    @ViewBuilder
    private var dayAnalysisSection: some View {
        Section {
            let exercises = day.activeExercises
            let analysis = DayAnalyzer.analyze(
                exercises: exercises,
                timeFormat: day.timeFormat,
                timeCapMinutes: day.timeCapMinutes,
                circuitRounds: day.circuitRounds,
                circuitRestSeconds: day.circuitRestSeconds
            )

            if let analysis {
                DayAnalysisCard(mode: .analysis(analysis))
            } else {
                DayAnalysisCard(mode: .empty)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    // MARK: Derived

    /// DEL-049: archivierte Snapshots (Urlaubs-Modus) sind aus der UI raus —
    /// nur aktive Uebungen anzeigen + sortieren.
    private var orderedExercises: [Exercise] {
        day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var weekdayOptions: [Int] {
        // 2..7,1 puts Monday first and Sunday last for European users.
        [2, 3, 4, 5, 6, 7, 1]
    }

    // MARK: Actions

    /// DEL-048: Entry-Point fuer eine Picker-Auswahl. Checked, ob das
    /// Template-Equipment zum aktuellen Plan-Env passt. Bei Konflikt wird
    /// statt sofortigem Insert der Confirmation-Dialog aufgemacht.
    /// Custom-Templates werden NIE als Konflikt gewertet — der User hat sie
    /// bewusst angelegt.
    private func handleExerciseSelection(_ template: ExerciseTemplate) {
        guard let planEnv = day.plan?.targetEnvironment,
              !template.isCustom,
              !ExerciseLibraryData.isEquipment(template.equipment, compatibleWith: planEnv)
        else {
            addExercise(from: template)
            return
        }
        // Konflikt: schlage das minimal-passende Env vor (homeGym fuer KH/KB/
        // Band, Gym fuer Maschinen/Kabel/LH).
        let required = minimumEnvironment(for: template.equipment)
        pendingEquipmentConflict = PendingEquipmentConflict(
            template: template,
            requiredEnv: required,
            planEnv: planEnv
        )
    }

    /// DEL-048: Mappt Equipment auf das niedrigst-passende Env, das der User
    /// braucht, um die Uebung sinnvoll auszufuehren. Dumbbells/Kettlebells/
    /// Bands gehen schon in HomeGym; Barbell/Machine/Cable brauchen Gym.
    private func minimumEnvironment(for equipment: Equipment) -> EnvironmentType {
        switch equipment {
        case .bodyweight:                                return .noEquipment
        case .dumbbell, .kettlebell, .band:              return .homeGym
        case .barbell, .machine, .cable:                 return .gym
        }
    }

    /// DEL-048: User waehlt "Plan umstellen". Wir setzen das neue Env auf
    /// dem Plan UND lassen den `PlanEnvironmentMigrator` ueber die bereits
    /// vorhandenen Uebungen drueberlaufen (damit z.B. eine KH-Variante nicht
    /// neben einer auf einmal hinfaelligen BW-Variante stehen bleibt). Dann
    /// adden wir die ausloesende Uebung als ganz normale neue Exercise.
    private func switchPlanEnvAndAdd(conflict: PendingEquipmentConflict) {
        guard let plan = day.plan else {
            addExercise(from: conflict.template)
            return
        }
        plan.targetEnvironment = conflict.requiredEnv
        let r = PlanEnvironmentMigrator.migrate(
            plan: plan,
            toEnvironment: conflict.requiredEnv,
            modelContext: modelContext
        )
        // Eigentliche neue Uebung adden (NACH dem Migrator, sonst wird sie
        // selber gleich umsortiert/ersetzt).
        addExercise(from: conflict.template)

        // Toast
        var parts: [String] = []
        parts.append("Plan auf \(environmentLabel(conflict.requiredEnv))")
        if r.swapped > 0 { parts.append("\(r.swapped) ersetzt") }
        let message = parts.joined(separator: " · ")
        withAnimation(.easeOut(duration: 0.2)) {
            swapResultToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                swapResultToast = nil
            }
        }
    }

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }

    /// DEL-083: Verbindet die Uebung an `idx` mit der direkt darueber zum
    /// Superset. Beide bekommen die selbe `supersetId`. Wenn die obere
    /// bereits in einem Superset ist, schliessen wir uns dem an statt einen
    /// neuen anzulegen. Erneuter Aufruf → loest die Verbindung.
    private func toggleSupersetWithPrevious(at idx: Int) {
        let arr = orderedExercises
        guard idx > 0, idx < arr.count else { return }
        let current = arr[idx]
        let previous = arr[idx - 1]

        if current.supersetId != nil {
            // Trennen: Wenn current als einziger Teil ihrer Gruppe bleibt
            // (gruppe-size <= 2 nach dem entfernen), nullen wir auch den
            // verbleibenden Partner — denn ein "Superset of 1" macht
            // semantisch keinen Sinn.
            let id = current.supersetId!
            current.supersetId = nil
            let remaining = arr.filter { $0.supersetId == id }
            if remaining.count <= 1 {
                remaining.forEach { $0.supersetId = nil }
            }
        } else {
            // Verbinden: gleicher supersetId wie previous (entweder dessen
            // existierende ID oder eine neu erstellte).
            let id = previous.supersetId ?? UUID()
            previous.supersetId = id
            current.supersetId = id
        }
    }

    private func addExercise(from template: ExerciseTemplate) {
        // DEL-149: NUR der deutsche Library-Base-Name landet in
        // `Exercise.name`. Frueher (DEL-111) wurde hier `template.displayName`
        // genommen — das fror die aktuelle Locale ein und produzierte
        // Eintraege wie "Koşu Bandı"/"Treadmill" in der DB, die nach einem
        // Sprachwechsel falsch gerendert wurden. Der DE-Base ist der stabile
        // Library-Anchor; die UI-Sicht macht den Lookup ueber
        // `displayName` (Extension) wieder lokalisiert.
        let exercise = Exercise(
            name: template.name,
            // Settings-Epic Phase 6 (EXLIB-07/09): stabile Rueckreferenz,
            // ueberlebt ein spaeteres Umbenennen der Vorlage.
            exerciseTemplateID: template.id,
            // DEL-157: Cardio- + Time-Based-Uebungen starten mit genau 1 Satz
            // (eine Distanz-/Dauer- bzw. Halte-Zeile). Die Standard-3-Saetze
            // ergeben fuer einen Lauf/Plank keinen Sinn. Strength bleibt 3.
            sets: (template.isCardio || template.isTimeBased) ? 1 : 3,
            orderIndex: day.activeExercises.count,
            // DEL-080: Cardio-Flag aus dem Library-Template propagieren.
            // Picker-Pick einer Cardio-Uebung (z.B. "Freier Lauf") soll
            // direkt mit `isCardio = true` im Plan landen — sonst kriegt
            // der User die falsche SetRow-UI.
            isCardio: template.isCardio,
            isTimeBased: template.isTimeBased,
            // DEL-053: Compound-Flag aus dem Library-Template ziehen. Die
            // 5 kanonischen Barbell-Lifts werden als Compound markiert,
            // alles andere als Isolation. User kann's spaeter im
            // ExerciseEditor manuell ueberschreiben.
            isCompound: template.isSystemCompound,
            // DEL-098: Belastungsfaktoren aus dem Library-Template ziehen,
            // damit Recovery-/Fatigue-Scoring schon ab dem ersten Workout
            // mit den richtigen Werten rechnet.
            systemicFatigueFactor: template.systemicFatigueFactor,
            localMuscleDamageFactor: template.localMuscleDamageFactor,
            cnsDemandFactor: template.cnsDemandFactor,
            axialLoadFactor: template.axialLoadFactor,
            technicalComplexityFactor: template.technicalComplexityFactor,
            recoveryClass: template.recoveryClass,
            // DEL-163: Muskel + Equipment vom Template uebernehmen. Vorher
            // gingen diese beim Adopt verloren (Exercise fiel im Editor auf
            // Brust/Koerpergewicht zurueck), weil nur isCompound + Faktoren
            // kopiert wurden. Gilt fuer Custom- UND System-Templates.
            primaryMuscle: template.primaryMuscle,
            equipment: template.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    private func addCustomExercise(_ draft: CustomExerciseDraft) {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Persist as a custom template too — the exercise reappears in the picker
        // next time so the user doesn't have to retype it.
        // DEL-159: Metadaten aus dem Erstell-Sheet (Muskel/Equipment/Compound)
        // statt neutraler Defaults — Picker zeigt sie korrekt an, DayAnalyzer
        // kann den Muscle-Focus berechnen.
        let template = ExerciseTemplate(
            name: trimmed,
            equipment: draft.equipment,
            primaryMuscle: draft.primaryMuscle,
            isCustom: true,
            isSystemCompound: draft.isCompound
        )
        modelContext.insert(template)

        let exercise = Exercise(
            name: trimmed,
            orderIndex: day.activeExercises.count,
            isCompound: draft.isCompound,
            primaryMuscle: draft.primaryMuscle,
            equipment: draft.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// UI-Refactor (Korrektur V1): Name/Struktur analog zu
    /// `PlanEditorView.revertToSnapshot()` — rollt die `metaSection`-Felder
    /// UND (neu) die Uebungs-Reihenfolge zurueck.
    private func revertToSnapshot() {
        snapshot.apply(to: day)
        revertExerciseOrder(usingSnapshot: exerciseOrderIndexAtOpen)
        dismiss()
    }

    /// UI-Refactor (Korrektur V1): reine Rueckschreib-Logik mit explizitem
    /// `orderIndexAtOpen`-Parameter statt direktem `@State`-Zugriff — testbar
    /// ohne lebende SwiftUI-Umgebung (siehe Tests/FitnessAppUITests).
    /// Uebungen, die beim Oeffnen schon da waren, zurueck auf ihren
    /// urspruenglichen Platz — ignoriert seitdem neu hinzugefuegte/geloeschte
    /// Uebungen (siehe `exerciseOrderIndexAtOpen`-Doc).
    internal func revertExerciseOrder(usingSnapshot orderIndexAtOpen: [PersistentIdentifier: Int]) {
        for exercise in day.activeExercises {
            if let original = orderIndexAtOpen[exercise.persistentModelID] {
                exercise.orderIndex = original
            }
        }
    }

    /// DEL-095: Reorder via Drag&Drop. Per `Array.move` umschichten, dann
    /// alle `orderIndex` neu kontinuierlich 0..n-1 vergeben — sonst entstehen
    /// Luecken, die nach dem naechsten Delete unstable sortieren.
    /// **Superset-aware**: Wenn der User eine Uebung zieht, die zu einem
    /// Superset gehoert (`supersetId != nil`), nehmen wir den Partner
    /// automatisch mit. Sonst zerreisst ein versehentlicher Drag die
    /// DEL-083-Kopplung lautlos.
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var arr = orderedExercises
        let expandedSource = expandSupersetGroups(in: arr, base: source)
        arr.move(fromOffsets: expandedSource, toOffset: destination)
        for (i, exercise) in arr.enumerated() {
            exercise.orderIndex = i
        }
    }

    /// Erweitert eine Drag-Source-IndexSet um alle Geschwister-Indices, die
    /// denselben `supersetId` tragen — Superset-Bloecke bleiben so beim
    /// Reorder zusammen.
    private func expandSupersetGroups(in arr: [Exercise], base: IndexSet) -> IndexSet {
        var expanded = base
        for index in base {
            guard index < arr.count, let supersetId = arr[index].supersetId else { continue }
            for (i, ex) in arr.enumerated() where ex.supersetId == supersetId {
                expanded.insert(i)
            }
        }
        return expanded
    }

    /// DEL-049: Loescht eine aktive Uebung UND ihren archivierten Urlaubs-
    /// Modus-Snapshot (`swappedFromOriginal`), sonst bleibt ein toter
    /// Eintrag in der Datenbank zurueck, den der User nirgendwo mehr sieht.
    ///
    /// Bugfix (Day-Editor-Persistenzbug, Swipe-Loeschen): Loeschen/Reorder
    /// sind bewusst "sofort wirksame Aktionen ohne Save/Cancel-Konzept"
    /// (siehe `snapshot`-Typ-Doku) — sie haengen deshalb NICHT am
    /// "Fertig"-Checkmark (`saveAndDismiss()`), sondern muessen SOFORT
    /// selbst dauerhaft werden, da weder "Fertig" noch der Zurueck-Chevron
    /// (`isDirty` ignoriert Loeschen/Reorder ausdruecklich) danach noch
    /// garantiert ausgeloest werden. Ohne diesen expliziten Save verliess
    /// sich die Loeschung bislang auf SwiftDatas impliziten Context-
    /// Autosave — ein App-Kaltstart kurz danach konnte die Loeschung
    /// dadurch verlieren (derselbe, bereits an anderer Stelle TestingBot-
    /// bestaetigte Musterfehler, siehe `TrainingDayContentSnapshotWriter-
    /// Tests.testCapturePersistsWithoutAnyAdditionalCallerSave`).
    ///
    /// Scheitert der Save: KEIN automatischer Wiederaufbau der geloeschten
    /// Uebung(en). Ein `context.rollback()` ist in dieser App bewusst
    /// ausgeschlossen (wirkt auf den GESAMTEN, geteilten Context und wuerde
    /// unabhaengige, anderswo bereits bestaetigte Aenderungen mit zerstoeren
    /// — siehe `PlanGeneratorInstantiator`-Typ-Doku). Eine manuell neu
    /// angelegte Ersatz-Uebung waere ebenfalls KEINE echte Wiederherstellung
    /// — sie bekaeme eine neue `instanceID` und wuerde damit die ueber P8
    /// Stufe-2 abgesicherte Resume-Identitaet einer eventuell gerade
    /// offenen Session brechen. Stattdessen nur sichtbarer Fehlerhinweis
    /// (bestehende `swapResultToast`-Konvention) — der User sieht die
    /// geloeschte Uebung weiterhin als entfernt und kann sie bei Bedarf wie
    /// jede andere Uebung ueber den Bibliotheks-Picker erneut hinzufuegen.
    /// Pure-Logic-Helfer fuer den Crash-Fix (Block C, TestingBot, 2/2
    /// reproduziert): liefert die nach dem Loeschen verbleibenden Uebungen,
    /// berechnet AUSSCHLIESSLICH aus der uebergebenen Momentaufnahme
    /// `snapshot` (vor dem `modelContext.delete(...)` erfasst). `internal`
    /// und ohne `modelContext`-Zugriff, daher direkt testbar — siehe
    /// `DayEditorDeleteReindexTests`.
    internal static func remainingAfterDeletion(
        _ snapshot: [Exercise], removing offsets: IndexSet
    ) -> [Exercise] {
        snapshot.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
    }

    private func deleteExercises(at offsets: IndexSet) {
        let arr = orderedExercises
        for index in offsets {
            let exercise = arr[index]
            // Original mit-cascaden (chain-cleanup, falls Doppel-Swap).
            var cur: Exercise? = exercise.swappedFromOriginal
            while let next = cur {
                let nextOriginal = next.swappedFromOriginal
                modelContext.delete(next)
                cur = nextOriginal
            }
            modelContext.delete(exercise)
        }
        // Re-index remaining exercises so orderIndex stays a contiguous 0..n-1.
        // Bugfix (Crash DEL-Day-Editor-Swipe): NICHT erneut `orderedExercises`
        // (liest `day.activeExercises` live) abfragen — SwiftData aktualisiert
        // die In-Memory-Relationship nach `delete()` nicht garantiert synchron
        // vor dem `save()`, wodurch die gerade geloeschte(n) Uebung(en) hier
        // nochmal auftauchen konnten. Das Setzen von `orderIndex` auf einem
        // bereits zum Loeschen vorgemerkten Objekt crasht den Prozess sofort
        // (reproduziert 2/2 auf TestingBot, Block C). Stattdessen aus der
        // bereits VOR dem Loeschen erfassten Momentaufnahme `arr` rechnen.
        let remaining = Self.remainingAfterDeletion(arr, removing: offsets)
        for (i, exercise) in remaining.enumerated() {
            exercise.orderIndex = i
        }
        do {
            try modelContext.save()
        } catch {
            showTransientToast(String(localized: "day.editor.exercise.delete.saveFailed", bundle: .module))
        }
    }

    /// Bugfix (Day-Editor-Persistenzbug): gemeinsamer Helfer fuer die
    /// bestehende `swapResultToast`-Konvention (siehe `switchPlanEnvAndAdd`)
    /// — vermeidet doppelten Animations-/Dispatch-Code an den zwei neuen
    /// Fehler-Aufrufstellen (`deleteExercises`, `saveAndDismiss`).
    private func showTransientToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            swapResultToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                swapResultToast = nil
            }
        }
    }

    /// Triggered vom "Training starten"-Button. Wenn eine ungespeicherte
    /// Session existiert (DEL-042), oeffnet sich der Recovery-Dialog —
    /// erst nach User-Entscheidung wird tatsaechlich neu gestartet.
    private func startSession() {
        if !openSessions.isEmpty {
            showingOpenSessionDialog = true
        } else {
            actuallyStartNewSession()
        }
    }

    /// Erstellt + navigiert in eine neue Session. Wird sowohl direkt
    /// (kein Konflikt) als auch nach Recovery-Entscheidung aufgerufen.
    private func actuallyStartNewSession() {
        // DEL-239: Rueckfrage nach langer Pause, VOR dem Insert. Derselbe
        // Abfang wie in DashboardView — sonst waere das Verhalten davon
        // abhaengig, von welchem Screen aus gestartet wird.
        // Bugfix (Comeback-Advisor bei Zeitformat-Sessions): reine
        // Zeitformat-Tage (AMRAP/EMOM/Auf Zeit) haben keine Zielgewichte,
        // die eine Reduktion betreffen koennte — die Rueckfrage waere hier
        // irrefuehrend. `timeFormat` ist ein einzelnes Feld pro TrainingDay,
        // ein Tag ist also nie "gemischt": entweder komplett Zeitformat
        // oder komplett normales Satz/Wiederholungs-Training.
        if day.timeFormat == nil, deloadEnabled, comebackAssessment == nil,
           let assessment = AbsenceDeload.assess(in: modelContext) {
            pendingComebackStart = { actuallyStartNewSession() }
            comebackAssessment = assessment
            return
        }
        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: day.activeExercises.count,
            isCompleted: false,
            // Bugfix (README 2.35, Ad-Hoc-Zeitformat-Start ueber diesen Editor):
            // `isAdHoc` galt bisher als stabiler Marker mit GENAU einem
            // Erzeugungspfad (`startAdHocWorkout`, siehe Kommentar in
            // `WorkoutSession+DisplayName.swift`) - das stimmt seit dem Ad-Hoc-
            // Zeitformat-Start nicht mehr, der ebenfalls einen planlosen Tag
            // hier her navigiert. Ohne dieses Flag wuerde z.B.
            // `TimedWorkoutPlayerView.discardTimedSession` den verwaisten Tag
            // beim Abbrechen nicht mitloeschen (die Bedingung dort prueft
            // `session.isAdHoc`, nicht `day.plan == nil`).
            isAdHoc: day.plan == nil,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
        // P8 Stufe-2: Initial-Snapshot bei Erzeugung (Plan-Tag ODER
        // Ad-hoc-Zeitformat-Tag ueber diesen Editor-Pfad).
        TrainingDayContentSnapshotWriter.capture(for: session, in: modelContext)
        // README 2.35: schuetzt den Ad-Hoc-Tag jetzt endgueltig vor
        // `sweepAbandonedAdHocDayIfNeeded()` - siehe Doc-Kommentar bei
        // `didStartSessionForAdHocDay`.
        didStartSessionForAdHocDay = true
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
    }

    /// README 2.35: siehe Doc-Kommentar bei `didStartSessionForAdHocDay` und
    /// beim `.onDisappear`-Aufruf in `body`. Loescht NUR einen planlosen Tag,
    /// fuer den nie erfolgreich eine Session angelegt wurde - egal wie viele
    /// Uebungen ueber den Bibliotheks-Picker schon hinzugefuegt wurden, ohne
    /// Session ist davon nichts "echt" (kein anderer Weg fuehrt je wieder zu
    /// diesem Tag zurueck).
    private func sweepAbandonedAdHocDayIfNeeded() {
        guard day.plan == nil, !didStartSessionForAdHocDay else { return }
        modelContext.delete(day)
    }

    /// DEL-042 "Fortsetzen": navigiere in die existing offene Session ohne
    /// eine neue zu erstellen.
    ///
    /// DEL-127: optionaler `session`-Parameter — wenn vom Dialog-Pfad
    /// (Recovery) ohne Argument aufgerufen, fallbacked es auf
    /// `openSessions.first`. Aus dem adaptiven Plan-Detail-CTA wird die
    /// konkrete `openSessionForCurrentDay` reingereicht, damit auch bei
    /// mehreren offenen Sessions (selten, aber moeglich) die richtige
    /// fortgesetzt wird.
    private func resumeOpenSession(_ session: WorkoutSession? = nil) {
        guard let open = session ?? openSessions.first else { return }
        navigation.workoutPath.append(ActiveSessionRoute(session: open))
    }

    /// DEL-042 "Speichern & neu starten": markiere die alte Session als
    /// isCompleted=true (mit den bisher geloggten Saetzen), rechne totals
    /// und starte dann eine neue Session.
    private func completeOpenSessionAndStartNew() {
        guard let open = openSessions.first else {
            actuallyStartNewSession()
            return
        }
        let now = Date()
        open.endTime = now
        open.durationMinutes = max(0, Int(now.timeIntervalSince(open.startTime) / 60))
        // DEL-221: Aggregate ueber den einen Schreiber. `exerciseCount` bleibt
        // hier absichtlich unangetastet — die Session traegt den Wert, den sie
        // beim Start bekommen hat.
        open.recomputeTotals()
        // P8 Stufe-2: kein erneuter capture-Aufruf — siehe
        // ActiveWorkoutView.finishWorkout für die Begründung.
        open.isCompleted = true
        try? modelContext.save()
        actuallyStartNewSession()
    }

    /// DEL-042 "Verwerfen": lösche die alte Session inkl. ihrer Logs
    /// (cascade) und starte neu.
    private func discardOpenSessionAndStartNew() {
        guard let open = openSessions.first else {
            actuallyStartNewSession()
            return
        }
        modelContext.delete(open)
        try? modelContext.save()
        actuallyStartNewSession()
    }

    /// Schreibt eine isRestDay=true-Session in den Store. Der PlanNavigator zaehlt
    /// alle completed-Sessions, also rueckt der Pointer auf den naechsten echten
    /// Tag. Da isRestDay=true, taucht der Eintrag NICHT in History/Trophy-Room
    /// /Recent-Workouts auf. Nach dem Insert poppen wir ein Step im NavigationStack
    /// zurueck zum Plan-Editor, damit der User direkt sieht, dass der Tag erledigt
    /// ist.
    private func markRestDaySkipped() {
        let now = Date()
        let session = WorkoutSession(
            startTime: now,
            endTime: now,
            durationMinutes: 0,
            exerciseCount: 0,
            totalSets: 0,
            totalVolumeKg: 0,
            isCompleted: true,
            isRestDay: true,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
        // Aus dem DayEditor zurueck ins parent (PlanEditor) — der naechste echte
        // Trainings-Tag steht dann direkt im Dashboard-Plan-Day-Card.
        if !navigation.workoutPath.isEmpty {
            navigation.workoutPath.removeLast()
        }
    }

    // MARK: Labels

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    // DEL-121 Final: delegieren an DayType.localizedName statt eigene
    // dayType.*-Keys. Die collidierten via snake_case/camelCase-Normalization
    // mit den legacy day_type.*-Keys (selbes Swift-Symbol). Die EN-Strings
    // wurden ins day_type.* Catalog-Namespace gemerged (Upper Body / Lower
    // Body / Rest Day statt Upper / Lower / Rest), dayType.* Keys deleted.
    private func typeLabel(_ type: DayType) -> String {
        String(localized: type.localizedName)
    }

    /// README 2.10/19c-19d: "AMRAP · 20 MIN"-Kapsel neben dem Uebungen-
    /// Section-Header. `DeltiqPill` grossschreibt nicht selbst (siehe dessen
    /// Doc-Kommentar), darum hier explizit `.uppercased()`.
    private func timedFormatPillText(_ format: WorkoutTimeFormat) -> String {
        var parts = [timedFormatDisplayName(format)]
        if let cap = day.timeCapMinutes {
            parts.append("\(cap) " + String(localized: "unit.minutes.short", bundle: .module))
        }
        // Zirkel hat kein `timeCapMinutes` - die Rundenzahl uebernimmt hier
        // dieselbe Rolle als knapper Kontext-Zusatz.
        if format == .circuit, let rounds = day.circuitRounds {
            parts.append("\(rounds)×")
        }
        return parts.joined(separator: " · ").uppercased()
    }

}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseRow: View {
    let exercise: Exercise
    var isInSuperset: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // DEL-083: Superset-Indikator — farbige Klammer/Linie am
            // linken Rand. Nur sichtbar, wenn die Uebung Teil einer
            // verknuepften Gruppe ist.
            Rectangle()
                .fill(isInSuperset ? Color.deltiqOrange : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            Text("\(exercise.orderIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.Deltiq.textSecondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // DEL-124: displayName resolved via Exercise+DisplayName-
                    // Library-Lookup (DEL-118). Plan-Detail-Row zeigt jetzt
                    // multilinguale Namen statt das deutsche `name`-Snapshot.
                    Text(exercise.displayName)
                        .font(.body)
                    // P5.3: gleiche Pill wie im aktiven Workout (`ExerciseCard`)
                    // — vorher sah man im Editor nicht, dass eine Uebung
                    // Warmup/Cooldown ist (keine Referenz auf `ExerciseRole`
                    // in dieser Datei).
                    if let pillText = exercise.role.localizedPillText {
                        Text(pillText)
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            Spacer()
            if isInSuperset {
                Image(systemName: "link")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .accessibilityLabel("Superset")
            }
            if exercise.isCardio {
                // Handoff: kein echter Apple-Health-Bezug (nur dekoratives
                // "Cardio"-Symbol) - Akzent-Orange statt .pink.
                Image(systemName: "heart.fill").foregroundStyle(Color.deltiqOrange)
            }
            if exercise.isTimeBased {
                Image(systemName: "stopwatch").foregroundStyle(Color.deltiqOrange)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.Deltiq.textTertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // DEL-118: format-string via xcstrings statt hardcoded DE-Interpolation.
    // Drei Varianten:
    //   * Cardio → "workout.detail.cardio"
    //   * Time-based (Plank, Wall Sit) → "workout.detail.seconds"
    //   * Standard Strength → "workout.detail.reps"
    //
    // README 2.10/19c-19d: Zeitformat-Tage (`exercise.day?.timeFormat`)
    // zeigen stattdessen nur das Ziel pro Runde (`timedFormatCircuitLabel`,
    // TimedWorkoutPlayerView.swift - dieselbe Fassung wie im Player und in
    // WorkoutSummaryView/TemplatePreviewView).
    private var detailLine: String {
        if let format = exercise.day?.timeFormat {
            return timedFormatCircuitLabel(
                repsMin: exercise.repsMin, isTimeBased: exercise.isTimeBased,
                sets: exercise.sets, format: format
            )
        }
        if exercise.isCardio {
            return String(format: String(localized: "workout.detail.cardio", bundle: .module), exercise.restSeconds)
        }
        let repsText = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        // DEL-118-Nachtrag (README 2.10): manuelle .one/.other-Auswahl statt
        // eines einzelnen Format-Strings - sonst bleibt "Sätze"/"Sek" (DE)
        // fuer exercise.sets == 1 stehen (replacingOccurrences loest keine
        // echten Plurals auf, siehe PlanRow.pluralized fuer dasselbe Muster).
        let baseKey = exercise.isTimeBased ? "workout.detail.seconds" : "workout.detail.reps"
        let key = exercise.sets == 1 ? "\(baseKey).one" : "\(baseKey).other"
        let template = String(localized: String.LocalizationValue(key), bundle: .module)
        return template
            .replacingOccurrences(of: "%1$lld", with: "\(exercise.sets)")
            .replacingOccurrences(of: "%2$@",   with: repsText)
            .replacingOccurrences(of: "%3$lld", with: "\(exercise.restSeconds)")
    }
}

/// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): `TrainingDay` ist
/// `@Bindable` und autosaved direkt in SwiftData. Haelt nur die `metaSection`-
/// Felder fest (Name/Wochentag/Typ/Intensitaet/Zeitformat + dessen Unterfelder)
/// — NICHT die Uebungsliste, deren Hinzufuegen/Loeschen/Reorder/Training-
/// Starten eigene, sofort wirksame Aktionen ohne Save/Cancel-Konzept sind.
/// `internal` statt `private`, damit gezielte Tests (siehe
/// `Tests/FitnessAppUITests`) die Capture/Apply-Logik per `@testable
/// import` direkt pruefen koennen.
@available(iOS 17.0, macOS 14.0, *)
struct TrainingDaySnapshot: Equatable {
    var customName: String?
    var weekday: Int
    var type: DayType
    var nextIntensity: DayIntensity
    var timeFormat: WorkoutTimeFormat?
    var timeCapMinutes: Int?
    var circuitRounds: Int?
    var circuitRestSeconds: Int?
    var circuitMode: CircuitRoundMode?

    static func capture(from day: TrainingDay) -> TrainingDaySnapshot {
        TrainingDaySnapshot(
            customName: day.customName,
            weekday: day.weekday,
            type: day.type,
            nextIntensity: day.nextIntensity,
            timeFormat: day.timeFormat,
            timeCapMinutes: day.timeCapMinutes,
            circuitRounds: day.circuitRounds,
            circuitRestSeconds: day.circuitRestSeconds,
            circuitMode: day.circuitMode
        )
    }

    func apply(to day: TrainingDay) {
        day.customName = customName
        day.weekday = weekday
        day.type = type
        day.nextIntensity = nextIntensity
        day.timeFormat = timeFormat
        day.timeCapMinutes = timeCapMinutes
        day.circuitRounds = circuitRounds
        day.circuitRestSeconds = circuitRestSeconds
        day.circuitMode = circuitMode
    }
}
#endif
