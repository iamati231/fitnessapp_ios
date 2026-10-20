#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

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

    /// Nachbesserung (P2.3, Abnahme "keine Duplikate bei mehrfacher
    /// Bestaetigung"): `CardioFeasibilityCardModel.accept(profile:in:)` ist
    /// synchron, ohne `await` — schuetzt NUR den direkten "Uebernehmen"-
    /// Button in `cardioFeasibilitySection`. Der Pfad ueber `PlanBuilderView`
    /// ("Plan anpassen") ist bereits durch dessen eigenen `isAdopting`-Schutz
    /// abgedeckt (derselbe Button loest dort sowohl Adopt als auch diese
    /// Closure aus).
    @State private var isAcceptingCardioFeasibility = false
    /// Nachbesserung (Task #197, zweite Runde): Speicherfehler von
    /// `accept`/`acceptCustom` werden jetzt sichtbar gemacht statt still im
    /// `nil`-Pfad zu verschwinden — Non-nil zeigt den Alert, "OK" setzt
    /// zurueck und erlaubt den naechsten Versuch (der Button ist wegen
    /// `isAcceptingCardioFeasibility` ohnehin erst nach dem Reset wieder
    /// aktiv).
    @State private var cardioAcceptErrorMessage: String?
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
    /// Nachbesserung (zweite Korrekturrunde, Punkt B): `accept` kann nach einem ERFOLGREICHEN
    /// Speichervorgang trotzdem werfen, wenn NUR die Rueckbindung scheitert
    /// (`PlanCreationError.createdButRebindFailed`, nach bereits einem internen Retry in
    /// `createPlan`) - "Speicherfehler" waere dann falsch. Steuert den Alert-Titel. Betrifft NUR
    /// den direkten "Uebernehmen"-Button; der "Plan anpassen"-Sheet-Pfad zeigt bei diesem Fall
    /// stattdessen eine eigene Nachricht unter `PlanBuilderView`s generischem Titel (siehe dort).
    @State private var cardioAcceptErrorIsCreatedButUnresolved = false
    /// Nachbesserung (Task #197, dritte Korrekturrunde): der tatsaechliche Operationszustand fuer
    /// den DIREKTEN "Uebernehmen"-Button - einmal committed (Plan persistiert, nur Rueckbindung
    /// gescheitert), ruft `attempt(...)` fuer diese Instanz NIE WIEDER `model.accept(...)` auf,
    /// egal wie oft erneut getippt wird (siehe `PlanCreationOperation`-Typ-Doku). Genau das
    /// verhindert den Duplikat-Fall, den ein einfaches "Flag zuruecksetzen + Button wieder
    /// aktivieren" nicht verhindert haette.
    @State private var acceptOperation = PlanCreationOperation()
    /// Task #197 (Verifikationsrunde): `acceptOperation` ist laut ihrer eigenen Typ-Doku PERMANENT
    /// fuer ihre Lebensdauer - "ein wirklich neuer Versuch braucht eine neue Instanz". Anders als
    /// `acceptCustomOperation` (siehe dort: frisch bei jedem Sheet-Oeffnen) lebte `acceptOperation`
    /// bisher aber ueber die GESAMTE `PlansListView`-Lebensdauer, ohne je ausgetauscht zu werden -
    /// auf echtem Geraet reproduziert: nach einem erfolgreich angenommenen Cardio-Vorschlag zeigte
    /// JEDE spaetere, voellig unabhaengige Cardio-Karte (neues Ziel/Renndatum/Volumen, eigener
    /// `CardioFeasibilityCardModel.fingerprint`) faelschlich "Erneut versuchen" statt "Vorschlag
    /// annehmen"/"Plan uebernehmen" - UND ein Tap darauf haette nur noch den LAENGST aufgeloesten
    /// alten Plan erneut aufzuloesen versucht, nie den neuen Vorschlag tatsaechlich angelegt.
    /// Haelt fest, fuer welchen Fingerprint `acceptOperation` zuletzt (neu erzeugt oder committed)
    /// stand; weicht die aktuell angezeigte Karte davon ab, ist die Instanz fuer eine ANDERE
    /// Kombination committed (oder noch nie committed) und muss vor Gebrauch ausgetauscht werden.
    @State private var acceptOperationFingerprint: String?
    /// Nachbesserung (Task #197, dritte Korrekturrunde): dieselbe Garantie wie `acceptOperation`,
    /// aber fuer den "Plan anpassen"-Sheet-Pfad (`acceptCustom`) - eigene, unabhaengige Instanz,
    /// weil es ein eigener, unabhaengiger Vorgang ist. Wird beim OEFFNEN des Sheets bewusst neu
    /// erzeugt (siehe Aufrufstelle unten), damit eine neue Bearbeitungssitzung nie den
    /// committed-Zustand einer fruiheren erbt.
    @State private var acceptCustomOperation = PlanCreationOperation()
    /// Nachtrag "Plan anpassen": eigener Zustand, NICHT `showingPlanBuilder`
    /// wiederverwenden - der haengt am Plus-Menue mit leerem Wizard-Start,
    /// hier soll er mit dem Machbarkeits-Vorschlag vorbefuellt oeffnen.
    @State private var showingPlanAdjustSheet = false

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

                if let profile = profiles.first, let model = CardioFeasibilityCardModel.make(for: profile) {
                    cardioFeasibilitySection(model, profile: profile)
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
        // Nachbesserung (Task #197, zweite Runde): sichtbarer Fehler statt
        // stillem nil-Pfad, siehe `cardioAcceptErrorMessage`-Doku.
        // Nachbesserung (zweite Korrekturrunde, Punkt B): Titel haengt vom Fehlerfall ab, siehe
        // `cardioAcceptErrorIsCreatedButUnresolved`-Doku.
        .alert(
            Text(cardioAcceptErrorIsCreatedButUnresolved
                 ? "cardioFeasibility.error.createdButUnresolved.title"
                 : "cardioFeasibility.error.saveFailed.title", bundle: .module),
            isPresented: Binding(
                get: { cardioAcceptErrorMessage != nil },
                set: { if !$0 { cardioAcceptErrorMessage = nil } }
            )
        ) {
            Button("OK") { cardioAcceptErrorMessage = nil }
        } message: {
            Text(cardioAcceptErrorMessage ?? "")
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

    // MARK: - Handoff "Lauf-Coaching - Machbarkeits-Check"

    /// Vor den eigenen Plaenen (2.30), bewusst KEIN `DeltiqCard` wie die
    /// echten Plaene darunter - gestrichelter Rand macht sofort erkennbar
    /// "das hier laeuft noch nicht". Uebernehmen/Verwerfen direkt hier,
    /// anders als die verkuerzte Dashboard-Karte (die nur zu dieser Stelle
    /// verlinkt).
    private func cardioFeasibilitySection(_ model: CardioFeasibilityCardModel, profile: UserBodyProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "flag.checkered")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.verdict.feasible
                         ? String(localized: "plans.cardioFeasibility.feasibleTitle", bundle: .module)
                         : String(localized: "plans.cardioFeasibility.infeasibleTitle", bundle: .module))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(model.detailText)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if model.hasPlan, let days = model.planResult?.days {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        CardioFeasibilityDayRow(day: day)
                    }
                }
            }
            // Nachtrag "Plan anpassen", Layout-Hinweis: die primaere Aktion
            // steht allein in voller Staerke, "Plan anpassen" und "Ziel
            // behalten" folgen als gleichrangiges, leiseres Paar darunter.
            if model.hasPlan {
                Button {
                    guard !isAcceptingCardioFeasibility else { return }
                    // Siehe `acceptOperationFingerprint`-Doku: eine Karte fuer eine ANDERE
                    // Ziel/Renndatum/Volumen-Kombination als die, fuer die `acceptOperation`
                    // zuletzt stand, braucht zwingend eine frische Instanz - sonst wuerde dieser
                    // Tap nur den alten, laengst committeten Vorgang erneut aufloesen statt den
                    // hier tatsaechlich angezeigten, neuen Vorschlag anzulegen.
                    if acceptOperationFingerprint != model.fingerprint {
                        acceptOperation = PlanCreationOperation()
                        acceptOperationFingerprint = model.fingerprint
                    }
                    isAcceptingCardioFeasibility = true
                    withAnimation {
                        // Nachbesserung (vierte Korrekturrunde): `model.accept(...using:)` fuehrt
                        // `resumeIfCommitted`/`attempt` jetzt INTERN aus (siehe
                        // `CardioFeasibilityCardModel`-Doku) - `nil` bedeutet, dass bereits
                        // `accept`s eigene Vorbedingungen (z.B. `hasPlan`) nicht erfuellt sind,
                        // und wird wie `.nothingToCreate` behandelt.
                        switch model.accept(profile: profile, in: modelContext, using: acceptOperation) {
                        case .success(let plan):
                            // Geraete-Fund (TestingBot, Task #197 UI-Pruefumfang): ohne dieses
                            // Zuruecksetzen blieb der Button nach JEDEM erfolgreichen Uebernehmen
                            // fuer den Rest der View-Lebensdauer dauerhaft deaktiviert - SwiftUIs
                            // TabView haelt @State ueber Tab-Wechsel hinweg am Leben, ein spaeterer,
                            // voellig unabhaengiger Cardio-Vorschlag war dadurch nie mehr per Tap
                            // annehmbar (nur noch ueber den Umweg "Plan anpassen").
                            isAcceptingCardioFeasibility = false
                            navigation.workoutPath.append(plan)
                        case nil:
                            isAcceptingCardioFeasibility = false
                        case .nothingToCreate:
                            // Nachbesserung (P2.3-Review, Punkt 3): Flag zuruecksetzen - die Karte
                            // bleibt sichtbar, der Button muss wieder bedienbar sein.
                            isAcceptingCardioFeasibility = false
                        case .committedButUnresolved:
                            // Der Plan WURDE bereits gespeichert - "Speicherfehler" waere falsch,
                            // Button zeigt ab jetzt "Erneut versuchen" (siehe Label unten).
                            isAcceptingCardioFeasibility = false
                            cardioAcceptErrorIsCreatedButUnresolved = true
                            cardioAcceptErrorMessage = String(localized: "cardioFeasibility.error.createdButUnresolved.message", bundle: .module)
                        case .failedBeforeCommit:
                            isAcceptingCardioFeasibility = false
                            cardioAcceptErrorIsCreatedButUnresolved = false
                            cardioAcceptErrorMessage = String(localized: "cardioFeasibility.error.saveFailed.message", bundle: .module)
                        }
                    }
                } label: {
                    // Nachbesserung (dritte Korrekturrunde, Punkt 5): im "bereits erstellt, nur
                    // nicht aufgeloest"-Zustand kein irrefuehrendes erneutes "Uebernehmen" -
                    // derselbe Button loest dann nur noch eine Aufloesung aus, nie eine Neuanlage.
                    Text((acceptOperation.committedPlanID != nil && acceptOperationFingerprint == model.fingerprint)
                         ? String(localized: "plans.cardioFeasibility.retryResolve", bundle: .module)
                         : (model.verdict.feasible
                            ? String(localized: "plans.cardioFeasibility.apply", bundle: .module)
                            : String(localized: "plans.cardioFeasibility.acceptSuggestion", bundle: .module)))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
                .disabled(isAcceptingCardioFeasibility)
            }
            HStack(spacing: 20) {
                if model.hasPlan {
                    Button {
                        // Nachbesserung (Task #197, dritte Korrekturrunde): frische Instanz pro
                        // Bearbeitungssitzung - eine neu geoeffnete "Plan anpassen"-Sitzung darf
                        // NIE den committed-Zustand einer frueheren erben (siehe
                        // `acceptCustomOperation`-Doku).
                        acceptCustomOperation = PlanCreationOperation()
                        showingPlanAdjustSheet = true
                    } label: {
                        Text("plans.cardioFeasibility.adjustPlan", bundle: .module)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
                if !model.verdict.feasible {
                    Button {
                        withAnimation { model.dismiss(profile: profile) }
                    } label: {
                        Text("plans.cardioFeasibility.keepGoal", bundle: .module)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                .strokeBorder(Color.deltiqOrange.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .sheet(isPresented: $showingPlanAdjustSheet) {
            if let input = model.planInput {
                PlanBuilderView(initialInput: input) { adjustedInput, adjustedResult in
                    // Nachbesserung (Task #197, dritte Korrekturrunde): `acceptCustomOperation`
                    // (frisch pro Sheet-Oeffnung, siehe Aufrufstelle oben) ersetzt das vorherige
                    // direkte `do/catch` - einmal `.committedButUnresolved`, ruft diese Instanz
                    // `model.acceptCustom(...)` NIE WIEDER auf, egal wie oft der Builder-Button
                    // erneut getippt wird. `PlanBuilderView` leitet ihre eigene lokalisierte
                    // Nachricht selbst aus dem zurueckgegebenen `PlanBuilderHandoffOutcome` ab -
                    // hier wird kein fertiger Text mehr uebergeben.
                    switch model.acceptCustom(
                        input: adjustedInput, result: adjustedResult, profile: profile,
                        in: modelContext, using: acceptCustomOperation
                    ) {
                    case .success(let plan):
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigation.workoutPath.append(plan)
                        }
                        return .success
                    case nil:
                        return .success
                    case .nothingToCreate:
                        return .success
                    case .committedButUnresolved:
                        return .committedButUnresolved
                    case .failedBeforeCommit:
                        return .failedBeforeCommit
                    }
                }
            }
        }
    }

    // MARK: - Plaene

    /// Kein `header:` — "Pläne" ist bereits der Screen-Titel in der
    /// Kopfzone, eine zweite identische Ueberschrift waere redundant (vgl.
    /// CalculatorsView, deren einzige Sektion aus demselben Grund
    /// unbetitelt bleibt).
    @ViewBuilder
    private var plansSection: some View {
        if plans.isEmpty {
            emptyState
        } else {
            ForEach(plans) { plan in
                // Nachtrag 6. August, abends (README 2.10/19a): ein
                // `NavigationLink` zeichnet in einer `List` IMMER seinen
                // eigenen nativen Chevron dazu - der sitzt dann ausserhalb
                // der `DeltiqCard`, im Leerraum der Zeile, statt darin wie
                // beim Session-Banner. Gleicher Fix wie bei
                // `activeSessionSection` oben: `Button`, der dieselbe
                // Path-Instanz befuellt, plus handgezeichneter Chevron IN
                // `PlanRow`.
                Button {
                    navigation.workoutPath.append(plan)
                } label: {
                    // Nachtrag 6. August (README 2.6): ein blosses
                    // .listRowBackground(Color.Deltiq.surface) uebernimmt nur
                    // die Flaeche, nicht unseren 20pt-Karten-Radius - die Zeile
                    // fuellte vorher die vollen List-Insets und war schmaeler
                    // als die 16pt-Vorgabe, dazu mit dem falschen Radius.
                    // Eine echte DeltiqCard plus dieselben Insets wie das
                    // Banner (siehe activeSessionSection) gleicht beide an.
                    DeltiqCard {
                        PlanRow(plan: plan)
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
                        duplicatePlan(plan)
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
        navigation.workoutPath.append(plan)
    }

    private func deletePlans(at offsets: IndexSet) {
        let plansToDelete = offsets.map { plans[$0] }
        // TestingBot-Geraetebefund (Deltiq-Abnahme, Punkt 1, VIERTE
        // Nachbesserung zum fdad04c-Fix — drei vorherige Versuche (Save per
        // `DispatchQueue.main.async` verzoegern; `session.day` vorab nullen;
        // Tage einzeln statt per Plan-Cascade loeschen, aber noch im selben
        // `save()` wie der Plan) haben den Crash auf echtem Geraet
        // NACHWEISLICH NICHT behoben — alle drei erneut reproduziert,
        // identischer Fehler im iOS-Geraetelog: "SwiftData/BackingData.
        // swift:296: Fatal error: Context is missing for ... TrainingDay/pN",
        // ausgeloest WAEHREND SwiftData selbst den "CoreData: Executing write
        // request" verarbeitet.
        //
        // Entscheidender Geraete-Befund: `PlanEditorView.deleteDays` loescht
        // denselben Tag (mit derselben laufenden Session) DIREKT, OHNE dass
        // im selben `save()` zusaetzlich der Plan geloescht wird — das crasht
        // NICHT. Der dritte Versuch hier loeschte Tag UND Plan EINZELN, aber
        // IMMER NOCH im selben `save()` — und crashte trotzdem identisch.
        // Schlussfolgerung: SwiftData verarbeitet `delete(day)` UND
        // `delete(plan)` (plan.days deleteRule: .cascade) im SELBEN Save
        // weiterhin als EINE Kaskade und versucht den bereits einzeln zum
        // Loeschen markierten Tag ein zweites Mal ueber den Plan zu
        // verarbeiten — das inkonsistente Doppel-Processing desselben Tages
        // in einer Transaktion ist der eigentliche Ausloeser, nicht die
        // Reihenfolge der `delete()`-Aufrufe an sich.
        //
        // Fix: Tag-Loeschung und Plan-Loeschung in ZWEI GETRENNTE, nacheinander
        // committete Saves aufteilen. Nach dem ersten `save()` ist der Tag
        // bereits vollstaendig und bestaetigt aus dem Store entfernt, bevor
        // der (jetzt tage-lose) Plan ueberhaupt zum Loeschen markiert wird —
        // SwiftData hat dann nichts mehr zu kaskadieren.
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
                circuitMode: day.circuitMode
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
                modelContext.insert(exCopy)
            }
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct PlanRow: View {
    let plan: TrainingPlan

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
                    Text(plan.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    if plan.isActive {
                        DeltiqPill(String(localized: "plans.activeBadge", bundle: .module).uppercased(), style: .accent)
                    }
                }
                HStack(spacing: 8) {
                    // DEL-128: Plurals via .one/.other-Namespace + manuelle
                    // %lld-Substitution (Apple-Plural-Pattern verschluckt sich
                    // an GenerateStringSymbols seit Xcode 26.4.1 — DEL-121).
                    Text(pluralized("plan.metadata.days", count: plan.days.count))
                    Text("•")
                    Text(pluralized("plan.metadata.weeks", count: plan.weeks))
                    Text("•")
                    Text(environmentLabel(plan.targetEnvironment))
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
