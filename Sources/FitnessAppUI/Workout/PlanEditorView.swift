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
    @Environment(\.dismiss) private var dismiss
    // `editMode` ist auf macOS/watchOS unavailable (SwiftUI.EnvironmentValues.
    // editMode). Das Package deklariert macOS 14 als Mindestversion, damit
    // `swift test` auf dem macOS-CI-Runner baut - eine echte macOS-Deployment
    // dieser View gibt es nicht. Guard reicht daher als reiner Compile-Fix.
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif

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
    /// UI-Ticket ("Mehr-Informationsarchitektur"): siehe `planMenuAction`/
    /// `body`'s `.sheet` unten.
    @State private var showingExerciseLibrary = false
    // DEL-049 — Restore-Prompt-State (Urlaubs-Modus zu Ende). Separat vom
    // adapt-State, weil das UI-Wording, die Buttons UND die ausgefuehrte
    // Aktion komplett andere sind.
    @State private var pendingEnvironmentRestore: PendingEnvironmentSwap?
    /// DEL-050 — Multi-Plan-Sync-Prompt-State. Nur gesetzt wenn der User
    /// mehrere aktive Plaene hat und EINEN davon umstellt.
    @State private var pendingGlobalSync: PendingEnvironmentSwap?
    @State private var swapResultToast: String?

    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (Korrektur): deckt ALLE Felder dieses Formulars ab,
    /// inklusive `targetEnvironment` und `isActive` — "Verwerfen" muss die
    /// Formular-Aenderungen vollstaendig zuruecknehmen, kein Teil-Rollback.
    /// Die Tage-Liste bleibt aus demselben Grund wie in `DayEditorView`
    /// aussen vor (eigene sofort wirksame Aktionen ohne Save/Cancel-Konzept).
    @State private var snapshot: PlanMetaSnapshot

    /// UI-Refactor (Korrektur, 2. Anlauf): unterdrueckt genau EINE Reaktion
    /// des `.onChange(of: plan.targetEnvironment)`-Handlers — ein Revert ist
    /// kein neuer User-Edit und darf nicht nochmal den Migrations-Dialog
    /// aufmachen. Scharf geschaltet in `revertToSnapshot()` (nur wenn sich
    /// das Feld dort tatsaechlich aendert), konsumiert ausschliesslich im
    /// `.onChange`-Handler selbst — NICHT synchron in `revertToSnapshot()`
    /// zurueckgesetzt, weil `.onChange` erst NACH dessen synchronem Ende
    /// feuert (eine fruehere Fassung setzte das Flag dort faelschlich
    /// schon wieder auf `false`, bevor der Handler es je sehen konnte —
    /// Fund einer unabhaengigen Code-Review, siehe Doc-Kommentare an
    /// beiden Stellen).
    @State private var isApplyingSnapshot = false

    /// UI-Refactor (Korrektur): welcher ANDERE Plan beim Oeffnen aktiv war
    /// (falls dieser Plan es selbst nicht war) — noetig, um einen
    /// `isActive`-Toggle sauber zurueckzurollen: `setActive(true)`
    /// deaktiviert global alle anderen Plaene, ein reines
    /// `plan.isActive = false` beim Verwerfen wuerde diesen anderen Plan
    /// NICHT reaktivieren und den Store ohne jeden aktiven Plan zuruecklassen.
    /// Kann erst in `.onAppear` erfasst werden, nicht in `init` — `@Query
    /// allPlans` ist zum Init-Zeitpunkt noch nicht befuellt.
    @State private var otherActivePlanIDAtOpen: PersistentIdentifier?
    @State private var didCaptureOtherActivePlanBaseline = false

    /// UI-Refactor (Korrektur V1): `weekday` pro Tag-ID beim Oeffnen, NUR fuer
    /// die Reihenfolge-Erkennung. `plan.days` ist ein direkter Init-Parameter
    /// (kein `@Query`), deshalb hier in `init` erfassbar statt erst in
    /// `.onAppear`. Intersection-basiert: neu angelegte Tage haben keinen
    /// Eintrag (werden beim Verwerfen nicht angefasst - Anlegen/Loeschen
    /// bleiben bewusst sofort wirksame Aktionen, siehe `snapshot`-Doc), nur
    /// bereits beim Oeffnen vorhandene UND noch existierende Tage werden auf
    /// ihren urspruenglichen Wochentag zurueckgesetzt.
    @State private var dayWeekdayAtOpen: [PersistentIdentifier: Int]

    public init(plan: TrainingPlan) {
        self.plan = plan
        _snapshot = State(initialValue: PlanMetaSnapshot.capture(from: plan))
        _dayWeekdayAtOpen = State(initialValue: Dictionary(
            uniqueKeysWithValues: plan.days.map { ($0.persistentModelID, $0.weekday) }
        ))
    }

    public var body: some View {
        // Signature-Geruest: eigene Kopfzone statt navigationTitle/Toolbar.
        // `List` bleibt Container (DEL-095: .onMove/.onDelete fuer die
        // Tage-Reihenfolge brauchen sie) - alle drei Sektionen bleiben
        // deshalb in EINER List statt metaSection/settingsSection auf eine
        // separate ScrollView auszulagern (gleiches Prinzip wie
        // DashboardSettingsView).
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                title: plan.name.isEmpty ? String(localized: "tab.plan", bundle: .module) : plan.displayName,
                onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                actions: headerActions
            )

            List {
                // DEL-030 + DEL-035: Templates sind jetzt voll editierbar wie
                // Custom-Plaene — kein Lock-Banner, kein "Programm-Typ"/"Beschreibung"-
                // Feld mehr in der UI. metaSection nur noch der Plan-Name.
                // settingsSection (Wochen/Trainingsort/Active) wandert nach UNTEN
                // unter daysSection, damit die Trainings-Liste oben bleibt.
                metaSection
                equipmentGapSection
                daysSection
                settingsSection
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
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        // UI-Refactor (Korrektur, Punkt 4): bei Aenderungen bleibt die Geste
        // bewusst AUS — ein ungesicherter Verlassen-Weg wuerde am Discard-
        // Dialog vorbei. Ohne Aenderungen funktioniert sie weiter normal.
        .deltiqSwipeBackEnabled(!isDirty)
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            revertToSnapshot()
        }
        .onAppear {
            guard !didCaptureOtherActivePlanBaseline else { return }
            didCaptureOtherActivePlanBaseline = true
            otherActivePlanIDAtOpen = allPlans.first {
                $0.isActive && $0.persistentModelID != plan.persistentModelID
            }?.persistentModelID
        }
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
            // UI-Refactor (Korrektur, 2. Anlauf): ein `revertToSnapshot()`-
            // Rueckschreiben ist kein neuer User-Edit — darf nicht nochmal
            // den Migrations-Dialog ausloesen. Die urspruengliche Fassung
            // setzte `isApplyingSnapshot` synchron in `revertToSnapshot()`
            // wieder auf `false`, BEVOR dieser Handler ueberhaupt feuert
            // (SwiftUI ruft `.onChange` nach dem Update-Zyklus auf, nicht
            // innerhalb desselben synchronen Closures) — die Pruefung sah
            // dadurch immer `false`, unterdrueckte also nie etwas (Fund
            // einer unabhaengigen Code-Review). Fix: `isApplyingSnapshot`
            // wird NUR in `revertToSnapshot()` auf `true` gesetzt (und zwar
            // nur, wenn sich `targetEnvironment` dort nachweislich aendert —
            // `.onChange` feuert garantiert bei jeder echten Aenderung,
            // das Flag kann also nie "haengen bleiben"). Konsumiert wird es
            // ausschliesslich HIER, beim tatsaechlichen Feuern — unabhaengig
            // vom Timing zwischen dem synchronen Rueckschreiben und SwiftUIs
            // Update-Zyklus.
            if isApplyingSnapshot {
                isApplyingSnapshot = false
                return
            }
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
                revertTargetEnvironment(to: swap.oldEnv)
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
                revertTargetEnvironment(to: swap.oldEnv)
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
                revertTargetEnvironment(to: swap.oldEnv)
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
        // UI-Ticket ("Mehr-Informationsarchitektur"): kontextueller Zugang
        // zur bestehenden Uebungsbibliothek beim Bearbeiten eines Plans -
        // oeffnet dieselbe `ExerciseLibraryView` wie unter "Mehr" und wie
        // `PlanBuilderView`s Alternativen-Dialog, kein zweiter Screen.
        .sheet(isPresented: $showingExerciseLibrary) {
            NavigationStack {
                ExerciseLibraryView()
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

    /// Geraete-Nachtest (Runde 6, docs/DELTIQ_DEVICE_ACCEPTANCE.md, D06):
    /// "Cancel" in den drei Umgebungswechsel-Dialogen oben schrieb bisher
    /// direkt `plan.targetEnvironment = swap.oldEnv` OHNE das
    /// `isApplyingSnapshot`-Flag zu setzen — diese synthetische Rueckschreibung
    /// loeste denselben `.onChange`-Handler erneut aus wie ein echter
    /// User-Edit und zeigte prompt den jeweils ANDEREN Dialog (Adapt
    /// <-> Restore), dessen eigener Cancel wiederum zurueck zum ersten
    /// Dialog fuehrte — ein Endlos-Ping-Pong, aus dem "Cancel" nicht
    /// herausfuehrte. Fix: denselben Unterdrueckungs-Mechanismus wie
    /// `revertToSnapshot()` verwenden (nur scharf schalten, wenn sich der
    /// Wert tatsaechlich aendert, sonst bliebe das Flag faelschlich haengen).
    internal func revertTargetEnvironment(to oldEnv: EnvironmentType) {
        if plan.targetEnvironment != oldEnv {
            isApplyingSnapshot = true
        }
        plan.targetEnvironment = oldEnv
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

    // MARK: - README 2.20 "Plan bauen": neu rechnen

    /// Rechnet den am Plan gespeicherten `generatorInput` neu (siehe
    /// `PlanGeneratorInstantiator.recalculate`) und meldet per Toast, wie
    /// viele Tage tatsaechlich ueberschrieben wurden - alle vom User seither
    /// bearbeiteten Tage bleiben unangetastet stehen.
    /// Nachbesserung (Review nach P2.3-Nachbesserung): identisches
    /// manuelles `.one`/`.other`-Muster wie `PlansListView.pluralizedCount`/
    /// `WorkoutSummaryView.formatBreakdownFooter` — bewusst NICHT xcstrings
    /// `variations.plural`, an denen Xcode 26.4.1s `GenerateStringSymbols`
    /// sich nachweislich verschluckt (DEL-121 Build-Saga, siehe dortige
    /// Kommentare). Lokal dupliziert statt geteilt, gleiche Begruendung wie
    /// dort: ein gemeinsamer Helper fuer so wenige Aufrufstellen lohnt
    /// keinen dritten Ort.
    private func pluralizedRecalculateToast(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }

    private func recalculateFromGenerator() {
        // Nachbesserung (P2.3-Review, Punkt 1+2): `recalculate` wirft jetzt,
        // wenn die Session-Sicherheitspruefung selbst fehlschlaegt (keine
        // Mutation in diesem Fall) — und meldet separat, wie viele Tage
        // wegen bestehender Trainingshistorie bewusst uebersprungen wurden
        // (konservativ, bis es eine Inhalts-/Versionsabsicherung dafuer
        // gibt), statt das in der Gesamtzahl verschwinden zu lassen.
        let message: String
        do {
            let summary = try PlanGeneratorInstantiator.recalculate(plan, in: modelContext)
            switch (summary.rewrittenCount, summary.skippedDueToHistoryCount) {
            case (0, 0):
                message = String(localized: "planEditor.recalculate.toast.none", bundle: .module)
            case (let rewritten, 0):
                message = pluralizedRecalculateToast("planEditor.recalculate.toast.rewritten", count: rewritten)
            case (0, let skipped):
                message = pluralizedRecalculateToast("planEditor.recalculate.toast.skipped", count: skipped)
            case (let rewritten, let skipped):
                message = pluralizedRecalculateToast("planEditor.recalculate.toast.rewritten", count: rewritten)
                    + ", " + pluralizedRecalculateToast("planEditor.recalculate.toast.skipped", count: skipped)
            }
        } catch {
            // Fail-safe (Punkt 1): kein Tag wurde angefasst — verstaendlicher
            // Fehlerzustand statt eines stillen No-Ops oder einer falschen
            // Erfolgsmeldung.
            message = String(localized: "planEditor.recalculate.toast.failed", bundle: .module)
        }
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

    /// UI-Refactor (Korrektur): rollt ALLE Formular-Felder vollstaendig
    /// zurueck, inklusive `targetEnvironment` (Migrations-Dialog bleibt
    /// waehrenddessen unterdrueckt, siehe `isApplyingSnapshot`), `isActive`
    /// und (Korrektur V1) die Tage-Reihenfolge. Bereits separat bestaetigte
    /// Migrationen (Adapt/Restore ueber die eigenen Dialoge oben) sind davon
    /// NICHT betroffen — die haben sich per `rebaselineTargetEnvironment()`
    /// schon als neue Baseline festgeschrieben, bevor dieser Pfad ueberhaupt
    /// erreichbar ist (siehe dort).
    private func revertToSnapshot() {
        // UI-Refactor (Korrektur, 2. Anlauf): das Flag NUR scharf schalten,
        // wenn sich `targetEnvironment` hier nachweislich aendert — sonst
        // feuert `.onChange(of: plan.targetEnvironment)` fuer diesen Aufruf
        // gar nicht, niemand konsumiert das Flag, und es bliebe `true`
        // haengen (wuerde dann faelschlich den NAECHSTEN echten User-Edit
        // unterdruecken). Siehe den `.onChange`-Handler oben fuer den
        // Konsum-Teil dieses Fixes.
        if plan.targetEnvironment != snapshot.targetEnvironment {
            isApplyingSnapshot = true
        }
        snapshot.apply(to: plan)
        // UI-Refactor (Korrektur V1): Tage, die beim Oeffnen schon da waren,
        // zurueck auf ihren urspruenglichen Wochentag — ignoriert seitdem
        // neu angelegte/geloeschte Tage (siehe `dayWeekdayAtOpen`-Doc).
        revertDayOrder(usingSnapshot: dayWeekdayAtOpen)
        // UI-Refactor (Korrektur V3): `snapshot.apply` schreibt `isActive`
        // immer auf den Baseline-Wert zurueck. `otherActivePlanIDAtOpen` ist
        // laut Invariante NUR gesetzt, wenn diese Baseline `false` war
        // (`setActive` haelt "hoechstens ein aktiver Plan" global ein) —
        // nach der Zeile oben ist `plan.isActive` in diesem Fall also
        // garantiert `false`. Deshalb reicht "ID vorhanden" als Bedingung:
        // war der andere Plan zwischenzeitlich (ob durch einmaliges An- oder
        // durch ein An-Aus-Toggle) nicht mehr aktiv, reaktiviert das hier
        // ihn wieder; war er es die ganze Zeit ueber noch, ist es ein
        // folgenloses No-Op.
        if let other = planToReactivateOnDiscard(otherActivePlanIDAtOpen: otherActivePlanIDAtOpen, amongCandidates: allPlans) {
            other.isActive = true
        }
        dismiss()
    }

    /// UI-Refactor (Korrektur V1): reine Rueckschreib-Logik mit explizitem
    /// `weekdayAtOpen`-Parameter statt direktem `@State`-Zugriff — testbar
    /// ohne lebende SwiftUI-Umgebung (siehe Tests/FitnessAppUITests).
    internal func revertDayOrder(usingSnapshot weekdayAtOpen: [PersistentIdentifier: Int]) {
        for day in plan.days {
            if let original = weekdayAtOpen[day.persistentModelID] {
                day.weekday = original
            }
        }
    }

    /// UI-Refactor (Korrektur V2): macht NUR `targetEnvironment` zur neuen
    /// Baseline — nicht den kompletten Snapshot. Aufgerufen direkt nachdem
    /// eine der eigenen, bereits explizit bestaetigten Umgebungs-Migrationen
    /// (Adapt/Restore) tatsaechlich gelaufen ist: dieses eine Feld (plus die
    /// migrierten Uebungen, die ohnehin ausserhalb von `snapshot` liegen)
    /// ist dann kein "ausstehender, per Verwerfen rueckrollbarer
    /// Formular-Edit" mehr. Ein volles Re-Capture wuerde hier faelschlich
    /// JEDE andere zu diesem Zeitpunkt noch offene Formular-Aenderung (z.B.
    /// `customName`) mit bestaetigen, obwohl der User die nie separat
    /// freigegeben hat — genau das "Ein vollstaendiges rebaselineSnapshot()
    /// darf nicht unbeabsichtigt andere offene Aenderungen mitbestaetigen"
    /// aus der Korrektur-Vorgabe. Ein reiner Picker-Wechsel ohne Migration
    /// (leerer Plan, oder "justEnv" ohne Anpassung) bleibt bewusst normal
    /// ueber `snapshot`/`isDirty` revertierbar — dort ist nichts inkonsistent
    /// zurueckzulassen.
    private func rebaselineTargetEnvironment() {
        snapshot.targetEnvironment = plan.targetEnvironment
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

    /// UI-Refactor (DeltiqHeader-Muster): Vergleich gegen `PlanMetaSnapshot`
    /// vom Oeffnen des Sheets — siehe dessen Scope-Begruendung oben. Plus
    /// (Korrektur V1/V3) die beiden Faelle, die ein reiner Feld-Vergleich
    /// nicht sieht: Tage-Reihenfolge und ein nur zwischenzeitlich
    /// umgeschalteter anderer aktiver Plan.
    private var isDirty: Bool {
        snapshot != PlanMetaSnapshot.capture(from: plan) || isDayOrderDirty || isOtherActivePlanStateDirty
    }

    /// UI-Refactor (Korrektur V1): true, wenn mindestens ein beim Oeffnen
    /// vorhandener Tag seitdem einen anderen Wochentag bekommen hat
    /// (Drag&Drop-Reorder, siehe `moveDays`). Neue/geloeschte Tage zaehlen
    /// bewusst nicht mit (siehe `dayWeekdayAtOpen`-Doc). Live-Property reicht
    /// nur `dayWeekdayAtOpen` durch — die eigentliche Pruefung steckt in der
    /// `internal` Funktion darunter, die ohne `@State`-Zugriff direkt testbar
    /// ist (siehe Tests/FitnessAppUITests).
    private var isDayOrderDirty: Bool {
        dayOrderIsDirty(comparedTo: dayWeekdayAtOpen)
    }

    /// UI-Refactor (Korrektur V1): reine Pruef-Logik mit explizitem
    /// `weekdayAtOpen`-Parameter statt direktem `@State`-Zugriff — testbar
    /// ohne lebende SwiftUI-Umgebung. Bewusst NICHT `isDayOrderDirty`
    /// genannt (anderer Name als die Property direkt darueber), um jede
    /// Zweideutigkeit zwischen Property- und Funktionsreferenz zu vermeiden.
    internal func dayOrderIsDirty(comparedTo weekdayAtOpen: [PersistentIdentifier: Int]) -> Bool {
        plan.days.contains { day in
            guard let original = weekdayAtOpen[day.persistentModelID] else { return false }
            return original != day.weekday
        }
    }

    /// UI-Refactor (Korrektur V3): faengt eine An-Aus-Toggle-Sequenz ab, die
    /// ein reiner `snapshot.isActive`-Vergleich nicht sieht. Beispiel: Plan A
    /// ist beim Oeffnen aktiv (`otherActivePlanIDAtOpen == A`, `snapshot.
    /// isActive == false`), User schaltet diesen Plan an (verdraengt A) und
    /// wieder aus — `plan.isActive` ist danach wieder `false`, identisch zur
    /// Baseline, obwohl A jetzt faelschlich inaktiv geblieben ist. Nur
    /// relevant, wenn dieser Plan selbst (wieder) inaktiv ist — ist er aktiv,
    /// meldet bereits der normale Feld-Vergleich oben "dirty". Nutzt dieselbe
    /// `planToReactivateOnDiscard`-Lookup wie `revertToSnapshot()`.
    private var isOtherActivePlanStateDirty: Bool {
        otherActivePlanStateIsDirty(otherActivePlanIDAtOpen: otherActivePlanIDAtOpen, amongCandidates: allPlans)
    }

    /// UI-Refactor (Korrektur post-Review): reine Entscheidungslogik, analog
    /// `planToReactivateOnDiscard` extrahiert (explizite Parameter statt
    /// `@State`/`@Query`, direkt testbar). `nil` (kein anderer Plan war beim
    /// Oeffnen aktiv) heisst explizit "keine Aenderung" — ein Vergleich wie
    /// `other?.isActive != true` waere hier falsch, da er bei `nil` ebenfalls
    /// `true` liefert und einen nie angefassten, inaktiven Plan faelschlich
    /// dirty meldet.
    internal func otherActivePlanStateIsDirty(
        otherActivePlanIDAtOpen: PersistentIdentifier?,
        amongCandidates candidates: [TrainingPlan]
    ) -> Bool {
        guard !plan.isActive,
              let other = planToReactivateOnDiscard(otherActivePlanIDAtOpen: otherActivePlanIDAtOpen, amongCandidates: candidates)
        else { return false }
        return !other.isActive
    }

    /// UI-Refactor (Korrektur V3): reine Entscheidungslogik fuer "welcher
    /// andere Plan muss beim Verwerfen reaktiviert werden" — `otherActive-
    /// PlanIDAtOpen` und die Plan-Liste als EXPLIZITE Parameter statt
    /// direktem `@State`/`@Query`-Zugriff, damit sie ohne lebende SwiftUI-/
    /// Query-Umgebung direkt testbar ist (siehe Tests/FitnessAppUITests).
    /// `nil` heisst "nichts zu tun" (kein anderer Plan beim Oeffnen
    /// betroffen, oder er ist nicht mehr auffindbar).
    internal func planToReactivateOnDiscard(
        otherActivePlanIDAtOpen: PersistentIdentifier?,
        amongCandidates candidates: [TrainingPlan]
    ) -> TrainingPlan? {
        guard let otherID = otherActivePlanIDAtOpen else { return nil }
        return candidates.first { $0.persistentModelID == otherID }
    }

    /// UI-Refactor (Korrektur): der Save-Checkmark muss immer ganz rechts
    /// erreichbar sein — darf weder durch den 2-Action-Cap verdraengt
    /// werden noch (waehrend des Reorder-Modus) Icon/Position mit einem
    /// "Reorder fertig"-Haekchen teilen. "Neu rechnen" (README 2.20) UND
    /// der Tage-Reorder-Toggle (DEL-095) wandern deshalb BEIDE in EIN
    /// Ellipsis-Menu — `saveAction` ist dadurch immer genau 1 der
    /// hoechstens 2 Actions und immer die LETZTE (am weitesten rechts,
    /// `ForEach(actions)` rendert in Array-Reihenfolge, siehe Theme.swift).
    private var headerActions: [DeltiqHeaderAction] {
        let menuAction = planMenuAction
        return menuAction != nil ? [menuAction!, saveAction] : [saveAction]
    }

    /// Ellipsis-Menu: "Neu rechnen" (nur fuer Plaene mit `generatorInput`),
    /// Reorder-Start/-Ende (nur iOS, nur wenn nicht readOnly und Tage
    /// vorhanden), plus (UI-Ticket "Mehr-Informationsarchitektur") immer
    /// "Uebungsbibliothek" — anders als die ersten beiden kein bedingter
    /// Eintrag, deshalb zeigt der Header ab jetzt IMMER dieses Menu (nicht
    /// mehr `nil`, wenn weder Neu-rechnen noch Reorder zutrifft).
    private var planMenuAction: DeltiqHeaderAction? {
        let showsRecalculate = plan.generatorInput != nil
        #if os(iOS)
        let isEditing = editMode?.wrappedValue.isEditing == true
        let showsReorder = !isReadOnly && !plan.days.isEmpty
        #else
        let isEditing = false
        let showsReorder = false
        #endif
        return DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            if showsRecalculate {
                Button {
                    recalculateFromGenerator()
                } label: {
                    Label {
                        Text("planEditor.recalculate.action", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            #if os(iOS)
            if showsReorder {
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
            }
            #endif
            Button {
                showingExerciseLibrary = true
            } label: {
                Label {
                    Text("planBuilder.exerciseLibrary.action", bundle: .module)
                } icon: {
                    Image(systemName: "books.vertical")
                }
            }
        })
    }

    /// UI-Refactor (DeltiqHeader-Muster): Autosave-Screen (siehe
    /// `ExerciseEditorView`). Ruft seit dem Plan-Editor-Persistenzbugfix
    /// `saveAndDismiss()` auf (siehe dortige Dokumentation) — vorher war das
    /// ein reines "Fertig" ohne eigenen Speicher-Schritt. Kein Validitaets-
    /// Gate auf diesem Screen → kein `isDisabled`.
    private var saveAction: DeltiqHeaderAction {
        DeltiqHeaderAction(
            systemImage: "checkmark",
            accessibilityLabel: String(localized: "common.done", bundle: .module)
        ) {
            saveAndDismiss()
        }
    }

    /// Bugfix (Plan-Editor-Persistenzbug, derselbe Musterfehler wie beim
    /// Day-Editor, siehe `DayEditorView.saveAndDismiss()`): `plan` ist
    /// `@Bindable` und wurde von allen Formular-Feldern (Wochen-Stepper,
    /// Trainingsort-Picker, Name-Feld, Active-Toggle, Progressions-RIR, ...)
    /// bereits direkt im Live-Objektgraphen mutiert, BEVOR der Haekchen-Tap
    /// hier ankommt. `@Bindable` ruft dabei selbst NIE `context.save()` auf
    /// — die Typ-Doku oben an `DayRow`/dieser View nannte das faelschlich
    /// "autosaved direkt in SwiftData". Der implizite SwiftData-Autosave ist
    /// nicht zuverlaessig garantiert, VOR einem direkt anschliessenden
    /// Kaltstart/App-Kill schon gelaufen zu sein. Ein fehlgeschlagener Save
    /// dismisst deshalb jetzt NICHT mehr — der User soll nicht glauben,
    /// seine Aenderung sei gesichert, waehrend sie es nicht ist (sichtbarer
    /// Fehlerhinweis ueber den bereits bestehenden `showTransientToast`-Pfad
    /// statt eines irrefuehrenden "Fertig"). Die bereits mutierten Felder
    /// bleiben dabei unveraendert im Objektgraphen stehen (kein Revert) —
    /// `isDirty` vergleicht weiterhin gegen `snapshot` und bleibt deshalb
    /// nach einem fehlgeschlagenen Save korrekt `true`, der Discard-Dialog
    /// bleibt also intakt. Erneutes Tippen ruft `context.save()` einfach
    /// nochmal auf demselben, bereits mutierten Objekt auf — ein Update,
    /// kein Insert, also idempotent (kein Duplikat, kein zweiter Datensatz).
    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            showTransientToast(String(localized: "planEditor.save.failed", bundle: .module))
        }
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
                    .background(Color.deltiqOrange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("planEditor.template.banner.title", bundle: .module)
                        .font(.body.weight(.semibold))
                    Text("planEditor.template.banner.subtitle", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    /// Eyebrow-Stil statt der nativen List-Section-Header-Konvention
    /// (Caps-Grau). `.textCase(nil)` verhindert, dass List den bereits
    /// grossgeschriebenen String noch einmal automatisch transformiert.
    private func sectionHeader(_ key: String) -> some View {
        Text(String(localized: String.LocalizationValue(stringLiteral: key), bundle: .module).uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Color.deltiqOrange)
            .textCase(nil)
    }

    /// DEL-035: nur noch der Plan-Name in der Meta-Section. `programType` ist
    /// ein interner Identifier (z.B. "full_body", "ppl") fuer Recommendation-
    /// Logik und gehoert nicht ins User-UI. `descriptionText` lebt nur im
    /// Template-Picker, im PlanEditor unnoetig.
    private var metaSection: some View {
        Section {
            // DEL-125: customName + localizedSystemName-Placeholder.
            TextField(
                text: Binding(
                    get: { plan.customName ?? "" },
                    set: { plan.customName = $0.isEmpty ? nil : $0 }
                ),
                prompt: Text(plan.localizedSystemName)
            ) {
                Text("day.editor.field.name", bundle: .module)
            }
            .font(.system(size: 15))
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader("planEditor.section.info")
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// Equipment-Vielfalt Phase 1 Task 4: macht eine Equipment-Luecke auf
    /// einem BEREITS GESPEICHERTEN Plan sichtbar, nicht nur in der Adopt-
    /// Vorschau (Decision 1 — warnen, nicht blockieren). Computed property,
    /// bei JEDEM `body`-Render frisch aus der bestehenden `userProfiles`-
    /// Query gelesen (gleiches Prinzip wie `ProgramTemplatePickerView.
    /// resolvedSelection`/`equipmentStatusBanner`) — NIEMALS in `@State`
    /// zwischengespeichert, damit eine Profil-Aenderung an anderer Stelle
    /// sofort hier ankommt.
    /// Final-Review Fix 3: muss denselben EFFEKTIVEN Kontext wie
    /// `ProgramTemplatePickerView.equipmentPlanningContext` nutzen, nicht das
    /// rohe, individuelle Profil — sonst liest ein Default-User ohne eigene
    /// Einrichtung (`equipmentProfile` komplett `.unknown`) hier faelschlich
    /// jede annotierte Uebung als "unsicher" und zeigt die harte Luecken-
    /// Warnung dauerhaft an, obwohl der Picker fuer denselben Fall nur die
    /// neutrale "Annahme"-Anzeige zeigt (siehe `EquipmentPlanningResolver`).
    private var equipmentPlanningContext: EquipmentPlanningContext? {
        guard let profile = userProfiles.first else { return nil }
        return EquipmentPlanningResolver.resolve(
            environment: profile.environment,
            individualProfile: profile.equipmentProfile,
            confirmedComplete: profile.equipmentProfileConfirmedComplete
        )
    }

    private var equipmentGapReport: PlanEquipmentReport? {
        guard let context = equipmentPlanningContext, !context.isAssumption else { return nil }
        return SavedPlanEquipmentCheck.report(for: plan, against: context.effectiveProfile)
    }

    @ViewBuilder
    private var equipmentGapSection: some View {
        if let report = equipmentGapReport, !report.isFullyAvailable {
            Section {
                DeltiqCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("planEditor.equipmentGap.title", bundle: .module)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(String(format: String(localized: "planEditor.equipmentGap.detail", bundle: .module), equipmentGapExerciseNames(report).joined(separator: ", ")))
                                .font(.footnote)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    /// Dieselbe Formatierung wie `ProgramTemplatePickerView.missingGapDetail`
    /// im Prinzip (konkrete Uebungen nennen statt pauschal "Equipment fehlt")
    /// — hier auf Uebungsnamen statt Geraete-Items, weil `PlanEquipmentReport`
    /// pro Uebung, nicht pro Geraet aggregiert.
    private func equipmentGapExerciseNames(_ report: PlanEquipmentReport) -> [String] {
        (report.missing + report.uncertain).map(\.exerciseName)
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
                        .foregroundStyle(Color.Deltiq.textSecondary)
                } label: {
                    Text("planEditor.field.weeks", bundle: .module)
                        .font(.system(size: 15))
                }
            }
            .listRowBackground(Color.Deltiq.surface)

            Picker(selection: $plan.targetEnvironment) {
                Text("environment.gym", bundle: .module).tag(EnvironmentType.gym)
                Text("environment.home_gym", bundle: .module).tag(EnvironmentType.homeGym)
                Text("environment.no_equipment", bundle: .module).tag(EnvironmentType.noEquipment)
            } label: {
                Text("onboarding.field.environment", bundle: .module)
                    .font(.system(size: 15))
            }
            .listRowBackground(Color.Deltiq.surface)

            Toggle(isOn: Binding(
                get: { plan.isActive },
                set: { setActive($0) }
            )) {
                Text("planEditor.toggle.setActive", bundle: .module)
                    .font(.system(size: 15))
            }
            .tint(Color.deltiqOrange)
            .listRowBackground(Color.Deltiq.surface)

            // DEL-053 — globaler Plan-Override fuer die RIR-Schwelle der
            // Smart-Progression: der letzte Satz muss mindestens so viele
            // Wiederholungen in Reserve gehabt haben (`lastSet.rir >=
            // Schwelle`). Auto = pro-Uebung-Default (Compound: RIR>=2,
            // Isolation: RIR>=1). User kann den Override hier auf einen
            // strengeren Wert setzen, z.B. RIR>=3 fuer alle Uebungen.
            Picker(selection: progressionRIRBinding) {
                Text("planEditor.progressRIR.auto", bundle: .module).tag(Optional<Float>.none)
                Text("planEditor.progressRIR.rir0", bundle: .module).tag(Optional<Float>.some(0))
                Text("planEditor.progressRIR.rir1", bundle: .module).tag(Optional<Float>.some(1))
                Text("planEditor.progressRIR.rir2", bundle: .module).tag(Optional<Float>.some(2))
                Text("planEditor.progressRIR.rir3", bundle: .module).tag(Optional<Float>.some(3))
            } label: {
                Text("planEditor.progressRIR.label", bundle: .module)
                    .font(.system(size: 15))
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            sectionHeader("planEditor.section.settings")
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
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
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
            } else if isReadOnly {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
                // onDelete bewusst NICHT registriert — Template-Tage sind gesetzt
            } else {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
                .onMove(perform: moveDays)
                .onDelete(perform: deleteDays)
            }
        } header: {
            HStack {
                sectionHeader("planEditor.section.trainingDays")
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
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.deltiqOrange)
                            .font(.system(size: 18))
                    }
                    .accessibilityLabel(Text("common.add", bundle: .module))
                }
            }
        } footer: {
            Text(isReadOnly
                 ? "planEditor.days.footer.template"
                 : "planEditor.days.footer.user",
                 bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
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
            // P6.1: eine echte Re-Aktivierung ueber diesen Schalter ist ein
            // neuer, realer Zeitpunkt — kein erfundenes Datum. Wird bei
            // einem Discard der gesamten Editor-Sitzung zusammen mit
            // `isActive` wieder auf den Baseline-Wert zurueckgesetzt (siehe
            // `PlanMetaSnapshot`), ueberlebt also nur bei tatsaechlicher
            // Bestaetigung.
            plan.activatedAt = Date()
        }
        plan.isActive = active
    }

    /// Legt einen neuen Tag (Trainings- ODER Ruhetag) im Plan an. Bei
    /// Trainingstagen navigieren wir direkt in den DayEditor, damit der User
    /// gleich Uebungen hinzufuegen kann. Ruhetage werden nur in der Liste
    /// gespeichert — kein Editor noetig.
    private func createNewDay(type: DayType) {
        // Bugfix (Audit): ein numerisches max() ueber `weekday` behandelt
        // Sonntag (1) faelschlich als kleinsten statt letzten Wochentag
        // (siehe `PlanNavigator.sortByWeekdayMondayFirst`) - bei einem Plan
        // mit Samstag(7)+Sonntag(1) landete der naechste Tag wieder auf
        // Sonntag statt auf dem tatsaechlich freien Montag. Erster freier
        // Wochentag in Montag-first-Reihenfolge, sonst deterministischer
        // Fallback ueber die Tagesanzahl.
        let mondayFirstCycle = [2, 3, 4, 5, 6, 7, 1]
        let usedWeekdays = Set(plan.days.map(\.weekday))
        let nextWeekday = mondayFirstCycle.first { !usedWeekdays.contains($0) }
            ?? mondayFirstCycle[plan.days.count % mondayFirstCycle.count]
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

    /// TestingBot-Regressionscheck (Block A, Deltiq-Abnahme) fand denselben
    /// Musterfehler in `PlansListView.deletePlans` (siehe dortige Doku):
    /// Loeschen ohne sofortigen `context.save()` verlaesst sich auf
    /// SwiftDatas impliziten Autosave und kann einen kurz danach folgenden
    /// Kaltstart nicht ueberstehen — ein Tag mit laufender Session nullifiziert
    /// dabei genau wie ein ganzer Plan. Gleicher Fix, gleiche Begruendung
    /// gegen `context.rollback()` (siehe `PlansListView.deletePlans`).
    private func deleteDays(at offsets: IndexSet) {
        let toDelete = offsets.map { orderedDays[$0] }
        for day in toDelete {
            modelContext.delete(day)
        }
        do {
            try modelContext.save()
        } catch {
            showTransientToast(String(localized: "planEditor.day.delete.saveFailed", bundle: .module))
        }
    }

    /// Gemeinsamer Helfer fuer die bestehende `swapResultToast`-Konvention
    /// (siehe `switchPlanEnvAndAdd`) — identisches Muster wie
    /// `DayEditorView.showTransientToast`.
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
        // UI-Refactor (Korrektur V2): diese Migration ist bereits ueber ihren
        // eigenen Dialog explizit bestaetigt — ab jetzt neue Baseline statt
        // ausstehender, nur per Discard scheinbar rueckrollbarer Aenderung.
        // Nur das betroffene Feld, siehe Doc an `rebaselineTargetEnvironment`.
        rebaselineTargetEnvironment()
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
        rebaselineTargetEnvironment()
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
                    .font(.system(size: 12, weight: .bold))
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)
                // DEL-123: format-string via xcstrings statt hardcoded DE.
                Text(String(format: String(localized: "plan.dayRow.exerciseCount", bundle: .module),
                            day.activeExercises.count,
                            intensityLabel(day.nextIntensity)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
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

/// UI-Refactor (Korrektur): `TrainingPlan` ist `@Bindable` — die Bindings
/// mutieren den LIVE-Objektgraphen sofort, aber `@Bindable` ruft dabei
/// selbst NIE `context.save()` auf (siehe `PlanEditorView.saveAndDismiss()`
/// fuer den Persistenzbugfix, der diese frueher hier stehende, falsche
/// "autosaved direkt in SwiftData"-Annahme korrigiert hat). Deckt ALLE
/// Formular-Felder ab (inklusive `targetEnvironment`/`isActive`) — siehe die
/// Begruendung bei `PlanEditorView.snapshot`/`revertToSnapshot()`.
/// `internal` statt `private`, damit gezielte Tests (siehe
/// `Tests/FitnessAppUITests`) die Capture/Apply-Logik per `@testable import`
/// direkt pruefen koennen.
@available(iOS 17.0, macOS 14.0, *)
struct PlanMetaSnapshot: Equatable {
    var customName: String?
    var weeks: Int
    var progressionTargetRIROverride: Float?
    var targetEnvironment: EnvironmentType
    var isActive: Bool
    /// P6.1: muss zusammen mit `isActive` erfasst/zurueckgeschrieben werden
    /// — sonst wuerde ein verworfener Re-Aktivierungs-Tap (`setActive(true)`
    /// stempelt sofort `Date()`, siehe dort) beim Discard zwar `isActive`,
    /// nicht aber den dabei gesetzten Zeitstempel zuruecksetzen.
    var activatedAt: Date?

    static func capture(from plan: TrainingPlan) -> PlanMetaSnapshot {
        PlanMetaSnapshot(
            customName: plan.customName,
            weeks: plan.weeks,
            progressionTargetRIROverride: plan.progressionTargetRIROverride,
            targetEnvironment: plan.targetEnvironment,
            isActive: plan.isActive,
            activatedAt: plan.activatedAt
        )
    }

    func apply(to plan: TrainingPlan) {
        plan.customName = customName
        plan.weeks = weeks
        plan.progressionTargetRIROverride = progressionTargetRIROverride
        plan.targetEnvironment = targetEnvironment
        plan.isActive = isActive
        plan.activatedAt = activatedAt
    }
}
#endif
