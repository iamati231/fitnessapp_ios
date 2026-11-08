#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

/// Top-level list of training plans plus a banner for any in-flight workout session.
/// New plans are created with sensible defaults and pushed straight into the editor.
@available(iOS 17.0, macOS 14.0, *)
public struct PlansListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    /// Single-key @Query (sort by name) + in-memory secondary sort by `isActive`.
    /// SortDescriptor with a Bool key-path requires `Compared : NSObject`, which
    /// SwiftData @Model classes are NOT — so multi-descriptor arrays don't compile
    /// on macOS toolchains. Client-side sort is the cleanest workaround.
    @Query(sort: \TrainingPlan.name)
    private var plansByName: [TrainingPlan]

    private var plans: [TrainingPlan] {
        plansByName.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.name < rhs.name
        }
    }

    @Query(filter: #Predicate<WorkoutSession> { !$0.isCompleted },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var activeSessions: [WorkoutSession]

    @Query private var profiles: [UserBodyProfile]

    @State private var showingTemplatePicker = false
    @State private var showingPlanBuilder = false

    /// TestingBot-Regressionscheck (Block A, Deltiq-Abnahme): `deletePlans`
    /// verliess sich bislang rein auf SwiftDatas impliziten Context-
    /// Autosave — derselbe Musterfehler wie bei
    /// `DayEditorView.deleteExercises` (siehe dortige Typ-Doku,
    /// `TrainingDayContentSnapshotWriterTests.testCapturePersistsWithoutAnyAdditionalCallerSave`).
    /// Reproduziert: Plan mit laufender Session loeschen, sofort Force-Quit
    /// + Kaltstart — die Loeschung war auf der Store-Datei nie angekommen,
    /// Plan UND Session waren nach dem Neustart wieder da. Jetzt expliziter
    /// Save direkt nach dem Delete; non-nil zeigt den Alert unten.
    @State private var deletePlanErrorMessage: String?

    public init() {}

    public var body: some View {
        // Signature-Geruest: eigene Kopfzone statt navigationTitle/Toolbar;
        // "Pläne" ist der Screen-Titel, "Plan" bleibt die Eyebrow (Tab-Name).
        // `List` bleibt Container (Swipe-Duplizieren + onDelete brauchen sie,
        // siehe DEL-070) - anders als Rechner/Bibliothek, die komplett auf
        // ScrollView+DeltiqSection wechseln, weil sie keine dieser Gesten
        // benoetigen.
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                title: String(localized: "plans.list.title", bundle: .module),
                actions: [
                    DeltiqHeaderAction(systemImage: "plus", menu: {
                        Button {
                            showingTemplatePicker = true
                        } label: {
                            Label {
                                Text("plans.create.fromTemplate", bundle: .module)
                            } icon: {
                                Image(systemName: "rectangle.stack.fill.badge.plus")
                            }
                        }
                        Button {
                            showingPlanBuilder = true
                        } label: {
                            Label {
                                Text("plans.create.fromBuilder", bundle: .module)
                            } icon: {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        Button {
                            createNewPlan()
                        } label: {
                            Label {
                                Text("plans.create.empty", bundle: .module)
                            } icon: {
                                Image(systemName: "plus")
                            }
                        }
                    })
                ]
            )

            plansContextRow

            List {
                if let active = activeSessions.first {
                    activeSessionSection(active)
                }

                plansSection
            }
            .scrollContentBackground(.hidden)
            // Nachtrag 6. August (README 2.6): plansContextRow sass vorher als
            // erste List-Row hier drin - 12pt eigener Top-Inset plus der
            // Standard-Top-Einzug der List addierten sich zu ~60pt statt der
            // ueblichen 12pt unter der Kopfzeile. Jetzt lebt die Kontextzeile
            // ausserhalb der List (siehe oben), also muss deren Top-Einzug weg.
            .contentMargins(.top, 0, for: .scrollContent)
            // Der seitliche Einzug der List wird ebenfalls entfernt - Banner
            // und Plan-Karten tragen ihre 16pt jetzt selbst ueber
            // listRowInsets, ein zusaetzlicher List-Einzug wuerde beide
            // Karten schmaeler als 16pt machen.
            .contentMargins(.horizontal, 0, for: .scrollContent)
            // CI-Fix: .listSectionSpacing ist iOS/tvOS/watchOS-only und auf
            // macOS (dieses Target baut fuer beide, siehe Release-Gate) gar
            // nicht deklariert - harter Compile-Error statt @available-Warnung.
            #if os(iOS)
            .listSectionSpacing(.compact)
            #endif
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingTemplatePicker) {
            ProgramTemplatePickerView()
        }
        .sheet(isPresented: $showingPlanBuilder) {
            PlanBuilderView()
        }
        .alert(
            Text("plans.delete.error.title", bundle: .module),
            isPresented: Binding(
                get: { deletePlanErrorMessage != nil },
                set: { if !$0 { deletePlanErrorMessage = nil } }
            )
        ) {
            Button("OK") { deletePlanErrorMessage = nil }
        } message: {
            Text(deletePlanErrorMessage ?? "")
        }
    }

    // MARK: - Kontextzeile

    /// Aktiver Plan (Accent-Pill, ungeprefixt — identische Darstellung wie
    /// der Plan-Name auf dem Dashboard) + Gesamt-Anzahl (neutral). Beide
    /// Pills entfallen einzeln, wenn der jeweilige Fakt nicht existiert;
    /// die ganze Zeile entfaellt, wenn noch gar keine Plaene da sind (dann
    /// uebernimmt `emptyState` die Erklaerung).
    @ViewBuilder
    private var plansContextRow: some View {
        if !plans.isEmpty {
            let activeName = plans.first(where: \.isActive)?.displayName
            DeltiqContextRow([
                activeName.map { DeltiqContextItem($0.uppercased(), style: .accent) },
                DeltiqContextItem(pluralizedCount("plans.context.count", count: plans.count).uppercased(), style: .neutral)
            ].compactMap { $0 })
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    /// Gleiches manuelles .one/.other-Muster wie `PlanRow.pluralized` (siehe
    /// DEL-121/DEL-128) — hier lokal dupliziert, weil `PlanRow` ein separater
    /// privater Typ ist und ein gemeinsamer Helper fuer zwei Zeilen Code
    /// keinen dritten Ort rechtfertigt.
    private func pluralizedCount(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // MARK: - Laufendes Training

    /// Einzige Akzent-Kante des Screens (siehe 1.4, max. 1 pro Screen) — die
    /// laufende Session ist die dringendste Aktion hier. `DeltiqCard` laesst
    /// sich direkt als List-Row einbetten; `.listRowBackground(.clear)` +
    /// `.listRowSeparator(.hidden)` unterdruecken Listens eigenes Zeilen-
    /// Chrome, damit nur die Karten-Optik sichtbar bleibt.
    ///
    /// Simulator-Befund (Light Mode, 5. August): ein `NavigationLink`
    /// zeichnet in einer `List` IMMER seinen eigenen nativen Chevron dazu,
    /// egal welcher ButtonStyle gesetzt ist — zusammen mit
    /// `ActiveSessionBanner`s eigenem, handgebautem Chevron ergab das zwei
    /// Pfeile nebeneinander. Ein simpler `Button`, der `navigation.
    /// workoutPath` (dieselbe Path-Instanz, die auch `WorkoutRootView`s
    /// `.navigationDestination(for: ActiveSessionRoute.self)` bedient)
    /// direkt befuellt, navigiert identisch — nur ohne den nativen Chevron.
    private func activeSessionSection(_ session: WorkoutSession) -> some View {
        Group {
            Button {
                navigation.workoutPath.append(ActiveSessionRoute(session: session))
            } label: {
                DeltiqCard(accentEdge: true) {
                    ActiveSessionBanner(session: session)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Text("plans.active.hint", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
        }
    }

    // MARK: - Plaene

    /// Bugfix (Crash, TestFlight 0.1.0/175): extracted so `PlanRow` never
    /// holds a live `TrainingPlan` reference of its own (see
    /// `PlanRowItem`/`PlanRowContent` doc below). Only re-evaluates in
    /// reaction to `plansByName`'s own `@Query` refiring, so a plan is only
    /// ever read here while it is still a confirmed row of the live query
    /// results — never while it's mid-deletion.
    private var planRows: [PlanRowItem] {
        plans.map { PlanRowItem(plan: $0, content: PlanRowContent($0)) }
    }

    /// Kein `header:` — "Pläne" ist bereits der Screen-Titel in der
    /// Kopfzone, eine zweite identische Ueberschrift waere redundant (vgl.
    /// CalculatorsView, deren einzige Sektion aus demselben Grund
    /// unbetitelt bleibt).
    @ViewBuilder
    private var plansSection: some View {
        if planRows.isEmpty {
            emptyState
        } else {
            ForEach(planRows) { item in
                // Nachtrag 6. August, abends (README 2.10/19a): ein
                // `NavigationLink` zeichnet in einer `List` IMMER seinen
                // eigenen nativen Chevron dazu - der sitzt dann ausserhalb
                // der `DeltiqCard`, im Leerraum der Zeile, statt darin wie
                // beim Session-Banner. Gleicher Fix wie bei
                // `activeSessionSection` oben: `Button`, der dieselbe
                // Path-Instanz befuellt, plus handgezeichneter Chevron IN
                // `PlanRow`.
                Button {
                    navigation.workoutPath.append(item.plan)
                } label: {
                    // Nachtrag 6. August (README 2.6): ein blosses
                    // .listRowBackground(Color.Deltiq.surface) uebernimmt nur
                    // die Flaeche, nicht unseren 20pt-Karten-Radius - die Zeile
                    // fuellte vorher die vollen List-Insets und war schmaeler
                    // als die 16pt-Vorgabe, dazu mit dem falschen Radius.
                    // Eine echte DeltiqCard plus dieselben Insets wie das
                    // Banner (siehe activeSessionSection) gleicht beide an.
                    DeltiqCard {
                        PlanRow(content: item.content)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                // DEL-070: Swipe-Action "Duplizieren" — User kann eine
                // Variation seines aktiven Plans bauen, ohne das Original
                // zu zerschiessen. Loescht keine Daten, daher Orange statt
                // einer destruktiven Farbe.
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        duplicatePlan(item.plan)
                    } label: {
                        Label {
                            Text("plans.duplicate", bundle: .module)
                        } icon: {
                            Image(systemName: "plus.square.on.square")
                        }
                    }
                    .tint(Color.deltiqOrange)
                }
            }
            .onDelete(perform: deletePlans)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange.opacity(0.85))
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("plans.empty.title", bundle: .module)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                Text("plans.empty.hint", bundle: .module)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                // DEL-046: vorher `rectangle.stack.fill.badge.plus` — das
                // gerenderte SF-Symbol war auf `.borderedProminent` un-
                // sichtbar (vermutlich wegen `.badge.plus`-Komposition
                // + Tint-Override). `list.bullet.clipboard` rendert sauber
                // und harmonisiert visuell mit dem `+` des Leer-Buttons.
                Button {
                    showingTemplatePicker = true
                } label: {
                    Label {
                        Text("plans.create.fromTemplateShort", bundle: .module)
                    } icon: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()

                Button {
                    createNewPlan()
                } label: {
                    Label {
                        Text("plans.create.emptyShort", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .buttonStyle(.plain)
                .deltiqSecondaryButtonStyle()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Color.Deltiq.surface)
        // Haelt die 16pt Seitenrand, jetzt wo .contentMargins(.horizontal, 0, ...)
        // den eigenen Einzug der List oben entfernt (siehe body).
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    // MARK: Actions

    /// P2.3: einer der vier sanktionierten Pfade, mit denen ein Plan die
    /// Datenbank beruehrt (siehe `PlanGeneratorInstantiator`-Typ-Doku) — hier
    /// "Neuen (leeren) Plan erstellen", ohne Generator/Template. Nutzt
    /// bewusst KEINE eigene Aktivierungs-Logik aus `ProgramInstantiator`
    /// (direkter Insert statt `instantiate`), da ein leerer Plan keine
    /// Tage/Uebungen hat, die dessen Wochentag-/Equipment-Aufloesung
    /// braeuchten.
    private func createNewPlan() {
        let plan = TrainingPlan(
            name: TrainingPlan.blankPlanName,
            weeks: 12,
            isActive: plans.isEmpty,                       // first plan is active by default
            targetEnvironment: .gym,
            // `name` bleibt der deutsche System-Name (Namens-Lookups), die
            // Anzeige kommt ueber den Katalog: "New Plan" / "Yeni Plan".
            localizationKey: TrainingPlan.blankPlanLocalizationKey
        )
        modelContext.insert(plan)
        // Audit-Fix (Save-Fehler): fehlender context.save() nach dem Insert -
        // derselbe Musterfehler wie `ProgramTemplatePickerView.instantiate`.
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(plan)
            deletePlanErrorMessage = error.localizedDescription
            return
        }
        navigation.workoutPath.append(plan)
    }

    /// TestingBot-Geraetebefund (Deltiq-Abnahme, Punkt 1): Loeschen eines
    /// Plans mit laufender (nicht abgeschlossener) Session crasht auf
    /// echtem Geraet reproduzierbar mit einem SwiftData-internen, nicht
    /// per do/catch fangbaren Fatal-Error ("Context is missing for ...
    /// TrainingDay/pN"). Vier gerätegetestete interne Fixes haben das NICHT
    /// behoben (siehe Git-Historie `deletePlans`-Commits) — Nutzerentscheid:
    /// die Loeschung stattdessen auf UI-Ebene verhindern, statt den
    /// SwiftData-Fehler weiter zu suchen.
    internal static func plansBlockedByActiveSession(_ plans: [TrainingPlan]) -> [TrainingPlan] {
        plans.filter { plan in
            plan.days.contains { day in day.sessions.contains { !$0.isCompleted } }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        let plansToDelete = offsets.map { plans[$0] }
        guard Self.plansBlockedByActiveSession(plansToDelete).isEmpty else {
            deletePlanErrorMessage = String(localized: "plans.delete.blockedActiveSession", bundle: .module)
            return
        }
        // Bugfix (Geräte-Nachweis, TestingBot): Löschen des AKTIVEN Plans
        // crashte reproduzierbar (App faellt auf den Home-Screen zurueck) —
        // ein zweiter, von der PlanRow-Loesung oben nicht abgedeckter Crash-
        // Pfad. `DashboardView` (als Tab-Geschwister staendig im Speicher,
        // SwiftUI's `TabView` haelt alle Tabs aktiv) liest an >10 Stellen
        // direkt `activePlans.first`-Properties (`.displayName`, `.days`,
        // tief verschachtelt bis zu `.activeExercises`) — exakt dieselbe
        // Gefahrenklasse wie der `PlanRow`-Crash oben, nur in einer fuer
        // einen vollstaendigen Werte-Schnappschuss viel zu grossen, tief
        // verschachtelten View (kein kleiner, gezielter Fix dort moeglich,
        // ohne Dashboards gesamte Plan-/Tag-/Uebungs-Logik umzubauen).
        // Fix nach demselben bereits bewaehrten Muster wie `session.day =
        // nil` vor einem Plan-Delete (siehe Git-Historie dieser Datei,
        // Commit "SwiftData 'Context is missing'"): die abhaengige
        // Eigenschaft (`isActive`) SYNCHRON, VOR jedem Save, auf den
        // sicheren Wert setzen. SwiftData/`@Query` spiegeln In-Memory-
        // Aenderungen am Context sofort wider, auch vor einem `save()` —
        // jeder nachfolgende Lesezugriff auf `activePlans` (gleich durch
        // welchen Ausloeser: den Query-eigenen Refresh ODER eine durch die
        // Objekt-Invalidierung erneut aufgerufene Dashboard-`body`) sieht
        // diesen Plan dann bereits als inaktiv und `activePlans.first`
        // liefert ihn nicht mehr — die riskanten Properties werden nie
        // mehr gelesen.
        //
        // Nachtrag (echter TestingBot-Crash-Log, Loeschen des LETZTEN/
        // einzigen Plans): dieser `isActive`-Fix deckt nur Lesezugriffe ab,
        // die auf DERSELBEN Ebene wie `activePlans.first` liegen. Ein
        // bereits VOR dem Delete gerendertes, tief verschachteltes
        // ViewBuilder-Closure (`DashboardView.exercisesList`, liest
        // `day.activeExercises`) kann SwiftUI/Observation unabhaengig davon
        // erneut aufrufen, sobald die geloeschte `TrainingDay`-Relationship
        // selbst ihre Aenderung meldet — das war entgegen der obigen Doku
        // doch ein kleiner, gezielter Fix: siehe `PlanDayExerciseItem` in
        // `DashboardView.swift`.
        for plan in plansToDelete where plan.isActive {
            plan.isActive = false
        }
        for plan in plansToDelete {
            for day in plan.days {
                modelContext.delete(day)
            }
        }
        do {
            try modelContext.save()
        } catch {
            deletePlanErrorMessage = error.localizedDescription
            return
        }
        for plan in plansToDelete {
            modelContext.delete(plan)
        }
        // Kein `context.rollback()` bei Fehler — wirkt auf den GESAMTEN,
        // geteilten Context und wuerde unabhaengige, anderswo bereits
        // bestaetigte Aenderungen mit zerstoeren (siehe
        // `PlanGeneratorInstantiator`-Typ-Doku, gleiche Begruendung wie
        // `DayEditorView.deleteExercises`). Stattdessen nur sichtbarer
        // Fehlerhinweis — der User sieht den Plan in der Liste weiterhin
        // als entfernt, auch wenn der Save scheiterte, und kann es erneut
        // versuchen.
        do {
            try modelContext.save()
        } catch {
            deletePlanErrorMessage = error.localizedDescription
        }
    }

    /// P2.3: einer der vier sanktionierten Pfade (siehe
    /// `PlanGeneratorInstantiator`-Typ-Doku) — "Bewusst eine neue Kopie
    /// erstellen". Bewusst NICHT in den dortigen Service verschoben: es gibt
    /// hier nur EINE Implementierung (nichts zu konsolidieren), ein Umzug
    /// waere Umbau ohne behobene Duplikation.
    ///
    /// DEL-070: Tiefkopie des Plans inkl. Tagen, Uebungen und allen
    /// Trainings-Parametern. Die Kopie startet als `isActive = false`
    /// (User soll bewusst entscheiden, ob er auf die Variante umschaltet)
    /// und bekommt einen "(Kopie)"-Suffix im Namen.
    ///
    /// `isTemplate` bleibt `false` — Templates sind Read-Only-Library-
    /// Seeds, eine User-Duplikat wandert in den editierbaren Plan-Bestand.
    /// Archivierte Snapshot-Uebungen (DEL-049 swappedFromOriginal) werden
    /// NICHT mit-kopiert — die Kopie startet "frisch", ohne Urlaubs-Modus-
    /// Geister.
    private func duplicatePlan(_ source: TrainingPlan) {
        // DEL-123: localizationKey wird beim Kopier-Vorgang nicht uebernommen,
        // damit der "(Kopie)"-Suffix sichtbar bleibt — sonst wuerde der
        // duplizierte Plan den lokalisierten Original-Namen rendern und der
        // User koennte beide Kopien nicht unterscheiden. Custom-Name "X (Kopie)"
        // geht durch den name-Fallback in TrainingPlan.displayName.
        let copy = TrainingPlan(
            name: "\(source.displayName) (Kopie)",
            programType: source.programType,
            descriptionText: source.descriptionText,
            weeks: source.weeks,
            isActive: false,
            targetEnvironment: source.targetEnvironment,
            isTemplate: false
        )
        copy.progressionTargetRIROverride = source.progressionTargetRIROverride
        modelContext.insert(copy)

        for day in source.days {
            // DEL-123: Tag-localizationKey schon — die Kopie ist strukturell
            // identisch und behaelt das Template-Origin.
            // Bugfix (Audit): customName/timeFormat/timeCapMinutes fehlten -
            // ein User-umbenannter Tag verlor seinen Namen, ein Zeitformat-Tag
            // (AMRAP/EMOM/Auf Zeit) sein Format komplett (Routing landete nach
            // dem Duplizieren faelschlich in ActiveWorkoutView statt
            // TimedWorkoutPlayerView).
            // Bugfix (Review-Fund, Zirkel-Feature): dieselbe Luecke fuer die
            // drei neuen Zirkel-Felder - ohne sie verlor ein dupliziertes
            // .circuit-Tag Rundenzahl/Pause/Modus und fiel stillschweigend
            // auf die generischen Defaults zurueck.
            let dayCopy = TrainingDay(
                name: day.name,
                customName: day.customName,
                weekday: day.weekday,
                type: day.type,
                nextIntensity: day.nextIntensity,
                plan: copy,
                localizationKey: day.localizationKey,
                timeFormat: day.timeFormat,
                timeCapMinutes: day.timeCapMinutes,
                circuitRounds: day.circuitRounds,
                circuitRestSeconds: day.circuitRestSeconds,
                circuitMode: day.circuitMode,
                // Phase B, Task 5: Herkunfts-Stempel wird dupliziert, nicht
                // geraten - ein echter, unberuehrter Auto-Ruhetag bleibt nach
                // dem Duplizieren eine eligible Einfuege-Stelle; ein bereits
                // vom User angefasster Tag (false) bleibt es nicht.
                isAutoFilledPlaceholder: day.isAutoFilledPlaceholder
            )
            modelContext.insert(dayCopy)

            // Nur AKTIVE Uebungen kopieren — archivierte Urlaubs-Modus-
            // Snapshots gehoeren der Original-Plan-Instanz und sollen
            // nicht in der Kopie geistern. `swappedFromOriginal`/`isArchived`
            // bleiben bewusst aussen vor (siehe Funktions-Kommentar oben) -
            // die Kopie startet ohne Urlaubs-Modus-Historie.
            //
            // Bugfix (Audit): customName, supersetId, role und die DEL-098-
            // Fatigue-Faktoren + primaryMuscle/equipment-Overrides fehlten -
            // Warmups wurden zu normalen Arbeitssaetzen, Supersets trennten
            // sich, Recovery-Scoring + eigene Uebungsklassifikation gingen
            // auf Default-Werte zurueck.
            for ex in day.activeExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let exCopy = Exercise(
                    name: ex.name,
                    customName: ex.customName,
                    sets: ex.sets,
                    repsMin: ex.repsMin,
                    repsMax: ex.repsMax,
                    restSeconds: ex.restSeconds,
                    notes: ex.notes,
                    suggestedWeight: ex.suggestedWeight,
                    orderIndex: ex.orderIndex,
                    targetRir: ex.targetRir,
                    weightReducedNote: ex.weightReducedNote,
                    isCardio: ex.isCardio,
                    isTimeBased: ex.isTimeBased,
                    smartProgressionEnabled: ex.smartProgressionEnabled,
                    progressionStep: ex.progressionStep,
                    isCompound: ex.isCompound,
                    targetDistanceKm: ex.targetDistanceKm,
                    targetDurationMinutes: ex.targetDurationMinutes,
                    supersetId: ex.supersetId,
                    role: ex.role,
                    systemicFatigueFactor: ex.systemicFatigueFactor,
                    localMuscleDamageFactor: ex.localMuscleDamageFactor,
                    cnsDemandFactor: ex.cnsDemandFactor,
                    axialLoadFactor: ex.axialLoadFactor,
                    technicalComplexityFactor: ex.technicalComplexityFactor,
                    recoveryClass: ex.recoveryClass,
                    primaryMuscle: ex.primaryMuscle,
                    equipment: ex.equipment,
                    day: dayCopy
                )
                exCopy.targetPaceMinutesPerKm = ex.targetPaceMinutesPerKm
                exCopy.coachingRationale = ex.coachingRationale
                modelContext.insert(exCopy)
            }
        }
        // Audit-Fix (Save-Fehler): derselbe Musterfehler wie
        // `ProgramTemplatePickerView.instantiate` - ohne expliziten Save
        // haengt die ganze Tiefkopie (Plan + Tage + Uebungen) am impliziten
        // Autosave. `modelContext.delete(copy)` cascaded auf Tage + Uebungen
        // (siehe `TrainingPlan.days`/`TrainingDay.exercises` deleteRule).
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(copy)
            deletePlanErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Subviews

/// Bugfix (Crash, TestFlight 0.1.0/175 — crash log `TrainingPlan.
/// targetEnvironment.getter` <- `PlanRow.body` <- `PlansListView.swift:795`):
/// a plain, `@Model`-free snapshot of everything `PlanRow` displays.
///
/// Root cause: `PlanRow` used to hold the LIVE `TrainingPlan` and read its
/// properties (`targetEnvironment`, `displayName`, `isActive`, `days.count`,
/// `weeks`) directly inside `body`. Reading an `@Model` property inside a
/// `View.body` registers a SwiftData Observation dependency on that SPECIFIC
/// object, separate from (and faster than) the `@Query`'s own list-level
/// diffing. Deleting the plan fires an invalidation through that same
/// Observation channel, re-invoking `PlanRow.body` — and SwiftData has no
/// catchable error path for reading a property after that: it's a hard,
/// non-recoverable crash (`_assertionFailure` inside SwiftData's
/// `BackingData`). `deletePlans`'s own commit history documents FOUR
/// separate, device-tested fix attempts for the closely related `session.
/// day`/`ActiveSessionBanner` crash (deferred save, nullify-before-delete,
/// cascade restructuring, split saves) — none of them worked, and the team
/// ultimately blocked that one case at the UI level instead of fixing it.
///
/// This fix is architecturally different from all four: instead of trying
/// to time the `save()` around the crash, it removes `PlanRow`'s own
/// dependency on the live object entirely. `PlanRowContent` is built once,
/// per plan, inside `PlansListView.planRows` — a computed property that only
/// re-evaluates in reaction to `plansByName`'s own `@Query` refiring, i.e.
/// only once a plan is confirmed to still be a row of the live query
/// results. `PlanRow.body` then reads only these plain `String`/`Bool`/`Int`
/// fields, so there is nothing left for SwiftData's Observation machinery to
/// re-invoke it over when the underlying `TrainingPlan` is deleted.
///
/// Not verified on a real device (no iOS hardware/simulator in this
/// environment) — the crash itself is a SwiftUI rendering-timing issue with
/// no automated UI-test harness in this repo. Needs a TestingBot/device
/// re-test of "delete a plan from the Plan tab" before this can be
/// considered confirmed fixed.
struct PlanRowContent: Equatable {
    let displayName: String
    let isActive: Bool
    let daysCount: Int
    let weeks: Int
    let targetEnvironment: EnvironmentType

    init(_ plan: TrainingPlan) {
        displayName = plan.displayName
        isActive = plan.isActive
        daysCount = plan.days.count
        weeks = plan.weeks
        targetEnvironment = plan.targetEnvironment
    }
}

// `internal` (not `private`) specifically so `@testable import DeltiqUI`
// can verify the extraction above against a real `TrainingPlan` — same
// pattern already used by `AddMealViewDiscardTests`' `MealDraftItemFieldsSnapshot`.

/// Pairs the live `plan` (needed only for tap/swipe actions, never read
/// during `body` evaluation) with its pre-extracted `PlanRowContent` (all
/// `PlanRow` actually renders). See `PlanRowContent` doc for why this split
/// exists.
private struct PlanRowItem: Identifiable {
    let plan: TrainingPlan
    let content: PlanRowContent
    var id: PersistentIdentifier { plan.persistentModelID }
}

@available(iOS 17.0, macOS 14.0, *)
private struct PlanRow: View {
    let content: PlanRowContent

    var body: some View {
        HStack(spacing: 12) {
            // Handoff 1.10 (ein Akzent): Icon war Gruen(aktiv)/Grau(inaktiv)
            // - beide Zustaende teilen sich jetzt dasselbe Orange-Icon; der
            // Aktiv-Status wird ausschliesslich ueber die DeltiqPill daneben
            // kommuniziert, nicht mehr doppelt ueber die Icon-Farbe.
            Image(systemName: "list.bullet.rectangle.portrait")
                .deltiqAccentIcon()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(content.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    if content.isActive {
                        DeltiqPill(String(localized: "plans.activeBadge", bundle: .module).uppercased(), style: .accent)
                    }
                }
                HStack(spacing: 8) {
                    // DEL-128: Plurals via .one/.other-Namespace + manuelle
                    // %lld-Substitution (Apple-Plural-Pattern verschluckt sich
                    // an GenerateStringSymbols seit Xcode 26.4.1 — DEL-121).
                    Text(pluralized("plan.metadata.days", count: content.daysCount))
                    Text("•")
                    Text(pluralized("plan.metadata.weeks", count: content.weeks))
                    Text("•")
                    Text(environmentLabel(content.targetEnvironment))
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
            }

            Spacer()

            // Nachtrag 6. August, abends (README 2.10/19a): ersetzt den
            // nativen List-Chevron, der jetzt entfaellt (der Button-Wrapper
            // in `plansSection` bringt keinen mit) - gleiches Muster wie
            // `ActiveSessionBanner` darunter.
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }

    /// DEL-128: Plural-Resolver fuer "plan.metadata.days" und ".weeks".
    /// Switcht auf `.one`/`.other`-Sub-Keys und macht die `%lld`-
    /// Substitution manuell (siehe DEL-121-Saga zu Apple-Plural-Patterns
    /// + Xcode-26.4.1-`GenerateStringSymbols`-Konflikten).
    private func pluralized(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ActiveSessionBanner: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .deltiqAccentIcon(size: 38, glyphSize: 16)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-128: "Gestartet %@"-Banner via xcstrings.
                // DEL-129: displayDayName-Extension loest day.displayName
                // -> snapshot -> Fallback-String in einer Source. Im TR-Mode
                // sieht der User jetzt "Tüm Vücut A" statt "Ganzkörper A".
                // Wenn day == nil UND snapshot == nil (sehr selten), faellt
                // die Extension auf history.session.fallback zurueck —
                // hier ueberschreiben wir mit dem aktiveren Banner-Fallback
                // "Training läuft" / "Workout in progress" via Branch.
                Text(session.day != nil || session.dayName != nil
                     ? session.displayDayName
                     : String(localized: "plans.active.fallbackName", bundle: .module))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(
                    String(localized: "plans.active.startedAt", bundle: .module)
                        .replacingOccurrences(
                            of: "%@",
                            with: session.startTime.formatted(.relative(presentation: .named))
                        )
                )
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textTertiary)
        }
    }
}
#endif
