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

    @State private var showingTemplatePicker = false

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
            .listSectionSpacing(.compact)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingTemplatePicker) {
            ProgramTemplatePickerView()
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
                NavigationLink(value: plan) {
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

    private func createNewPlan() {
        let plan = TrainingPlan(
            name: "Neuer Plan",
            weeks: 12,
            isActive: plans.isEmpty,                       // first plan is active by default
            targetEnvironment: .gym
        )
        modelContext.insert(plan)
        navigation.workoutPath.append(plan)
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }

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
            let dayCopy = TrainingDay(
                name: day.name,
                weekday: day.weekday,
                type: day.type,
                nextIntensity: day.nextIntensity,
                plan: copy,
                localizationKey: day.localizationKey
            )
            modelContext.insert(dayCopy)

            // Nur AKTIVE Uebungen kopieren — archivierte Urlaubs-Modus-
            // Snapshots gehoeren der Original-Plan-Instanz und sollen
            // nicht in der Kopie geistern.
            for ex in day.activeExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let exCopy = Exercise(
                    name: ex.name,
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
