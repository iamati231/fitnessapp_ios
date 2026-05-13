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
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
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
            "Auch andere Pläne anpassen?",
            isPresented: Binding(
                get: { pendingGlobalSync != nil },
                set: { if !$0 { pendingGlobalSync = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingGlobalSync
        ) { swap in
            Button("Für alle anpassen") {
                applyGlobalSync(newEnv: swap.newEnv)
                continueWithAdaptOrRestorePrompt(swap)
                pendingGlobalSync = nil
            }
            Button("Nur für diesen Plan") {
                continueWithAdaptOrRestorePrompt(swap)
                pendingGlobalSync = nil
            }
            Button("Abbrechen", role: .cancel) {
                plan.targetEnvironment = swap.oldEnv
                pendingGlobalSync = nil
            }
        } message: { swap in
            Text("Du hast mehrere aktive Pläne. Soll dein globaler Trainingsort und deine anderen aktiven Pläne ebenfalls auf \(environmentLabel(swap.newEnv)) geändert werden?")
        }
        .confirmationDialog(
            "Trainingsort geändert",
            isPresented: Binding(
                get: { pendingEnvironmentSwap != nil },
                set: { if !$0 { pendingEnvironmentSwap = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEnvironmentSwap
        ) { swap in
            Button("Übungen anpassen") {
                performEnvironmentSwap(to: swap.newEnv)
                pendingEnvironmentSwap = nil
            }
            Button("Nur Trainingsort ändern") {
                pendingEnvironmentSwap = nil
            }
            Button("Abbrechen", role: .cancel) {
                // Picker rueckgaengig machen
                plan.targetEnvironment = swap.oldEnv
                pendingEnvironmentSwap = nil
            }
        } message: { swap in
            Text("Sollen die Übungen an deinen neuen Trainingsort angepasst werden? Übungen ohne passende Alternative bleiben im Plan und brauchen manuelle Anpassung.")
        }
        // DEL-049 — Restore-Dialog ("Urlaubs-Modus zu Ende").
        .confirmationDialog(
            "Ursprüngliche Übungen wiederherstellen?",
            isPresented: Binding(
                get: { pendingEnvironmentRestore != nil },
                set: { if !$0 { pendingEnvironmentRestore = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEnvironmentRestore
        ) { swap in
            Button("Ja, wiederherstellen") {
                performEnvironmentRestore(to: swap.newEnv)
                pendingEnvironmentRestore = nil
            }
            Button("Nein, neu anpassen") {
                performEnvironmentSwap(to: swap.newEnv)
                pendingEnvironmentRestore = nil
            }
            Button("Abbrechen", role: .cancel) {
                plan.targetEnvironment = swap.oldEnv
                pendingEnvironmentRestore = nil
            }
        } message: { swap in
            Text("Wir haben gespeicherte Original-Übungen aus einem früheren Equipment-Wechsel gefunden. Möchtest du diese wiederherstellen (inkl. der letzten Arbeitsgewichte aus der Historie), statt das aktuelle Setup neu anzupassen?")
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

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "Bodyweight"
        }
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
                    Text("Template-Plan")
                        .font(.body.weight(.semibold))
                    Text("Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern.")
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
        Section("Plan-Info") {
            TextField("Name", text: $plan.name)
        }
    }

    private var settingsSection: some View {
        // Wochen + Trainingsort bleiben editierbar — der User kann sein
        // Template kuerzen oder die Equipment-Auswahl anpassen, ohne die
        // Uebungs-Struktur zu zerschiessen. Active-Toggle bleibt fuer Plan-
        // Wechsel offen.
        Section("Einstellungen") {
            Stepper(value: $plan.weeks, in: 1...52) {
                LabeledContent("Wochen", value: "\(plan.weeks)")
            }

            Picker("Trainingsort", selection: $plan.targetEnvironment) {
                Text("Gym").tag(EnvironmentType.gym)
                Text("Home-Gym").tag(EnvironmentType.homeGym)
                Text("Ohne Equipment").tag(EnvironmentType.noEquipment)
            }

            Toggle("Als aktiven Plan setzen", isOn: Binding(
                get: { plan.isActive },
                set: { setActive($0) }
            ))
        }
    }

    @ViewBuilder
    private var daysSection: some View {
        Section {
            if plan.days.isEmpty {
                Text(isReadOnly
                     ? "Template hat keine Trainings-Tage konfiguriert (sollte nicht passieren)."
                     : "Noch keine Trainings-Tage. Tippe '+' oben rechts um deinen ersten Tag anzulegen.")
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
                .onDelete(perform: deleteDays)
            }
        } header: {
            HStack {
                Text("Trainings-Tage")
                Spacer()
                if !isReadOnly {
                    // Menu statt Single-Button-Action: User entscheidet pro Klick,
                    // ob Trainings- oder Ruhetag (DEL-021/023). Default-Behavior
                    // vorher: implizit ein leerer Tag, der wegen
                    // `day.exercises.isEmpty` faelschlich als Ruhetag erkannt
                    // wurde — jetzt explizit.
                    Menu {
                        Button {
                            createNewDay(type: .custom)
                        } label: {
                            Label("Trainingstag", systemImage: "figure.strengthtraining.traditional")
                        }
                        Button {
                            createNewDay(type: .rest)
                        } label: {
                            Label("Ruhetag", systemImage: "bed.double.fill")
                        }
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } footer: {
            Text(isReadOnly
                 ? "Template — Tage sind festgelegt. Tippe einen Tag an, um die Übungen zu sehen."
                 : "Sortiert nach Wochentag (Mo-So). Editiere den Wochentag im Tag selber.")
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
            VStack {
                Text(weekdayShort(day.weekday))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .background(Color.blue.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(day.name)
                    .font(.body.weight(.medium))
                Text("\(day.activeExercises.count) Übungen • \(intensityLabel(day.nextIntensity))")
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
