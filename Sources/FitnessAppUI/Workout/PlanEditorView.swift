#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Edits a single `TrainingPlan` — name, weeks, environment, isActive flag, plus the
/// list of `TrainingDay`s. Setting a plan to "active" unsets the flag on every other
/// plan so there's always at most one active plan at a time.
@available(iOS 17.0, macOS 14.0, *)
public struct PlanEditorView: View {

    @Bindable public var plan: TrainingPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    @Query private var allPlans: [TrainingPlan]

    /// DEL-050: alle aktuell als `isActive == true` markierten Plaene. Wenn das
    /// genau {self} oder leer ist, syncen wir den Profile-Env still mit; sonst
    /// stellen wir dem User die Multi-Plan-Frage.
    @Query(filter: #Predicate<TrainingPlan> { $0.isActive == true })
    private var activePlans: [TrainingPlan]

    /// DEL-050: Source of Truth fuer den globalen Trainingsort. Ein Profil-
    /// Eintrag pro App-Install (Singleton-Convention). Wenn nil, ist der User
    /// noch im Onboarding und es gibt keinen globalen Env zu syncen — der
    /// Bottom-Up-Pfad bleibt dann lokal.
    @Query private var userProfiles: [UserBodyProfile]

    // DEL-022 — Environment-Swap-State
    @State private var pendingEnvironmentSwap: PendingEnvironmentSwap?
    // DEL-049 — Restore-Prompt-State (Urlaubs-Modus zu Ende). Separat vom
    // adapt-State, weil das UI-Wording, die Buttons UND die ausgefuehrte
    // Aktion komplett andere sind.
    @State private var pendingEnvironmentRestore: PendingEnvironmentSwap?
    /// DEL-050 — Multi-Plan-Sync-Prompt-State. Nur gesetzt wenn der User
    /// mehrere aktive Plaene hat und EINEN davon umstellt.
    @State private var pendingGlobalSync: PendingEnvironmentSwap?
    @State private var swapResultToast: String?

    public init(plan: TrainingPlan) {
        self.plan = plan
    }

    public var body: some View {
        Form {
            // DEL-030 + DEL-035: Templates sind jetzt voll editierbar wie
            // Custom-Plaene — kein Lock-Banner, kein "Programm-Typ"/"Beschreibung"-
            // Feld mehr in der UI. metaSection nur noch der Plan-Name.
            // settingsSection (Wochen/Trainingsort/Active) wandert nach UNTEN
            // unter daysSection, damit die Trainings-Liste oben bleibt.
            metaSection
            daysSection
            settingsSection
        }
        .navigationTitle(plan.name.isEmpty ? String(localized: "tab.plan", bundle: .module) : plan.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // DEL-095: EditButton aktiviert den Drag-Mode fuer Tage-Reorder.
        // Bei readOnly-Templates blenden wir den Button aus.
        .toolbar {
            if !isReadOnly && !plan.days.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        #endif
        // DEL-022 + DEL-031 + DEL-049 + DEL-050 — Trainingsort-Wechsel feuert
        // einen mehrstufigen Flow:
        //
        //   * SCHRITT A (DEL-050 Bottom-Up-Sync): je nach Anzahl anderer
        //     aktiver Plaene entweder still den Profile-Env synchronisieren
        //     ODER den User mit dem Multi-Plan-Sync-Dialog fragen, ob alle
        //     anderen Plaene mit umgestellt werden sollen. Nur wenn der User
        //     "Nur fuer diesen Plan" waehlt, bleibt der globale Wert wie er
        //     war.
        //
        //   * SCHRITT B (DEL-049 Restore vs. DEL-022 Adapt): Frage nach den
        //     Uebungen DIESES Plans. Restore wenn archivierte Originale im
        //     neuen Env wieder passen, sonst klassischer Adapt-Prompt. Wird
        //     vom Schritt-A-Flow direkt im Anschluss aufgerufen.
        //
        // Leerer Plan (keine aktiven Uebungen) skipped Schritt B, aber
        // Schritt A laeuft trotzdem — Metadaten-Sync ist auch ohne Uebungen
        // relevant (User koennte spaeter welche hinzufuegen wollen).
        .onChange(of: plan.targetEnvironment) { oldValue, newValue in
            guard oldValue != newValue else { return }
            let pending = PendingEnvironmentSwap(oldEnv: oldValue, newEnv: newValue)

            // SCHRITT A — DEL-050.
            // `otherActivePlans` = aktive Plaene OHNE den Plan, den wir gerade
            // editieren. Wenn leer, sind wir entweder der einzige aktive Plan
            // oder gar keiner ist aktiv → silent sync.
            let others = otherActivePlans
            if others.isEmpty {
                if let profile = userProfiles.first {
                    profile.environment = newValue
                }
                continueWithAdaptOrRestorePrompt(pending)
            } else {
                // Mehrere aktive Plaene → User darf entscheiden.
                pendingGlobalSync = pending
            }
        }
        // DEL-050 — Multi-Plan-Sync-Dialog. Erscheint nur wenn der User
        // mehrere aktive Plaene hat. Drei Buttons: alle + global syncen,
        // nur diesen Plan aendern, oder die Picker-Aenderung verwerfen.
        .confirmationDialog(
            Text("planEditor.globalSync.title", bundle: .module),
            isPresented: Binding(
                get: { pendingGlobalSync != nil },
                set: { if !$0 { pendingGlobalSync = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingGlobalSync
        ) { swap in
            Button {
                applyGlobalSync(newEnv: swap.newEnv)
                continueWithAdaptOrRestorePrompt(swap)
                pendingGlobalSync = nil
            } label: {
                Text("planEditor.globalSync.allPlans", bundle: .module)
            }
            Button {
                continueWithAdaptOrRestorePrompt(swap)
                pendingGlobalSync = nil
            } label: {
                Text("planEditor.globalSync.thisOnly", bundle: .module)
            }
            Button(role: .cancel) {
                plan.targetEnvironment = swap.oldEnv
                pendingGlobalSync = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { swap in
            Text(String(format: String(localized: "planEditor.globalSync.message", bundle: .module), environmentLabel(swap.newEnv)))
        }
        .confirmationDialog(
            Text("profile.envSwap.title", bundle: .module),
            isPresented: Binding(
                get: { pendingEnvironmentSwap != nil },
                set: { if !$0 { pendingEnvironmentSwap = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEnvironmentSwap
        ) { swap in
            Button {
                performEnvironmentSwap(to: swap.newEnv)
                pendingEnvironmentSwap = nil
            } label: {
                Text("planEditor.envSwap.adapt", bundle: .module)
            }
            Button {
                pendingEnvironmentSwap = nil
            } label: {
                Text("planEditor.envSwap.justEnv", bundle: .module)
            }
            Button(role: .cancel) {
                // Picker rueckgaengig machen
                plan.targetEnvironment = swap.oldEnv
                pendingEnvironmentSwap = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { swap in
            Text("planEditor.envSwap.message", bundle: .module)
        }
        // DEL-049 — Restore-Dialog ("Urlaubs-Modus zu Ende").
        .confirmationDialog(
            Text("profile.envRestore.title", bundle: .module),
            isPresented: Binding(
                get: { pendingEnvironmentRestore != nil },
                set: { if !$0 { pendingEnvironmentRestore = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEnvironmentRestore
        ) { swap in
            Button {
                performEnvironmentRestore(to: swap.newEnv)
                pendingEnvironmentRestore = nil
            } label: {
                Text("profile.envRestore.confirm", bundle: .module)
            }
            Button {
                performEnvironmentSwap(to: swap.newEnv)
                pendingEnvironmentRestore = nil
            } label: {
                Text("profile.envRestore.adjustNew", bundle: .module)
            }
            Button(role: .cancel) {
                plan.targetEnvironment = swap.oldEnv
                pendingEnvironmentRestore = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { swap in
            Text("planEditor.envRestore.message", bundle: .module)
        }
        .overlay(alignment: .bottom) {
            if let msg = swapResultToast {
                Label(msg, systemImage: "checkmark.seal.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Bundle der zwei Environments fuer den ConfirmationDialog. Equatable
    /// damit der Dialog korrekt presenting-binden kann.
    private struct PendingEnvironmentSwap: Equatable {
        let oldEnv: EnvironmentType
        let newEnv: EnvironmentType
    }

    // MARK: - DEL-050 Bottom-Up Sync helpers

    /// Aktive Plaene ohne den, den wir gerade editieren. Wenn leer →
    /// silent-sync zum Profile-Env; sonst Multi-Plan-Frage.
    private var otherActivePlans: [TrainingPlan] {
        activePlans.filter { $0.persistentModelID != plan.persistentModelID }
    }

    /// Stage 2 vom DEL-050-Flow: Nachdem der globale Sync-Pfad entschieden
    /// wurde (silent oder via Dialog), entscheidet diese Methode zwischen
    /// dem DEL-049-Restore- und dem DEL-022-Adapt-Prompt fuer DIESEN Plan.
    /// Leere Plaene skipen den Prompt.
    private func continueWithAdaptOrRestorePrompt(_ swap: PendingEnvironmentSwap) {
        guard plan.days.contains(where: { !$0.activeExercises.isEmpty })
        else { return }
        if PlanEnvironmentMigrator.hasRestorableOriginals(
            plan: plan, forEnvironment: swap.newEnv
        ) {
            pendingEnvironmentRestore = swap
        } else {
            pendingEnvironmentSwap = swap
        }
    }

    /// User hat "Fuer alle anpassen" gewaehlt → globaler Trainingsort UND
    /// alle anderen aktiven Plaene werden synchron mitgezogen. Der Migrator
    /// laeuft auf den anderen Plaenen direkt durch (Adapt-Pfad), damit
    /// derEx-Bestand auch dort konsistent wird. Toast meldet das Ergebnis.
    private func applyGlobalSync(newEnv: EnvironmentType) {
        if let profile = userProfiles.first {
            profile.environment = newEnv
        }
        let others = otherActivePlans
        guard !others.isEmpty else { return }
        let outcome = PlanEnvironmentMigrator.migrateAll(
            plans: others,
            toEnvironment: newEnv,
            modelContext: modelContext
        )
        // Toast mit dem Aggregat-Ergebnis der OTHERS (ohne diesen Plan,
        // der durch den Folge-Dialog gleich noch eigene Counts erzeugt).
        var parts: [String] = []
        parts.append("\(outcome.plansTouched) andere\(outcome.plansTouched == 1 ? "r Plan" : " Pläne") synchronisiert")
        if outcome.result.swapped > 0 { parts.append("\(outcome.result.swapped) ersetzt") }
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

    /// DEL-030: Plaene sind jetzt IMMER editierbar. `plan.isTemplate` bleibt
    /// im Model fuer eventuelle zukuenftige Read-Only-Surface (z.B. App-Store-
    /// Curated-Showcase-Plaene), aktuell aber durchgehend false nach
    /// ProgramInstantiator. Diese Property ist daher legacy-stub, gibt
    /// immer `false` zurueck. DayEditor + ExerciseEditor referenzieren sie
    /// noch und werden in einer Aufraeumwelle entfernt.
    private var isReadOnly: Bool {
        false
    }

    // MARK: Sections

    /// Legacy Template-Banner — wird nicht mehr aus body referenziert (DEL-030).
    /// Bleibt fuer eventuell zukuenftige Showcase-Plaene als Stub erhalten.
    private var templateBanner: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.indigo.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("planEditor.template.banner.title", bundle: .module)
                        .font(.body.weight(.semibold))
                    Text("planEditor.template.banner.subtitle", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(Color.indigo.opacity(0.08))
    }

    /// DEL-035: nur noch der Plan-Name in der Meta-Section. `programType` ist
    /// ein interner Identifier (z.B. "full_body", "ppl") fuer Recommendation-
    /// Logik und gehoert nicht ins User-UI. `descriptionText` lebt nur im
    /// Template-Picker, im PlanEditor unnoetig.
    private var metaSection: some View {
        Section {
            TextField(String(localized: "day.editor.field.name", bundle: .module), text: $plan.name)
        } header: {
            Text("planEditor.section.info", bundle: .module)
        }
    }

    private var settingsSection: some View {
        // Wochen + Trainingsort bleiben editierbar — der User kann sein
        // Template kuerzen oder die Equipment-Auswahl anpassen, ohne die
        // Uebungs-Struktur zu zerschiessen. Active-Toggle bleibt fuer Plan-
        // Wechsel offen.
        Section {
            Stepper(value: $plan.weeks, in: 1...52) {
                LabeledContent {
                    Text("\(plan.weeks)")
                } label: {
                    Text("planEditor.field.weeks", bundle: .module)
                }
            }

            Picker(selection: $plan.targetEnvironment) {
                Text("environment.gym", bundle: .module).tag(EnvironmentType.gym)
                Text("environment.home_gym", bundle: .module).tag(EnvironmentType.homeGym)
                Text("environment.no_equipment", bundle: .module).tag(EnvironmentType.noEquipment)
            } label: {
                Text("onboarding.field.environment", bundle: .module)
            }

            Toggle(isOn: Binding(
                get: { plan.isActive },
                set: { setActive($0) }
            )) {
                Text("planEditor.toggle.setActive", bundle: .module)
            }

            // DEL-053 — globaler Plan-Override fuer die RIR-Schwelle der
            // Smart-Progression. Auto = pro-Uebung-Default (Compound: RIR<=3,
            // Isolation: RIR<=1). User kann den Override hier auf einen
            // strengeren Wert setzen, z.B. RIR<=2 fuer alle Uebungen.
            Picker(selection: progressionRIRBinding) {
                Text("planEditor.progressRIR.auto", bundle: .module).tag(Optional<Float>.none)
                Text("planEditor.progressRIR.rir0", bundle: .module).tag(Optional<Float>.some(0))
                Text("planEditor.progressRIR.rir1", bundle: .module).tag(Optional<Float>.some(1))
                Text("planEditor.progressRIR.rir2", bundle: .module).tag(Optional<Float>.some(2))
                Text("planEditor.progressRIR.rir3", bundle: .module).tag(Optional<Float>.some(3))
            } label: {
                Text("planEditor.progressRIR.label", bundle: .module)
            }
        } header: {
            Text("planEditor.section.settings", bundle: .module)
        }
    }

    /// DEL-053 — Picker-Binding fuer den optionalen Plan-RIR-Override.
    private var progressionRIRBinding: Binding<Float?> {
        Binding(
            get: { plan.progressionTargetRIROverride },
            set: { plan.progressionTargetRIROverride = $0 }
        )
    }

    @ViewBuilder
    private var daysSection: some View {
        Section {
            if plan.days.isEmpty {
                Text(isReadOnly
                     ? "planEditor.days.empty.template"
                     : "planEditor.days.empty.user",
                     bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if isReadOnly {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                }
                // onDelete bewusst NICHT registriert — Template-Tage sind gesetzt
            } else {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                }
                .onMove(perform: moveDays)
                .onDelete(perform: deleteDays)
            }
        } header: {
            HStack {
                Text("planEditor.section.trainingDays", bundle: .module)
                Spacer()
                if !isReadOnly {
                    // Menu statt Single-Button-Action: User entscheidet pro Klick,
                    // ob Trainings- oder Ruhetag (DEL-021/023).
                    Menu {
                        Button {
                            createNewDay(type: .custom)
                        } label: {
                            Label {
                                Text("planEditor.days.add.training", bundle: .module)
                            } icon: {
                                Image(systemName: "figure.strengthtraining.traditional")
                            }
                        }
                        Button {
                            createNewDay(type: .rest)
                        } label: {
                            Label {
                                Text("day.restDay.title", bundle: .module)
                            } icon: {
                                Image(systemName: "bed.double.fill")
                            }
                        }
                    } label: {
                        Label {
                            Text("common.add", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } footer: {
            Text(isReadOnly
                 ? "planEditor.days.footer.template"
                 : "planEditor.days.footer.user",
                 bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: Derived

    /// Days sorted Mon-first via the shared `PlanNavigator` helper.
    private var orderedDays: [TrainingDay] {
        PlanNavigator.sortByWeekdayMondayFirst(plan.days)
    }

    // MARK: Actions

    private func setActive(_ active: Bool) {
        if active {
            for other in allPlans where other.persistentModelID != plan.persistentModelID {
                other.isActive = false
            }
        }
        plan.isActive = active
    }

    /// Legt einen neuen Tag (Trainings- ODER Ruhetag) im Plan an. Bei
    /// Trainingstagen navigieren wir direkt in den DayEditor, damit der User
    /// gleich Uebungen hinzufuegen kann. Ruhetage werden nur in der Liste
    /// gespeichert — kein Editor noetig.
    private func createNewDay(type: DayType) {
        let nextWeekday = (plan.days.map(\.weekday).max() ?? 1) % 7 + 1
        let defaultName: String
        switch type {
        case .rest: defaultName = "Ruhetag"
        default:    defaultName = "Tag \(plan.days.count + 1)"
        }
        let day = TrainingDay(
            name: defaultName,
            weekday: nextWeekday,
            type: type,
            plan: plan
        )
        modelContext.insert(day)
        // Bei Ruhetagen lassen wir den User auf der Liste — er kann den Tag
        // bei Bedarf umbenennen, aber muss nicht zwingend in den Editor.
        // Bei Trainingstagen springen wir direkt rein um Uebungen hinzuzufuegen.
        if type != .rest {
            navigation.workoutPath.append(day)
        }
    }

    private func deleteDays(at offsets: IndexSet) {
        let toDelete = offsets.map { orderedDays[$0] }
        for day in toDelete {
            modelContext.delete(day)
        }
    }

    /// DEL-095: Drag&Drop-Reorder fuer Trainingstage. `TrainingDay` hat
    /// keinen `orderIndex`, sondern wird per `weekday`-Wert (1=So, 2=Mo, ...
    /// 7=Sa) sortiert. Beim Reorder rotieren wir die EXISTING weekday-Werte
    /// auf die neue Position-Reihenfolge — z.B. Mo/Mi/Fr-Plan (wd 2/4/6),
    /// User zieht Fr-Day auf Position 0 → neue Zuordnung Fr→Mo (2),
    /// Mo→Mi (4), Mi→Fr (6). User-Intent "ich will diesen Tag zuerst" wird
    /// damit auf die existierenden Wochentage gemapped, ohne neue Slots zu
    /// erfinden oder Slots zu kollidieren.
    private func moveDays(from source: IndexSet, to destination: Int) {
        var arr = orderedDays
        // Snapshot der Wochentage in der aktuellen (Mo-first-)Reihenfolge —
        // diese Liste bleibt fix; wir verteilen sie auf die neu sortierte
        // Tag-Reihenfolge.
        let originalWeekdays = arr.map(\.weekday)
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, day) in arr.enumerated() {
            day.weekday = originalWeekdays[i]
        }
    }

    /// DEL-022 / DEL-047 / DEL-049: Delegiert an `PlanEnvironmentMigrator`.
    /// Die eigentliche Swap-Logik lebt dort, damit Profil-Sync, Bottom-Up
    /// und Urlaubs-Modus-Restore alle den selben Algorithmus nutzen.
    /// Archive-statt-delete-Semantik: die alten Uebungen werden NICHT
    /// geloescht, sondern als `isArchived = true` zur Seite gelegt; die
    /// neue Ersatz-Uebung haelt eine Referenz auf das Original via
    /// `swappedFromOriginal`.
    private func performEnvironmentSwap(to newEnv: EnvironmentType) {
        let result = PlanEnvironmentMigrator.migrate(
            plan: plan,
            toEnvironment: newEnv,
            modelContext: modelContext
        )
        showSwapToast(result: result)
    }

    /// DEL-049: gegen-Operation zu `performEnvironmentSwap`. Reaktiviert die
    /// archivierten Originale und entsorgt die Urlaubs-Modus-Ersatzuebungen.
    private func performEnvironmentRestore(to newEnv: EnvironmentType) {
        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan,
            toEnvironment: newEnv,
            modelContext: modelContext
        )
        showSwapToast(result: result)
    }

    private func showSwapToast(result: PlanEnvironmentSwapResult) {
        var parts: [String] = []
        if result.restored > 0   { parts.append("\(result.restored) wiederhergestellt") }
        if result.swapped > 0    { parts.append("\(result.swapped) ersetzt") }
        if result.kept > 0       { parts.append("\(result.kept) ohne Alternative") }
        if result.compatible > 0 { parts.append("\(result.compatible) unverändert") }
        let message = parts.isEmpty ? "Keine Übungen zum Anpassen" : parts.joined(separator: " · ")

        withAnimation(.easeOut(duration: 0.2)) {
            swapResultToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                swapResultToast = nil
            }
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct DayRow: View {
    let day: TrainingDay

    var body: some View {
        HStack(spacing: 12) {
            // DEL-105: Wochentag-Badge im Brand-Stil — gedimmter Orange-Tint
            // plus voller Orange-Text. Subtiler als der frueher blaue Gradient,
            // weniger Visual Noise wenn die ganze Woche untereinander steht.
            VStack {
                Text(weekdayShort(day.weekday))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.deltiqOrange)
            }
            .frame(width: 36, height: 36)
            .background(Color.deltiqOrange.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.deltiqOrange.opacity(0.35), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                // DEL-123: day.displayName resolved via TrainingDay.localizationKey
                Text(day.displayName)
                    .font(.body.weight(.medium))
                // DEL-123: format-string via xcstrings statt hardcoded DE.
                Text(String(format: String(localized: "plan.dayRow.exerciseCount", bundle: .module),
                            day.activeExercises.count,
                            intensityLabel(day.nextIntensity)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func weekdayShort(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    private func intensityLabel(_ intensity: DayIntensity) -> String {
        switch intensity {
        case .normal: return "Normal"
        case .light:  return "Leicht"
        case .heavy:  return "Schwer"
        }
    }
}
#endif
