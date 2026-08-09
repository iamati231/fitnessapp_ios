#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Home screen — landing surface answering three questions on app open:
///   1. Where am I (latest weight + body-fat + FFMI)?
///   2. What's next (today's training day from the active plan)?
///   3. What did I do recently (last completed workouts + weight trend)?
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    /// DEL-132 (Phase 3): HealthKit-Controller fuer Hero-Metric-Slots
    /// `.restingHR` + `.stepsToday`. Wird in RootView injected; falls
    /// nicht vorhanden (extrem unwahrscheinlich), bleiben die HK-Cards
    /// auf "—" stehen.
    @Environment(HealthKitController.self) private var healthKit

    /// Reverse-chronological so `.first` is the latest measurement.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @Query private var profiles: [UserBodyProfile]

    @Query(filter: #Predicate<TrainingPlan> { $0.isActive == true })
    private var activePlans: [TrainingPlan]

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completedSessions: [WorkoutSession]

    /// Trophy-Room teaser uses this to show count + latest exercise.
    /// Reverse-sort so `.first` is the most recent PR.
    @Query(sort: \PersonalRecordEntry.date, order: .reverse)
    private var personalRecords: [PersonalRecordEntry]

    /// DEL-042: laufende, nicht-abgeschlossene Sessions. Wenn `.first` nicht
    /// nil ist, gibt's eine offene Session, die der User entweder fortsetzen
    /// oder verwerfen sollte. Die PlanDayCard adaptiert daraufhin den
    /// Start-Button-Text + Farbe, und beim Klick auf eine andere-Plan-Session
    /// erscheint ein Conflict-Dialog.
    @Query(filter: #Predicate<WorkoutSession> {
        $0.isCompleted == false && $0.isRestDay == false
    }, sort: \WorkoutSession.startTime, order: .reverse)
    private var openSessions: [WorkoutSession]

    /// DEL-132 (Phase 2): WaterEntries fuer den `.waterTodayMl`-Hero-Slot.
    /// Predicate auf `date >= startOfToday` waere theoretisch effizienter,
    /// aber SwiftData's `#Predicate` macht bei `Calendar.current.startOfDay`
    /// Aerger (siehe WaterTrackerView Line 22-23) — daher full-fetch +
    /// in-memory-filter im `todayWaterMl`-Computed unten. Bei normalen
    /// User-Volumen (paar hundert Entries pro Monat) vernachlaessigbar.
    @Query(sort: \WaterEntry.date, order: .reverse)
    private var waterEntries: [WaterEntry]

    /// DEL-042: ConfirmationDialog-State fuer den Konflikt-Pfad.
    /// pendingNewStart-Closure wird aufgerufen wenn der User "Altes verwerfen"
    /// waehlt — sie liefert die Aktion fuer einen frischen Insert.
    @State private var showingActiveSessionConflict = false
    @State private var pendingNewStart: (() -> Void)?

    /// Nachtrag 6. August (README 2.1): Umschaltzustand fuer die
    /// aufklappbare Uebungsliste der Plan-Karte. View-lokal und bewusst
    /// nicht persistiert - faellt beim Verlassen des Dashboards zurueck
    /// auf zugeklappt. Nur eine Plan-Karte ist je Dashboard sichtbar
    /// (`activePlans.first`), ein einzelner Bool reicht.
    @State private var isExercisesExpanded = false

    /// DEL-132 (Phase 3): Async-fetched HealthKit-Werte fuer die
    /// entsprechenden Hero-Slots. Werden in `.task(id:)` auf Slot-
    /// Aenderung neu gezogen, sind nil solange noch nicht geholt /
    /// keine Permission / keine Daten.
    @State private var restingHRValue: Double?
    @State private var stepsTodayValue: Double?

    /// DEL-152: Persistierte Zeitfilter pro Trend-Chart. Default `.oneMonth`,
    /// damit lang-genutzte Accounts nicht mit einer ueberladenen X-Achse
    /// starten. Separate Keys pro Chart — Compound- und Cardio-Daten koennen
    /// unterschiedliche Spannweiten haben, der User stellt sie unabhaengig ein.
    @AppStorage("dashboard.compoundChartRange") private var compoundChartRange: ChartTimeRange = .oneMonth
    @AppStorage("dashboard.cardioChartRange") private var cardioChartRange: ChartTimeRange = .oneMonth
    /// DEL-178: Wochen-Volume-Trend-Chart. Eigener Range, damit der User
    /// pro Chart unabhängig zoomen kann (Compound-Trend evtl. 1M, Volume
    /// langfristig 3M etc.).
    @AppStorage("dashboard.volumeChartRange") private var volumeChartRange: ChartTimeRange = .threeMonths

    /// DEL-177: Letzter erfolgreicher CSV-Export. 0 = noch nie. Wird vom
    /// Soft-Coaching-Trigger gelesen — > 30 Tage her oder noch nie
    /// (mit genug History dahinter) → `.backupOverdue`-Hinweis.
    @AppStorage("lastDataExportAt") private var lastDataExportAt: Double = 0

    /// DEL-200: Ende der laufenden Deload-Woche als Unix-Timestamp.
    /// 0 = kein Deload aktiv. Gesetzt beim Apply-Tap auf der Coaching-
    /// Card; `autoEndDeloadIfExpired()` räumt nach Ablauf auf.
    @AppStorage("deload_until") private var deloadUntil: Double = 0

    /// DEL-238: Deload-Automatik. Gated die Empfehlung UND die
    /// Absenz-Rueckfrage — nie einen laufenden Deload.
    @AppStorage("pref_deload_enabled") private var deloadEnabled: Bool = true

    /// DEL-239: Bewertung der Trainingspause, solange die Rueckfrage offen ist.
    @State private var comebackAssessment: AbsenceDeload.Assessment?
    /// Fortsetzung des abgefangenen Trainingsstarts.
    @State private var pendingComebackStart: (() -> Void)?

    /// DEL-202: getappter Kalender-Tag fürs Tages-Detail-Sheet. Identifiable-
    /// Wrapper, weil `Date` selbst kein Identifiable ist und sheet(item:)
    /// eins verlangt.
    @State private var selectedCalendarDay: CalendarDaySelection?

    private struct CalendarDaySelection: Identifiable {
        let day: Date
        var id: Date { day }
    }

    /// Signature-Geruest: die Kopfzone hat keine native Toolbar mehr, der
    /// Plus-Knopf pusht daher programmatisch statt ueber einen
    /// NavigationLink im `.toolbar`.
    @State private var showingNewMeasurement = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: eigene Kopfzone statt Navigationsleiste
            // + dynamischer Begruessung als navigationTitle. Sitzt ausserhalb
            // der ScrollView, scrollt nicht mit.
            DeltiqHeader(
                eyebrow: String(localized: "tab.dashboard", bundle: .module).uppercased(),
                title: dashboardGreeting,
                actions: [
                    DeltiqHeaderAction(systemImage: "plus") {
                        showingNewMeasurement = true
                    }
                ]
            )

            // DEL-214: Achse explizit vertikal — und der Content wird unten via
            // containerRelativeFrame hart auf die Container-Breite geklemmt.
            ScrollView(.vertical) {
                // Signature-Geruest 1.1: Sektionsabstand 18 statt 16.
                VStack(alignment: .leading, spacing: 18) {
                    // Signature-Geruest 1.3: Kontextzeile mit aktivem Plan
                    // (Marke) + Wochen-Streak (neutral), plus Haarlinie.
                    dashboardContextRow

                    // DEL-109: heroMetrics bleibt statisch ueber den
                    // konfigurierbaren Widgets — zu zentral fuer das Brand,
                    // nicht via Toggle abschaltbar.
                    heroMetrics

                    // DEL-215: Prominente Resume-Tile fuer offene Sessions, die
                    // die PlanDayCard NICHT abdeckt (Ad-hoc-Workouts, Sessions
                    // auf inaktiven Plaenen, oder nextWorkout-Widget vom User
                    // deaktiviert). Statisch ueber den konfigurierbaren Widgets —
                    // ein laufendes Training schlaegt jede Card-Reihenfolge.
                    if let open = unrepresentedOpenSession {
                        resumeSessionTile(open)
                    }

                    // DEL-109: Dynamisches Widget-Rendering. Reihenfolge +
                    // Sichtbarkeit kommen aus dem User-Profil; jeder Case
                    // mappt auf den entsprechenden Card-View. Neue Widget-
                    // Typen: hier den switch erweitern UND den enum-Case
                    // anhaengen. Conditional-Rendering (z.B. cardioPaceChart
                    // wird nur sichtbar wenn `shouldShowCardioChart`) bleibt
                    // in den Card-Views selber — der Switch ruft sie nur auf.
                    ForEach(activeDashboardWidgets, id: \.self) { widget in
                        switch widget {
                        case .nextWorkout:     planDayCard
                        case .coachingInsight: coachingInsightCard
                        case .trophyRoom:      trophyRoomCard
                        case .workoutHistory:  historyCard
                        case .weeklyVolume:    weeklySummaryCard
                        case .muscleHeatmap:   muscleHeatmapCard
                        case .weightTrend:     trendChart
                        case .compoundLifts:   compoundLiftChart
                        case .cardioPace:      cardioPaceChart
                        case .recentWorkouts:  recentWorkoutsCard
                        case .volumeOverTime:  volumeOverTimeChart
                        case .trainingCalendar: trainingCalendarCard
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
                // DEL-214: Bugfix "Dashboard laesst sich horizontal wischen" —
                // ein zu breites Child (z.B. Chart-Label/monospaced Text) machte
                // den ScrollView-Content breiter als den Viewport, wodurch die
                // vertikale ScrollView horizontal pannte. containerRelativeFrame
                // proposed dem Content exakt die Container-Breite; zu breite
                // Children werden damit eingebremst statt den Canvas zu dehnen.
                .containerRelativeFrame(.horizontal)
            }
            .scrollContentBackground(.hidden)
        }
        // DEL-102: Off-Weiss / Off-Schwarz-Background, gegen den die
        // Bento-Cards (Surface) abheben. Im Light-Mode identisch zu
        // systemGroupedBackground, im Dark-Mode warmer (#0A0A0A statt #000).
        .background(Color.Deltiq.background.ignoresSafeArea())
        // Signature-Geruest 1.2: native Navigationsleiste versteckt, die
        // eigene DeltiqHeader uebernimmt Titel + Aktionen.
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showingNewMeasurement) {
            MeasurementView()
        }
        // DEL-132 (Phase 3): HealthKit-Werte fuer aktive Hero-Slots
        // ziehen. `.task(id:)` schiesst neu, sobald sich die Slot-Liste
        // aendert (z.B. nach Settings-Toggle), zusaetzlich beim ersten
        // Render. Bei fehlender HK-Permission bleiben die @State-
        // Properties auf nil und die Cards zeigen "—".
        .task(id: heroMetricSlots) {
            await refreshHealthKitHeroValues()
        }
        // DEL-200: abgelaufene Deload-Woche beim Dashboard-Erscheinen
        // aufräumen — Original-Gewichte zurückschreiben. Der typische
        // Pfad: App nach einer Woche wieder öffnen.
        .task {
            autoEndDeloadIfExpired()
        }
        // DEL-239: Rueckfrage nach langer Pause. `sheet(item:)`, damit das
        // Assessment beim Praesentieren feststeht. Die Entscheidung laeuft
        // ueber `resolveComeback`, das anschliessend den abgefangenen
        // Trainingsstart fortsetzt.
        .sheet(item: $comebackAssessment) { assessment in
            ComebackPromptSheet(assessment: assessment) { factor in
                resolveComeback(factor: factor)
            }
        }
        // DEL-042: Conflict-Dialog wenn der User in Plan A starten will,
        // waehrend in Plan B noch eine offene Session lebt.
        .confirmationDialog(
            Text("dashboard.openSession.title", bundle: .module),
            isPresented: $showingActiveSessionConflict,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                discardOtherOpenSessionsAndStartNew()
            } label: {
                Text("dashboard.openSession.discardAndStart", bundle: .module)
            }
            Button {
                resumeAnyOpenFromConflict()
            } label: {
                Text("dashboard.openSession.resume", bundle: .module)
            }
            Button(role: .cancel) {
                pendingNewStart = nil
            } label: {
                Text("dashboard.openSession.cancel", bundle: .module)
            }
        } message: {
            if let open = openSessions.first {
                // DEL-073: %1$@/%2$@ positional placeholders fuer
                // Datums-Stempel und Day-Name (Reihenfolge bleibt in
                // EN/TR identisch — sicherheitshalber positional).
                let stamp = open.startTime.formatted(.relative(presentation: .named))
                let dayName = open.dayName
                    ?? String(localized: "dashboard.openSession.dayName.unknown", bundle: .module)
                let template = String(localized: "dashboard.openSession.message.withInfo", bundle: .module)
                Text(template
                        .replacingOccurrences(of: "%1$@", with: stamp)
                        .replacingOccurrences(of: "%2$@", with: dayName))
            } else {
                Text("dashboard.openSession.message.fallback", bundle: .module)
            }
        }
    }

    // MARK: - Trophy Room teaser

    /// Compact entry-point to `PRHistoryView`. Counts personal-record entries
    /// across the store and shows the latest exercise that produced one — gives
    /// the user something to tap on even when the rest of the dashboard is dense.
    @ViewBuilder
    private var trophyRoomCard: some View {
        // UX-201: Empty + Data-State haben unterschiedliche Affordances —
        // empty rendert eine 4-teilige Premium-Karte mit CTA "Training
        // starten" (statt einem leeren NavigationLink in eine leere
        // PRHistoryView), data rendert die kompakte Teaser-Row mit
        // Count + letztem PR.
        if prCount == 0 {
            // UX-Refine 2026-05-21: kein CTA — vermeidet Button-Spam mit
            // dem identischen "Training starten" in History/Compound/Recent.
            // Recent-Workouts-Card uebernimmt den primaeren Train-Anker.
            DashboardEmptyState(
                icon: "trophy.fill",
                title: "dashboard.trophy.emptyTitle",
                description: "dashboard.trophy.emptyDescription"
            )
            .deltiqCardStyle()
        } else {
            NavigationLink {
                PRHistoryView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        // Signature-Geruest 2.16: war Color.yellow - einziger
                        // Ausreisser gegen 1.7 (ein Akzent), in der
                        // Zusammenfassung war das schon behoben, hier nicht.
                        .background(Color.deltiqOrange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.trophy.title", bundle: .module)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        // DEL-121: Apple's format-as-key Plural-Convention
                        // (`"%lld Rekorde"`) bricht Xcode 26.4.1's neuen
                        // GenerateStringSymbols-Schritt. Statt darauf zu
                        // verlassen, switchen wir explizit auf one/other
                        // namespace-Keys. Marginal verbosere Swift-Logik,
                        // dafuer kompatibel mit dem Symbol-Generator.
                        let key: String.LocalizationValue = prCount == 1
                            ? "dashboard.trophy.recordCount.one"
                            : "dashboard.trophy.recordCount.other"
                        let countText = String(format: String(localized: key, bundle: .module), prCount)
                        let suffix = latestPRSummary.map { " • \($0)" } ?? ""
                        Text(countText + suffix)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                // DEL-102: Bento-Card statt manuelle Background+Clip-Kette.
                .deltiqCardStyle()
            }
            .buttonStyle(.plain)
        }
    }

    private var prCount: Int { personalRecords.count }

    /// "Bankdrücken vor 2 Tagen" — short last-PR teaser when the table has rows.
    private var latestPRSummary: String? {
        guard let latest = personalRecords.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: latest.date, relativeTo: Date())
        // DEL-149: snapshot-resolver — lokalisierter Name aus dem DE-Base
        // (oder Reverse-Lookup-Hit fuer vor-DEL-149-Snapshots).
        let displayName = Exercise.resolvedDisplayName(forStoredName: latest.exerciseName)
        return "\(displayName) \(relative)"
    }

    // MARK: - History teaser (DEL-019)

    /// Prominent entry point to the full WorkoutHistoryView. Mirror der Trophy-
    /// Room-Card: kompakt, klickbar, mit Count und letztem-Workout-Teaser.
    /// Vorher war die History nur ueber "Alle anzeigen" am Ende der Recent-
    /// Workouts-Sektion erreichbar — User-Feedback war "find ich nicht".
    @ViewBuilder
    private var historyCard: some View {
        // UX-201: gleiche Doppel-Branch-Logik wie Trophy Room. Empty wird
        // zur 4-teiligen Premium-Karte, die direkt ins Plan-Tab fuehrt
        // (statt in eine leere History-Liste zu navigieren).
        let hasRealHistory = completedSessions.contains(where: { !$0.isRestDay })
        if !hasRealHistory {
            // UX-Refine 2026-05-21: kein CTA — Recent-Workouts-Card am
            // unteren Ende der Empty-State-Strecke ist der gemeinsame
            // Train-Anker fuer den brand-neuen User.
            DashboardEmptyState(
                icon: "calendar.badge.clock",
                title: "dashboard.history.emptyTitle",
                description: "dashboard.history.emptyDescription"
            )
            .deltiqCardStyle()
        } else {
            NavigationLink {
                WorkoutHistoryView()
            } label: {
                HStack(spacing: 12) {
                    // DEL-105: Brand-Akzent statt iOS-Standard-Blau.
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.deltiqOrange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.history.title", bundle: .module)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(historyTeaserText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                // DEL-103: Bento-Card.
                .deltiqCardStyle()
            }
            .buttonStyle(.plain)
        }
    }

    // DEL-120: zwei Varianten via xcstrings:
    //   * count + last     -> "dashboard.history.countWithLast" (2-Arg-Format)
    //   * count nur        -> "dashboard.history.countOnly"
    //
    // UX-201: der frühere Empty-Branch ("dashboard.history.empty"-Teaser)
    // ist entfernt — historyCard switcht jetzt auf hasRealHistory-Niveau:
    // bei empty rendert er die Premium-Empty-Card mit CTA, sonst kommt
    // historyTeaserText ueberhaupt erst zum Zug. Defensive `real.isEmpty`-
    // Branch ist damit unreachable und wurde gestrichen.
    private var historyTeaserText: String {
        let real = completedSessions.filter { !$0.isRestDay }
        if let latest = real.first {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: latest.startTime, relativeTo: Date())
            let template = String(localized: "dashboard.history.countWithLast", bundle: .module)
            return template
                .replacingOccurrences(of: "%1$lld", with: "\(real.count)")
                .replacingOccurrences(of: "%2$@",   with: relative)
        }
        return String(format: String(localized: "dashboard.history.countOnly", bundle: .module), real.count)
    }

    // MARK: - DEL-109 Widget-Konfiguration

    /// Aktive Dashboard-Widgets aus dem User-Profil. Fallback auf den
    /// Default, wenn kein Profil existiert (Erst-Launch vor Onboarding-
    /// Finish — Edge-Case, weil RootView in dem Fall ohnehin OnboardingView
    /// rendert, nicht Dashboard).
    private var activeDashboardWidgets: [DashboardWidgetType] {
        profiles.first?.activeDashboardWidgets ?? DashboardWidgetType.defaultOrder
    }

    // MARK: - Hero metrics

    /// DEL-132 (Phase 1): Hero-Slot-Liste vom User-Profil. Fallback auf
    /// `defaultOrder` falls (sehr selten) kein Profile existiert (Edge-
    /// Case waehrend Onboarding-Race).
    private var heroMetricSlots: [HeroMetricType] {
        profiles.first?.heroMetricSlots ?? HeroMetricType.defaultOrder
    }

    /// DEL-141: Dynamische Begrüßung für den NavigationTitle. Drei Tages-
    /// zeit-Buckets (Morgen 5-12, Tag 12-18, Abend 18-5) × zwei Namen-
    /// Branches (mit/ohne Vornamen) = 6 explicit case-literals statt
    /// String-Interpolation. Grund: das Dead-Catalog-Audit-Tool
    /// (`dead_catalog_v3.py`) catched literale Key-Strings sauber, aber
    /// `"\(timeKey).named"`-Interpolation nur heuristisch. Explizite
    /// Literale halten den Audit auf "UNUSED: 0" ohne komplexere Phase-B-
    /// Patterns im Tool.
    private var dashboardGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let trimmedName = profiles.first?.firstName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !(trimmedName?.isEmpty ?? true)

        switch (hour, hasName) {
        case (5..<12, true):
            return String(format: String(localized: "dashboard.greeting.morning.named", bundle: .module),
                          trimmedName!)
        case (5..<12, false):
            return String(localized: "dashboard.greeting.morning.generic", bundle: .module)
        case (12..<18, true):
            return String(format: String(localized: "dashboard.greeting.afternoon.named", bundle: .module),
                          trimmedName!)
        case (12..<18, false):
            return String(localized: "dashboard.greeting.afternoon.generic", bundle: .module)
        case (_, true):
            return String(format: String(localized: "dashboard.greeting.evening.named", bundle: .module),
                          trimmedName!)
        case (_, false):
            return String(localized: "dashboard.greeting.evening.generic", bundle: .module)
        }
    }

    /// Signature-Geruest 1.3: Marken-Kapsel (aktiver Plan-Name) + neutrale
    /// Kapsel (Wochen-Streak). Beide leer → keine Zeile (Erst-Start ohne
    /// Plan/Historie).
    ///
    /// Der Handoff schlaegt woertlich "WOCHE 3 · PPL 6×" vor — einen
    /// Wochenzaehler im aktuellen Planzyklus. Dafuer gibt es keine
    /// Datenquelle: `TrainingPlan` hat kein Startdatum, und `programType`
    /// ist eine interne Template-ID (bei manuell angelegten Plaenen leer),
    /// keine anzeigefertige Kurzform. Verwendet wird stattdessen der
    /// tatsaechliche, immer vorhandene Plan-Name.
    @ViewBuilder
    private var dashboardContextRow: some View {
        let streakWeeks = TrainingCalendarAggregator.weekStreak(
            workoutDates: completedSessions.filter(\.isRealWorkout).map(\.startTime),
            goalPerWeek: profiles.first?.weeklyWorkoutGoal ?? 1
        )
        let planName = activePlans.first?.displayName

        if planName != nil || streakWeeks > 0 {
            DeltiqContextRow([
                planName.map { DeltiqContextItem($0.uppercased(), style: .accent) },
                streakWeeks > 0
                    ? DeltiqContextItem(
                        String(
                            format: String(localized: "dashboard.calendar.streakFormat", bundle: .module),
                            streakWeeks
                        ).uppercased(),
                        style: .neutral
                      )
                    : nil
            ].compactMap { $0 })
        }
    }

    /// DEL-132 (Phase 1): Hero-Reihe iteriert jetzt ueber die User-
    /// gewaehlten Slots (vorher hartcodierte 3-Card-HStack). Length-0
    /// versteckt die Reihe komplett — Power-User die "nur Training,
    /// keine Body-Composition" wollen, koennen das Dashboard auf rein
    /// trainings-zentriertes Layout reduzieren.
    @ViewBuilder
    private var heroMetrics: some View {
        if heroMetricSlots.isEmpty {
            // Length 0 — Hero komplett ausblenden. EmptyView() rendert
            // wirklich nichts; die folgenden Widgets schliessen ohne
            // sichtbare Luecke an die NavBar an.
            EmptyView()
        } else if let latest = measurements.first {
            // UX-Fix 2026-05-21: Equal-Height-Cards. `.fixedSize(vertical:
            // true)` auf der HStack nimmt die maximale intrinsische Hoehe
            // ihrer Kinder; in Kombination mit `.frame(maxHeight:
            // .infinity)` innerhalb jeder MetricCard ziehen alle Karten
            // auf die gleiche Hoehe — bleibt fuer beliebige Slot-Counts
            // (1, 2 oder 3) funktional.
            HStack(spacing: 12) {
                ForEach(heroMetricSlots, id: \.self) { slot in
                    heroMetricCard(for: slot, measurement: latest)
                        // DEL-132 (Phase 4): Slot-Add/Remove-Transition.
                        // Wenn ein User in Settings einen Slot toggled, sliden
                        // die Cards rein/raus statt schlagartig zu poppen.
                        // .asymmetric: insertion mit scale+opacity (zoom-in),
                        // removal mit opacity-only (fade-out, kein Pop-shrink).
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            // DEL-132 (Phase 4): Spring-Animation auf die ganze HStack,
            // sodass auch das Reorder der Cards (Drag-and-Drop in
            // Settings) sanft animiert — sonst springen Cards beim
            // Index-Swap hart in ihre neue Position.
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: heroMetricSlots)
        } else {
            EmptyMetricsCard()
        }
    }

    /// DEL-132 (Phase 1): Slot → MetricCard-Mapping. Pro `HeroMetricType`
    /// ein Switch-Case der die richtigen Label/Wert/Unit-Werte aus dem
    /// `BodyMeasurement` + Profile zusammensetzt. Default-Label-
    /// Source ist jetzt `heroMetric.*.label` (statt der alten
    /// `metric.*`-Keys), damit Card-Label und Settings-Picker-Label
    /// aus EINER Catalog-Quelle kommen.
    @ViewBuilder
    private func heroMetricCard(for slot: HeroMetricType,
                                measurement latest: BodyMeasurement) -> some View {
        let label = String(localized: String.LocalizationValue(slot.localizationKey),
                           bundle: .module)
        switch slot {
        case .weight:
            // Signature-Geruest 2.16: eine Nachkommastelle statt zwei -
            // "70,00 kg" taeuschte eine Praezision vor, die eine
            // Personenwaage (100g-Aufloesung) gar nicht liefert.
            MetricCard(
                label: label,
                value: latest.weightKg.truncated(to: 1).formattedOneDecimal,
                unit: "kg",
                delta: weeklyWeightDelta()
            )
        case .bodyFatNavy:
            MetricCard(
                label: label,
                value: latest.navyBodyFatPct?.truncated(to: 1).formattedOneDecimal ?? "—",
                unit: latest.navyBodyFatPct != nil ? "%" : nil,
                delta: nil
            )
        case .ffmi:
            MetricCard(
                label: label,
                value: latest.ffmi?.truncated(to: 1).formattedOneDecimal ?? "—",
                unit: nil,
                delta: nil
            )
        case .leanMass:
            MetricCard(
                label: label,
                value: latest.fatFreeMassKg?.truncated(to: 1).formattedOneDecimal ?? "—",
                unit: latest.fatFreeMassKg != nil ? "kg" : nil,
                delta: nil
            )
        case .bmi:
            let bmi = computedBMI(measurement: latest)
            MetricCard(
                label: label,
                value: bmi?.truncated(to: 1).formattedOneDecimal ?? "—",
                unit: nil,
                delta: nil
            )
        case .waterTodayMl:
            // DEL-132 (Phase 2): Wasser-Hero. Semantisch-korrekte-
            // Rendering-Iteration 2026-05-21: ml ist eine diskrete
            // Einheit — "1250,00 ml" macht keinen Sinn, weil keine
            // halben ml getrunken werden. Plain Int-String.
            MetricCard(
                label: label,
                value: "\(todayWaterMl)",
                unit: "ml",
                delta: nil
            )
        case .workoutsThisWeek:
            // DEL-132 (Phase 2): Workouts-this-Week — diskreter Counter,
            // keine halben Workouts. Plain Int-String, kein 2-Dezimal-
            // Padding (siehe waterTodayMl-Kommentar).
            MetricCard(
                label: label,
                value: "\(workoutsThisWeekCount)",
                unit: nil,
                delta: nil
            )
        case .restingHR:
            // DEL-132 (Phase 3): Ruhepuls in BPM — diskreter Counter
            // pro Minute, keine "halben Pulse". Round-half-up + Int.
            // DEL-132 (Phase 4): wenn HealthKit-Auth fehlt, rendert
            // die Card tappable mit Lock-Hint und triggert
            // requestAuthorization() — User landet sofort in der iOS-
            // System-Permission-Sheet, statt vor einem stumm leeren
            // "—" zu stehen.
            healthKitGatedCard(
                label: label,
                value: restingHRValue.map { String(Int($0.rounded())) },
                unit: "bpm"
            )
        case .stepsToday:
            // DEL-132 (Phase 3): Schritte — keine halben Schritte. Int.
            // DEL-132 (Phase 4): gleiche Permission-CTA-Gating wie
            // restingHR.
            healthKitGatedCard(
                label: label,
                value: stepsTodayValue.map { String(Int($0.rounded())) },
                unit: nil
            )
        }
    }

    /// DEL-132 (Phase 1): BMI = weight_kg / (height_m)². Nil-Fallback
    /// wenn entweder kein Measurement existiert oder die Profile-Hoehe
    /// 0 ist (theoretisch unmoeglich nach Onboarding, defensiv weil
    /// SwiftData ja keine Mind-Constraint hat).
    private func computedBMI(measurement: BodyMeasurement) -> Double? {
        guard let profile = profiles.first, profile.heightCm > 0 else { return nil }
        let heightM = profile.heightCm / 100.0
        return measurement.weightKg / (heightM * heightM)
    }

    /// DEL-132 (Phase 2): Summe aller heutigen `WaterEntry.amountMl`.
    /// In-memory-Filter weil SwiftData-`#Predicate` mit Calendar-startOfDay
    /// nicht zuverlaessig laeuft (siehe WaterTrackerView). 0 ist valider
    /// Returnwert ("noch nichts getrunken heute").
    private var todayWaterMl: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return waterEntries
            .filter { $0.date >= startOfToday }
            .reduce(0) { $0 + $1.amountMl }
    }

    /// DEL-132 (Phase 2): Anzahl completed-non-rest-day-Sessions in der
    /// aktuellen Kalenderwoche. Calendar.current respektiert das Locale-
    /// Setting (Mo-first in DE, So-first in US). Wenn die Woche im
    /// Calendar-Lookup nil ist (sehr selten — zerstoertes Profil),
    /// 0 zurueck.
    private var workoutsThisWeekCount: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return 0
        }
        return completedSessions
            .filter { !$0.isRestDay && week.contains($0.startTime) }
            .count
    }

    /// DEL-132 (Phase 4): MetricCard mit HealthKit-Permission-Gating.
    /// Drei Render-Branches:
    ///   1. Authorized + Value vorhanden → normale MetricCard mit Wert.
    ///   2. Authorized + nil Value (kein Sample) → MetricCard mit "—",
    ///      KEIN Tap-Action (Daten kommen sobald Watch/iPhone schreibt).
    ///   3. Nicht-authorized → tappable Card mit "—" + Lock-Hint,
    ///      onTap triggert `healthKit.requestAuthorization()`. iOS
    ///      zeigt seine native Permission-Sheet; bei Approval refreshed
    ///      die `.task(id:)`-Anbindung automatisch.
    @ViewBuilder
    private func healthKitGatedCard(label: String, value: String?, unit: String?) -> some View {
        let isAuthorized = healthKit.authorizationStatus == .sharingAuthorized

        if isAuthorized {
            // Branch 1+2: zugriff erlaubt, render normal (Value oder "—").
            MetricCard(
                label: label,
                value: value ?? "—",
                unit: value != nil ? unit : nil,
                delta: nil
            )
        } else {
            // Branch 3: Permission fehlt — tappable Card mit Lock-Hint.
            Button {
                Task {
                    await healthKit.requestAuthorization()
                    // Nach User-Entscheidung neu fetchen — falls die
                    // Permission gerade gegeben wurde, lebt der Wert
                    // sofort im naechsten Render-Cycle.
                    await refreshHealthKitHeroValues()
                }
            } label: {
                MetricCard(
                    label: label,
                    value: "—",
                    unit: nil,
                    delta: nil
                )
                .overlay(alignment: .topTrailing) {
                    // Kleines Lock-Icon oben rechts → "tap to connect"-Hint.
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("heroMetric.hk.permissionNeeded.a11y", bundle: .module))
        }
    }

    /// DEL-132 (Phase 3): Async refresh fuer HealthKit-gestuetzte Hero-
    /// Slots. Nur die tatsaechlich aktiven Slots werden geholt — wenn
    /// User keinen restingHR/stepsToday-Slot in den Hero-Settings hat,
    /// triggert das gar keinen HK-Read. Parallel via `async let`, weil
    /// die zwei Reads unabhaengig sind.
    private func refreshHealthKitHeroValues() async {
        let slots = heroMetricSlots
        let needsRestingHR = slots.contains(.restingHR)
        let needsSteps     = slots.contains(.stepsToday)
        guard needsRestingHR || needsSteps else { return }

        async let hr: Double?    = needsRestingHR ? await healthKit.latestRestingHeartRateBPM() : nil
        async let steps: Double? = needsSteps     ? await healthKit.stepCountToday()            : nil

        let resolvedHR    = await hr
        let resolvedSteps = await steps

        // Nur setzen wenn Slot aktiv ist — Stale-Reads von vorher-
        // gepulled-jetzt-deaktiviert wuerden sonst auf der UI haengen
        // bleiben. Beim Deaktivieren raeumen wir entsprechend auf nil.
        restingHRValue  = needsRestingHR ? resolvedHR    : nil
        stepsTodayValue = needsSteps     ? resolvedSteps : nil
    }

    /// Thin glue over `BodyCalculations.weeklyWeightDelta`. The Core algorithm
    /// is widget/watch-shareable; this view-side wrapper just adapts the @Query
    /// result to the value-type API.
    private func weeklyWeightDelta() -> Double? {
        BodyCalculations.weeklyWeightDelta(measurements: measurements)
    }

    // MARK: - Trend chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("dashboard.trend.title", bundle: .module)
                    .font(.headline)
                Spacer()
                if !forecastPoints.isEmpty {
                    Text("dashboard.trend.forecast.legend", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if measurements.isEmpty {
                // UX-201: 4-teiliger Premium-Empty-State mit CTA in die
                // Measurement-Tab. Vorher: 2-teilige Label-Row ohne Aktion.
                DashboardEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "dashboard.trend.emptyTitle",
                    description: "dashboard.trend.emptyDescription",
                    ctaTitle: "dashboard.empty.cta.addMeasurement",
                    ctaAction: { navigation.selectedTab = .measurement }
                )
            } else if measurements.count < 3 {
                InsufficientDataCard(currentCount: measurements.count)
            } else {
                Chart {
                    // Historical points + connecting line.
                    ForEach(historicalPoints, id: \.date) { p in
                        LineMark(
                            x: .value("Datum", p.date),
                            y: .value("Gewicht (kg)", p.weight),
                            series: .value("Serie", "Tatsächlich")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.deltiqOrange)

                        PointMark(
                            x: .value("Datum", p.date),
                            y: .value("Gewicht (kg)", p.weight)
                        )
                        .foregroundStyle(Color.deltiqOrange)
                        .symbolSize(40)
                    }

                    // Forecast: starts at the last historical point so the line stays
                    // continuous, then extends to +4w and (when reliable) +8w.
                    if !forecastPoints.isEmpty {
                        ForEach(forecastPoints, id: \.date) { p in
                            LineMark(
                                x: .value("Datum", p.date),
                                y: .value("Gewicht (kg)", p.weight),
                                series: .value("Serie", "Prognose")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                    }

                    // Goal-weight reference line if the user set one in onboarding.
                    if let goal = profiles.first?.goalWeightKg {
                        RuleMark(y: .value("Ziel", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(.green.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text(String(localized: "dashboard.goal.line", bundle: .module)
                                        .replacingOccurrences(of: "%@",
                                                              with: goal.truncated(to: 1).formattedOneDecimal))
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 220)

                if isTrendUnreliable {
                    Label {
                        Text("dashboard.trend.unstable", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                } else if forecastPoints.isEmpty && measurements.count >= 3 {
                    Label {
                        Text("dashboard.trend.needMore", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        // DEL-103: Bento-Card.
        .deltiqCardStyle()
    }

    /// Chronologically-ordered historical points (Charts wants left-to-right by date).
    private var historicalPoints: [(date: Date, weight: Double)] {
        measurements.reversed().map { ($0.date, $0.weightKg) }
    }

    /// Forecast series: anchors at the last historical point, then extends to +4w (and
    /// +8w when both projections are available). Empty when the trend is unreliable
    /// or `projectWeightTrend` returns nil — caller branches on that.
    private var forecastPoints: [(date: Date, weight: Double)] {
        guard !isTrendUnreliable,
              let lastHistorical = measurements.first
        else { return [] }

        let anchor = (date: lastHistorical.date, weight: lastHistorical.weightKg)
        let p4 = BodyCalculations.projectWeightTrend(measurements: measurements, weeksAhead: 4)
        let p8 = BodyCalculations.projectWeightTrend(measurements: measurements, weeksAhead: 8)

        var points: [(date: Date, weight: Double)] = [anchor]
        if let p4 {
            points.append((date: lastHistorical.date.addingTimeInterval(4 * 7 * 24 * 3600), weight: p4))
        }
        if let p8 {
            points.append((date: lastHistorical.date.addingTimeInterval(8 * 7 * 24 * 3600), weight: p8))
        }
        // Just the anchor isn't a useful "forecast line".
        return points.count >= 2 ? points : []
    }

    private var isTrendUnreliable: Bool {
        BodyCalculations.isTrendUnreliable(measurements: measurements)
    }

    // MARK: - Plan Day Card ("Was steht heute an?")

    @ViewBuilder
    private var planDayCard: some View {
        if let plan = activePlans.first, !plan.days.isEmpty {
            // DEL-133: State-Priority-Fix. Wenn eine Session GERADE laeuft
            // (auch wenn sie auf einem ANDEREN Tag als dem regulär-nächsten
            // gestartet wurde), zeigen wir die Running-Session statt der
            // Plan-Sequenz. Vorher rendete das Dashboard stur "Ganzkörper A
            // — direkt starten", waehrend der User in Wirklichkeit
            // "Ganzkörper B" im Plan-Tab gestartet hatte.
            //
            // Priorisierung:
            //   1. Wenn openSession.day im aktuellen Plan existiert →
            //      Zeige diesen Day (User sieht: "Ganzkörper B läuft").
            //      activeWorkoutButton rendert dann den Resume-Button.
            //   2. Sonst (kein Workout aktiv, oder aktiv auf einem anderen
            //      Plan) → Zeige den planmaessig naechsten Tag wie bisher.
            let runningDay: TrainingDay? = openSessions.first.flatMap { open in
                guard let sessionDay = open.day,
                      sessionDay.plan?.persistentModelID == plan.persistentModelID
                else { return nil }
                return sessionDay
            }
            let day = runningDay ?? nextScheduledDay(in: plan)
            // Nur explizit als .rest markierte Tage gelten als Ruhetag.
            // Leere Trainingstage (User noch nicht fertig konfiguriert) sind
            // KEINE Ruhetage — sie zeigen den disabled "Training starten"-
            // Button mit Hint, dass Uebungen fehlen (DEL-021/023).
            let isRestDay = day.type == .rest
            let isCurrentlyRunning = runningDay != nil
            // Signature-Geruest 1.4: die Plan-Karte traegt die Hauptaussage
            // des Screens - die eine erlaubte Orange-Kante links pro Screen.
            // Geprueft (wiederholt): dieser accentEdge:true und der im
            // else-Zweig unten schliessen sich gegenseitig aus (Normal- vs.
            // Leerzustand desselben Plan-Day-Slots, nie beide gleichzeitig
            // sichtbar) - genau die von Abschnitt 1.4 erlaubte Ausnahme.
            DeltiqCard(accentEdge: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // DEL-105: Brand-Akzent fuer Trainings-Tage statt iOS-Blau.
                    // Signature-Geruest: Rest-Day-Branch ist jetzt ebenfalls
                    // Orange statt Purple - ein Screen, ein Akzent.
                    // DEL-133: Running-Branch bekommt play.circle.fill als
                    // Icon — User sieht sofort, dass das Workout AKTIV ist.
                    Image(systemName: isCurrentlyRunning
                        ? "play.circle.fill"
                        : (isRestDay ? "bed.double.fill" : "calendar.badge.clock"))
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.deltiqOrange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        // DEL-133: drei-Wege-Label.
                        //   * running  → "Aktuell läuft" (war: "Nächstes Training")
                        //   * rest-day → "Heute Ruhetag"
                        //   * default  → "Nächstes Training"
                        Text(isCurrentlyRunning
                             ? "dashboard.plan.currentlyRunning"
                             : (isRestDay
                                ? "dashboard.plan.todayRestDay"
                                : "dashboard.plan.nextWorkout"),
                             bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // DEL-129: day.displayName statt .name — propagiert
                        // den localizationKey-Lookup ins Banner-Title.
                        Text(day.displayName)
                            .font(.title3.weight(.bold))
                    }
                    Spacer()
                }

                if isRestDay {
                    // DEL-094: Ruhetag bekommt KEINEN fetten Call-to-Action mehr.
                    // Der frühere "Ruhetag abschließen"-Button hat User dazu
                    // verleitet, leere isRestDay-Sessions in den Store zu
                    // schreiben, in der Annahme es sei der Start-Button.
                    // Jetzt: ruhiges Label, kein Aktions-Button.
                    Text("dashboard.plan.restDay", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if !day.activeExercises.isEmpty {
                    exercisesList(for: day)
                }

                if isRestDay {
                    // DEL-096: An Ruhetagen ist "Spontanes Workout" der
                    // primäre Pfad — der User hat den Tag frei vom Plan,
                    // will aber vielleicht trotzdem locker laufen gehen.
                    adHocWorkoutButton(prominent: true)

                    // DEL-094: Sekundärer Skip-Link für User, die den
                    // Plan-Pointer manuell vorwärts schubsen wollen
                    // (z.B. an einem Tag, an dem sie sich doch ausruhen).
                    // Bewusst klein + dezent — nicht der primäre Pfad.
                    Button {
                        markRestDaySkipped(plan: plan, day: day)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                            Text("dashboard.plan.checkoffRestDay.button", bundle: .module)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.deltiqOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("dashboard.plan.checkoffRestDay.a11y", bundle: .module))
                } else {
                    // DEL-042: Button-State adaptiv. Wenn offene Session
                    // existiert: orange "Fortsetzen"-Button, navigiert in die
                    // existing Session. Sonst: blauer "Direkt starten".
                    activeWorkoutButton(plan: plan, day: day)

                    // DEL-096: Sekundärer Ad-Hoc-Link — User darf jederzeit
                    // vom Plan abweichen (z.B. spontan eine Cardio-Einheit
                    // einschieben). Bewusst dezent, kein zweiter Fett-CTA.
                    adHocWorkoutButton(prominent: false)
                }
            }
            }
        } else {
            // No active plan or active plan has no days yet.
            // Signature-Geruest 1.4: gleiche Orange-Kante wie im Haben-
            // Plan-Zweig - die "Hauptaussage" bleibt dieselbe Karte, nur
            // ohne aktiven Plan. Mutual exclusive mit dem accentEdge:true
            // oben (if/else desselben Slots) - siehe Kommentar dort.
            DeltiqCard(accentEdge: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activePlans.isEmpty
                             ? "dashboard.plan.noActivePlan.title"
                             : "dashboard.plan.planEmpty.title",
                             bundle: .module)
                            .font(.body.weight(.semibold))
                        Text(activePlans.isEmpty
                             ? "dashboard.plan.noActivePlan.hint"
                             : "dashboard.plan.planEmpty.hint",
                             bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        navigation.selectedTab = .plan
                    } label: {
                        Text("dashboard.plan.tabShortcut", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // DEL-096: Auch ohne Plan soll der User trainieren können —
                // Ad-Hoc ist hier der einzige Trainings-CTA, also prominent.
                adHocWorkoutButton(prominent: true)
            }
            }
        }
    }

    // MARK: - DEL-100 Coaching Insight

    /// DEL-100: Insight-Card mit personalisierter Coaching-Message. Aktuell
    /// wird nur der `.restDay`-Context aktiv ausgespielt — Plateau-Detection
    /// und CNS-Overload-Schwellen brauchen mehr Wochen-Aggregation (kommt
    /// als naechste Welle, wenn Recovery-Scores im UI-Surface ankommen).
    /// Wenn kein Context greift, rendert die View `EmptyView()` — kein
    /// leerer Card-Slot auf dem Dashboard.
    @ViewBuilder
    private var coachingInsightCard: some View {
        // DEL-166: Wenn das Coaching-Widget aktiv geschaltet ist, MUSS die
        // Karte sichtbar sein — egal ob aktuell ein Coaching-Trigger greift.
        // Vorher returnte die View `EmptyView()` ohne Trigger; das wirkte wie
        // ein kaputtes Feature (Widget an, aber unsichtbar). Jetzt zwei
        // Zustaende: konkreter Insight ODER neutrale Empty-State-Karte.
        // DEL-200: Während einer aktiven Deload-Woche ersetzt der Status-
        // Banner die Coaching-Card komplett — der wichtigste Kontext IST
        // dann der Deload, alles andere wäre Rauschen.
        if isDeloadActive {
            deloadActiveBanner
        } else if let message = currentCoachingMessage {
            coachingInsightContent(message: message)
        } else {
            coachingInsightEmptyContent
        }
    }

    // MARK: - DEL-200 Deload-Apply

    /// DEL-238: Der Timer ODER die Daten.
    ///
    /// Vorher hing das allein an `deload_until`. Der Key ist nicht portabel
    /// und ueberlebt keine Neuinstallation — ging er verloren, verschwand das
    /// Banner und mit ihm der einzige Weg zu `endDeload`, waehrend die
    /// Gewichte reduziert blieben. `deloadOriginalWeight != nil` ist die
    /// belastbare Wahrheit, weil es im Backup mitwandert. Die Oder-Verknuepfung
    /// heilt diese Nutzer, ohne das Timer-Verhalten zu aendern.
    private var isDeloadActive: Bool {
        deloadUntil > Date().timeIntervalSince1970
            || DeloadManager.isActive(in: modelContext)
    }

    /// True wenn die aktuelle Coaching-Message der Deload-Vorschlag ist —
    /// dann rendert die Card zusätzlich den Apply-Button. P1-Kontexte
    /// gewinnen weiterhin (kein Button unter einer CNS-Warnung).
    private var showsDeloadApplyAction: Bool {
        activeCoachingContext == nil && activeSoftCoachingContext == .deloadRecommended
    }

    /// Startet die Deload-Woche: Gewichte via DeloadManager halbieren,
    /// Ablaufdatum setzen. Bei 0 angepassten Übungen (kein aktiver Plan
    /// mit Gewichten) passiert nichts — kein Phantom-Deload-Banner.
    private func applyDeload() {
        let adjusted = (try? DeloadManager.startDeload(in: modelContext)) ?? 0
        guard adjusted > 0 else { return }
        let until = Date().addingTimeInterval(
            TimeInterval(DeloadManager.defaultDurationDays * 24 * 3600)
        )
        deloadUntil = until.timeIntervalSince1970
    }

    /// Beendet die Deload-Woche (manuell oder via Auto-Expiry):
    /// Original-Gewichte zurück, Flag löschen.
    private func endDeload() {
        _ = try? DeloadManager.endDeload(in: modelContext)
        deloadUntil = 0
    }

    /// Auto-Restore beim Dashboard-Erscheinen: Deload abgelaufen → Gewichte
    /// zurückschreiben. Wird in `.task` der View aufgerufen — der typische
    /// "App nach einer Woche wieder öffnen"-Pfad.
    private func autoEndDeloadIfExpired() {
        guard deloadUntil > 0, !isDeloadActive else { return }
        endDeload()
    }

    private var deloadActiveBanner: some View {
        // Signature-Geruest 1.7: Teal war Sonderfarbe fuer den Deload-
        // Hinweis, verletzt aber "alles Interaktive/Aktive ist Orange" —
        // anders als der Health-Rot-Fall (2.5) hat Teal keine externe
        // Marken-Begruendung. Auf Orange vereinheitlicht.
        DeltiqCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.down.heart.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(
                        format: String(localized: "dashboard.deload.activeBanner", bundle: .module),
                        Date(timeIntervalSince1970: deloadUntil)
                            .formatted(date: .abbreviated, time: .omitted)
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    Button {
                        withAnimation { endDeload() }
                    } label: {
                        Text("dashboard.deload.endButton", bundle: .module)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.deltiqOrange)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Liefert den aktuellen Coaching-Text — oder nil, wenn kein Trigger
    /// greift bzw. kein Profil existiert. Caller (`coachingInsightCard`)
    /// rendert dann den Empty-State.
    private var currentCoachingMessage: String? {
        guard let profile = profiles.first else { return nil }
        // DEL-167: zweistufige Auswertung — P1 (echte Warnung) gewinnt vor
        // P2 (Soft-Insight). Nur wenn beide leer sind, faellt die View auf
        // den neutralen Empty-State zurueck.
        if let context = activeCoachingContext {
            let msg = CoachingMessageProvider.message(
                for: context,
                tone: profile.coachingTone,
                goal: profile.trainingGoal
            )
            if !msg.isEmpty { return msg }
        }
        // DEL-206: P1.5 — goal-basierte Tages-Empfehlung. Kreuzt den
        // heutigen/gestrigen Workout-State mit dem TrainingGoal über die
        // gleiche Matrix-Auflösung wie die P1-Warnungen. Rangiert UNTER
        // den echten Warnungen (CNS-Overload schlägt "mach noch Cardio"),
        // aber ÜBER den generischen Soft-Komplimenten.
        if let daily = activeGoalCoachingContext {
            let msg = CoachingMessageProvider.message(
                for: daily,
                tone: profile.coachingTone,
                goal: profile.trainingGoal
            )
            if !msg.isEmpty { return msg }
        }
        if let soft = activeSoftCoachingContext {
            let msg = CoachingMessageProvider.softMessage(
                for: soft,
                tone: profile.coachingTone
            )
            if !msg.isEmpty { return msg }
        }
        // DEL-168: P3 — Edu-Coaching-Tipp als Fallback, wenn weder Warnung
        // noch datengetriebener Soft-Insight greift. Tag-stabil rotierend.
        let eduMsg = CoachingMessageProvider.eduMessage(for: profile.coachingTone)
        if !eduMsg.isEmpty { return eduMsg }
        return nil
    }

    // MARK: - DEL-206 Goal-Based Daily Coaching (StateAnalyzer)

    /// Tagesaktueller Trigger für die Goal-Matrix. Priorität laut Ticket:
    /// heutige Morgen-Session > gestrige High-Fatigue. Die zielbasierte
    /// Ausformulierung übernimmt der Provider über
    /// `coaching.{context}.{tone}.{goal}`.
    ///
    ///   * **morningStrengthDone** — heute vor 13:00 ein Workout mit
    ///     Kraft-Anteil abgeschlossen (mixed zählt als Kraft).
    ///   * **morningCardioDone**   — heute vor 13:00 NUR Cardio.
    ///   * **highFatigueYesterday** — gestern >= 20 Sätze ODER eine
    ///     Session > 90 Minuten.
    ///
    /// "Morgen" = startOfDay bis 13:00. Wer die App erst um 14:00 öffnet,
    /// sieht die Empfehlung für den Rest des Tages — das Workout VON
    /// heute Morgen bleibt ja relevant.
    private var activeGoalCoachingContext: CoachingContext? {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let onePM = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now) else {
            return nil
        }

        let morningSessions = completedSessions.filter {
            $0.isRealWorkout && $0.startTime >= startOfDay && $0.startTime < onePM
        }
        if !morningSessions.isEmpty {
            // Reines Cardio nur, wenn ALLE Morgen-Sessions pure Cardio
            // waren — eine Mixed-Session hat Kraft-Anteil und triggert
            // die Strength-Variante (Ticket: "bzw. Strength-Profile").
            let allCardio = morningSessions.allSatisfy { $0.sessionCategory == .pureCardio }
            return allCardio ? .morningCardioDone : .morningStrengthDone
        }

        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: startOfDay) else {
            return nil
        }
        let yesterdaySessions = completedSessions.filter {
            $0.isRealWorkout && $0.startTime >= yesterdayStart && $0.startTime < startOfDay
        }
        let totalSets = yesterdaySessions.reduce(0) { $0 + $1.totalSets }
        let hadLongSession = yesterdaySessions.contains { $0.durationMinutes > 90 }
        if totalSets >= 20 || hadLongSession {
            return .highFatigueYesterday
        }
        return nil
    }

    // MARK: - DEL-167 Soft-Coaching-Trigger

    /// Auswahl in Prioritaets-Reihenfolge — erster Treffer gewinnt. Wird nur
    /// erreicht, wenn `activeCoachingContext` nil ist (keine P1-Warnung).
    /// Nachtrag (Audit): diese Liste war ueber mehrere Tickets hinweg nicht
    /// mitgepflegt worden - hier vollstaendig, in der tatsaechlichen
    /// Code-Reihenfolge:
    ///
    ///   1. **cardioVolumeSpike**   — Lauf-KM dieser Woche > 120% der
    ///      Vorwoche (DEL-248). Rangiert VOR deloadRecommended (DEL-249):
    ///      struktureller Schaden durch zu schnell gesteigertes Laufvolumen
    ///      (Sehnen/Baender) braucht Wochen zum Heilen, ZNS-Ermuedung durch
    ///      Krafttraining nur 1-2 Tage - das akutere Verletzungsrisiko
    ///      gewinnt, falls ein Hybrid-Athlet beide Ramps gleichzeitig faehrt.
    ///   2. **deloadRecommended**   — Overreaching-Muster im Krafttraining
    ///      (DEL-196). Gesundheitsrelevanter als jedes Kompliment.
    ///   3. **reEntry**             — Lange nicht trainiert (≥5 Tage Pause).
    ///      Der wichtigste Re-Engagement-Hinweis.
    ///   4. **volumeRecord**        — Letzte volle Woche war die
    ///      volumenstaerkste der Historie (DEL-198).
    ///   5. **cardioMissedLongRun** — Plan sieht einen langen Lauf vor, aber
    ///      keiner in den letzten 7 Tagen geloggt (DEL-248).
    ///   6. **postVolume**/**postCardio** — gestrige Session ueber 5.000 kg
    ///      bzw. 5 km (Volumen gewinnt bei Gleichstand).
    ///   7. **streak**              — ≥5 reale Sessions in den letzten 7 Tagen.
    ///   8. **trainedYesterday**    — irgendeine reale Session gestern
    ///      (DEL-211, faengt alles ab, was 6. nicht schon abdeckt).
    ///   9. **planPreview**         — heutiger Plan-Tag ist ein Trainings-Tag.
    ///  10. **measurementOverdue**/**hydrationLow**/**backupOverdue** —
    ///      Feature-Nudges, niedrigste Prioritaet.
    /// Sonst nil → Dashboard zeigt den neutralen Empty-State (DEL-166).
    ///
    /// **cardioJunkMiles** ist definiert (Case + dreisprachige Catalog-Keys),
    /// aber bewusst NICHT Teil dieser Liste - siehe Doc-Kommentar auf
    /// `CoachingContext.cardioJunkMiles` fuer den Grund.
    private var activeSoftCoachingContext: CoachingContext? {
        // DEL-249: Cardio-Volumen-Spike zuerst - anders als reEntry/
        // deloadRecommended (die sich durch ihre Bedingungen praktisch
        // gegenseitig ausschliessen) koennen deloadRecommended und
        // cardioVolumeSpike bei einem Hybrid-Athleten GLEICHZEITIG
        // zutreffen. Cardio gewinnt bewusst: struktureller Schaden durch
        // zu schnell gesteigertes Laufvolumen (Sehnen/Baender) braucht
        // Wochen zum Heilen, ZNS-Ermuedung durch Krafttraining nur 1-2 Tage.
        if isCardioVolumeSpikeActive { return .cardioVolumeSpike }
        // DEL-196: gesundheitsrelevanter als jedes Post-Workout-Kompliment.
        // Praktisch nie gleichzeitig mit reEntry (Deload braucht hohe
        // RECENT-Aktivität, reEntry Inaktivität).
        if shouldRecommendDeload { return .deloadRecommended }
        if daysSinceLastRealSession >= 5 { return .reEntry }
        // DEL-198: Volumen-Rekord schlägt die generischen Post-Workout-
        // Komplimente — "beste Woche ever" ist die stärkere Nachricht.
        if hadVolumeRecordWeek { return .volumeRecord }
        // DEL-248: ein fehlendes Schluessel-Training (Long Run) ist wichtiger
        // als die generischen Post-Workout-Komplimente unten.
        if isLongRunOverdueForActivePlan { return .cardioMissedLongRun }
        if let yKm = yesterdayCardioDistanceKm, let yVol = yesterdayVolumeKg {
            if yVol >= 5_000 { return .postVolume }
            if yKm >= 5      { return .postCardio }
        } else if let yVol = yesterdayVolumeKg, yVol >= 5_000 {
            return .postVolume
        } else if let yKm = yesterdayCardioDistanceKm, yKm >= 5 {
            return .postCardio
        }
        if last7DaysRealSessionCount >= 5 { return .streak }
        // DEL-211: JEDE gestrige reale Session (auch spontane Workouts
        // unter den postVolume-/postCardio-Schwellen) wird anerkannt,
        // BEVOR der Coach den heutigen Plan-Tag ausruft. Vorher: User
        // trainierte gestern moderat → fiel durch alle Gestern-Checks →
        // "Heute ist Trainingstag!" wirkte geschichtsvergessen.
        if !realSessionsOn(daysBeforeToday: 1).isEmpty { return .trainedYesterday }
        // DEL-211: Plan-Vorschau nur, wenn heute noch NICHT trainiert
        // wurde — sonst ruft der Coach abends den Trainingstag aus,
        // den der User gerade hinter sich hat.
        if hasTrainingPlannedToday && realSessionsOn(daysBeforeToday: 0).isEmpty {
            return .planPreview
        }
        // DEL-198: Feature-Nudges — nur für User, die das Feature aktiv
        // nutzen (sonst nerven die Hinweise Nicht-Nutzer).
        if isMeasurementOverdue { return .measurementOverdue }
        if isHydrationLow { return .hydrationLow }
        // DEL-177: Backup-Reminder als letzte Soft-Stufe vor dem Empty-State.
        // Niedrigste Prio — kein Trainings-Insight ist relevanter als eine
        // Backup-Erinnerung. Trigger nur, wenn der User auch echt was zu
        // sichern HAT (sonst nervt der Hinweis frische Installs).
        if shouldShowBackupReminder { return .backupOverdue }
        return nil
    }

    // MARK: - DEL-198 Coach-Trigger

    /// True wenn die letzte VOLLE Kalenderwoche die volumenstärkste der
    /// gesamten Historie war. Mindestens 4 volle Wochen Daten — sonst ist
    /// "Rekord" trivial. Nutzt den getesteten VolumeOverTimeAggregator
    /// (DEL-178) statt eigener Wochen-Bucketing-Logik.
    private var hadVolumeRecordWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        let logs = completedSessions
            .filter(\.isRealWorkout)
            .flatMap(\.logs)
            .map { log -> (date: Date, weightKg: Double, reps: Int, isCardio: Bool, isTimeBased: Bool) in
                let when = log.session?.startTime ?? log.date
                return (when, log.weight, log.reps, log.resolvedIsCardio, log.resolvedIsTimeBased)
            }
        guard let oldest = logs.map(\.date).min() else { return false }
        let weeks = VolumeOverTimeAggregator.aggregate(
            logs: logs, windowStart: oldest, now: now, calendar: calendar
        )
        // Laufende (unvollständige) Woche abschneiden.
        let fullWeeks = weeks.dropLast()
        guard fullWeeks.count >= 4,
              let lastFull = fullWeeks.last, lastFull.volumeKg > 0 else { return false }
        // Strikt größer als ALLE vorherigen vollen Wochen.
        return fullWeeks.dropLast().allSatisfy { $0.volumeKg < lastFull.volumeKg }
    }

    // MARK: - DEL-248 (Phase 4): Cardio-Coaching-Trigger

    /// DEL-248: Cardio-Pendant zu `shouldRecommendDeload` — anders als dort
    /// wird bewusst die LAUFENDE (unvollstaendige) aktuelle Woche gegen die
    /// letzte volle Vorwoche verglichen, nicht zwei volle Wochen. Ziel ist,
    /// einen Spike zu erkennen, WAEHREND er passiert ("schon Donnerstag bei
    /// 130% der Vorwoche") - beim Warten auf eine volle Woche waere die
    /// Warnung erst nuetzlich, wenn die Woche schon vorbei ist.
    private var isCardioVolumeSpikeActive: Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return false
        }
        func cardioKm(weeksAgo: Int) -> Double {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return 0 }
            return completedSessions
                .filter { $0.isRealWorkout && $0.startTime >= start && $0.startTime < end }
                .flatMap(\.logs)
                .filter(\.resolvedIsCardio)
                .compactMap(\.distanceKm)
                .reduce(0, +)
        }
        return CardioCoachingAdvisor.isVolumeSpike(
            currentWeekKm: cardioKm(weeksAgo: 0),
            previousWeekKm: cardioKm(weeksAgo: 1)
        )
    }

    /// DEL-248: der aktive Plan gilt als "hat einen langen Lauf", wenn seine
    /// Cardio-Uebungen mindestens zwei unterschiedliche Ziel-Dauern haben -
    /// die laengste davon ist dann `planLongRunTargetMinutes`. Bewusst
    /// RELATIV zum eigenen Plan statt ein fixer globaler Minutenwert (siehe
    /// Kommentar auf `CardioCoachingAdvisor.isLongRunOverdue`: ein
    /// Anfaenger-Tier setzt seinen langen Lauf bei 50 Minuten an, ein
    /// Performance-Tier bei 85 - ein einzelner globaler Schwellwert wuerde
    /// fuer kuerzere Tiers nie greifen). Hat der Plan gar keine Cardio-
    /// Uebungen, oder sind alle gleich lang (z.B. nur gleich lange Easy
    /// Runs), gibt es keinen erkennbar LAENGEREN Tag ->
    /// `planLongRunTargetMinutes` ist `nil`, die Frage ist gegenstandslos.
    /// Rein strukturell, KEIN Namens-/Key-Abgleich (siehe Datei-Kommentar
    /// auf `CardioCoachingAdvisor`: "Long Run" ist im Generator tatsaechlich
    /// der Uebungs-Name der Tempo-Zone, ein Namensabgleich waere hier
    /// irrefuehrend).
    private var isLongRunOverdueForActivePlan: Bool {
        guard let plan = activePlans.first else { return false }
        let cardioDurations = plan.days
            .flatMap(\.activeExercises)
            .filter(\.isCardio)
            .compactMap(\.targetDurationMinutes)
        var planLongRunTargetMinutes: Int?
        if let maxDuration = cardioDurations.max(), let minDuration = cardioDurations.min(),
           maxDuration > minDuration {
            planLongRunTargetMinutes = maxDuration
        }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        let recentRunMinutes = completedSessions
            .filter { $0.isRealWorkout && $0.startTime >= sevenDaysAgo }
            .flatMap(\.logs)
            .filter(\.resolvedIsCardio)
            .compactMap { $0.durationSeconds.map { $0 / 60 } }
        return CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: planLongRunTargetMinutes,
            recentRunDurationsMinutes: recentRunMinutes
        )
    }

    /// True wenn die letzte Körpermessung > 14 Tage her ist UND der User
    /// das Feature nachweislich nutzt (>= 2 Messungen). `measurements` ist
    /// reverse-sortiert — first = jüngste.
    private var isMeasurementOverdue: Bool {
        guard measurements.count >= 2, let latest = measurements.first else { return false }
        let fourteenDays: TimeInterval = 14 * 24 * 3600
        return Date().timeIntervalSince(latest.date) > fourteenDays
    }

    /// True wenn der User aktiv Wasser trackt (Eintrag in den letzten 7
    /// Tagen), gestern aber unter 1,5 l geloggt hat. Heute bewerten wir
    /// nicht — der Tag läuft ja noch.
    private var isHydrationLow: Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        let recentEntries = waterEntries.filter { $0.date >= weekAgo }
        guard !recentEntries.isEmpty else { return false }   // Feature ungenutzt
        let yesterdayMl = recentEntries
            .filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
            .reduce(0) { $0 + $1.amountMl }
        return yesterdayMl < 1_500
    }

    /// DEL-196: Deload-Trigger. Aggregiert die CNS-Last der letzten drei
    /// vollen Kalenderwochen (älteste zuerst, OHNE die laufende Woche —
    /// die ist unvollständig und würde den Trend fälschlich brechen) plus
    /// die Zahl harter Sessions (Feeling >= 4) der letzten 14 Tage. Die
    /// eigentliche Entscheidung lebt testbar in `DeloadAdvisor`.
    private var shouldRecommendDeload: Bool {
        // DEL-238: Ein Gate, zwei Oberflaechen. Der Apply-Button haengt ueber
        // `showsDeloadApplyAction` an `activeSoftCoachingContext ==
        // .deloadRecommended`, das wiederum an dieser Property — die
        // Coach-Nachricht UND der Button verschwinden also mit derselben
        // Zeile. Ein laufender Deload bleibt davon unberuehrt: Banner und
        // Beenden-Pfad sind bewusst NICHT gegated, sonst entstuende genau die
        // Sackgasse, die DEL-238 schliesst.
        guard deloadEnabled else { return false }
        // DEL-200: Während einer laufenden Deload-Woche keine erneute
        // Empfehlung — die Gewichte sind ja schon reduziert.
        guard !isDeloadActive else { return false }
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return false
        }
        // Drei volle Wochen: [now-3w ... now-2w), [now-2w ... now-1w), [now-1w ... currentWeekStart)
        var weeklyLoads: [Double] = []
        for offset in stride(from: -3, through: -1, by: 1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return false }
            // DEL-236: `strengthCNSLoad` statt `totalCNSLoad` — Laufen zaehlt
            // nicht mehr mit. Vorher konnte ein gesteigertes Laufpensum plus
            // zwei anstrengende Laeufe eine Deload-Empfehlung ausloesen, die
            // die LANGHANTEL-Gewichte halbiert, obwohl sich am Krafttraining
            // nichts geaendert hatte.
            let load = completedSessions
                .filter { $0.isRealWorkout && $0.startTime >= start && $0.startTime < end }
                .reduce(0.0) { $0 + $1.strengthCNSLoad }
            weeklyLoads.append(load)
        }
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? .distantPast
        // DEL-236: Ein zerstoerender Halbmarathon ist eine harte Session, sagt
        // aber nichts ueber die Ermuedung beim Bankdruecken. Nur Sessions mit
        // Kraftanteil zaehlen.
        let hardSessions = completedSessions.filter {
            $0.isRealWorkout
            && $0.startTime >= fourteenDaysAgo
            && DeloadAdvisor.isHardStrengthSession(
                feeling: $0.sessionFeeling,
                containsStrengthWork: $0.containsStrengthWork
            )
        }.count
        return DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: weeklyLoads,
            hardSessionCount: hardSessions
        )
    }

    /// DEL-177: Trigger-Logik für den 30-Tage-Backup-Reminder.
    ///
    ///   - Nie exportiert UND ≥ 10 reale Sessions (= User hat echt was zu
    ///     sichern) → trigger.
    ///   - Letzter Export > 30 Tage her UND ≥ 1 reale Session seither →
    ///     trigger.
    ///
    /// Wir koppeln den Hinweis an Trainings-Aktivität, damit frische
    /// Installs nicht sofort mit "Backup machen!" empfangen werden.
    private var shouldShowBackupReminder: Bool {
        let totalRealSessions = completedSessions.filter(\.isRealWorkout).count
        if lastDataExportAt == 0 {
            return totalRealSessions >= 10
        }
        let exportDate = Date(timeIntervalSince1970: lastDataExportAt)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        guard Date().timeIntervalSince(exportDate) >= thirtyDays else {
            return false
        }
        // Nur, wenn seit dem letzten Backup auch was Neues passiert ist.
        let newSessionsSinceBackup = completedSessions.filter {
            $0.isRealWorkout && $0.startTime > exportDate
        }.count
        return newSessionsSinceBackup >= 1
    }

    /// Maximal-Volumen ueber alle gestern (Kalendertag = today-1) abgeschlossenen
    /// realen Sessions. Nil = keine Session gestern.
    private var yesterdayVolumeKg: Double? {
        let sessions = realSessionsOn(daysBeforeToday: 1)
        guard !sessions.isEmpty else { return nil }
        return sessions.map(\.totalVolumeKg).max()
    }

    /// Maximal-Cardio-Distanz (km) ueber alle gestrigen Sessions.
    /// `WorkoutSession.totalDistanceKm` (DEL-081) summiert Logs.
    private var yesterdayCardioDistanceKm: Double? {
        let sessions = realSessionsOn(daysBeforeToday: 1)
        guard !sessions.isEmpty else { return nil }
        return sessions.map(\.totalDistanceKm).max()
    }

    /// Anzahl realer Sessions in den letzten 7 Tagen (rolling, inkl. heute).
    private var last7DaysRealSessionCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return completedSessions.filter { $0.isRealWorkout && $0.startTime >= cutoff }.count
    }

    /// Tage seit der juengsten realen Session. `Int.max` wenn nie trainiert
    /// → triggert reEntry nicht (keine Daten = kein Hinweis).
    private var daysSinceLastRealSession: Int {
        let realSessions = completedSessions.filter(\.isRealWorkout)
        guard let latest = realSessions.map(\.endTime).max() else { return Int.max }
        let cal = Calendar.current
        let start = cal.startOfDay(for: latest)
        let today = cal.startOfDay(for: Date())
        return cal.dateComponents([.day], from: start, to: today).day ?? Int.max
    }

    /// True wenn der heutige Plan-Eintrag ein Trainings-Tag ist (kein Rest).
    private var hasTrainingPlannedToday: Bool {
        guard let plan = activePlans.first, !plan.days.isEmpty else { return false }
        let day = nextScheduledDay(in: plan)
        return day.type != .rest
    }

    /// Real-Workout-Sessions, deren `startTime` im Kalendertag `today − N`
    /// liegt. Ohne reine Rest-Day-Marker / leere Ad-hoc-Sweeps.
    private func realSessionsOn(daysBeforeToday n: Int) -> [WorkoutSession] {
        let cal = Calendar.current
        guard let dayStart = cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: Date())),
              let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)
        else { return [] }
        return completedSessions.filter {
            $0.isRealWorkout && $0.startTime >= dayStart && $0.startTime < dayEnd
        }
    }

    /// DEL-100: Coaching-Insight in der normalen Karte statt eines eigenen
    /// Orange-Tints. Handoff 2.1: "der Inhalt traegt sich selbst, der Tint
    /// ist ueberfluessig" — die visuelle Differenzierung von der Plan-Karte
    /// kommt jetzt darueber, dass NUR die Plan-Karte die Orange-Kante hat.
    private func coachingInsightContent(message: String) -> some View {
        DeltiqCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    // DEL-200: Apply-Button direkt unter der Deload-Empfehlung —
                    // aus dem Hinweis wird eine Ein-Tap-Handlung.
                    if showsDeloadApplyAction {
                        Button {
                            withAnimation { applyDeload() }
                        } label: {
                            Label {
                                Text("dashboard.deload.applyButton", bundle: .module)
                            } icon: {
                                Image(systemName: "arrow.down.heart")
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.deltiqOrange)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// DEL-166: Neutraler Empty-State, wenn das Widget aktiv ist, aber gerade
    /// kein Coaching-Trigger anliegt (kein CNS-Overload, kein Plan-Ruhetag).
    /// Gleiche Karte wie der Insight-Zustand — der gedaempfte Ton kommt jetzt
    /// nur noch aus Icon-Deckkraft + Copy, nicht mehr aus einem eigenen,
    /// schwaecheren Tint.
    private var coachingInsightEmptyContent: some View {
        DeltiqCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange.opacity(0.7))
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("coaching.empty.title", bundle: .module)
                        .font(.subheadline.weight(.semibold))
                    Text("coaching.empty.message", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Wahlt den passenden Coaching-Context aus dem Heute-Zustand des
    /// Plans und der juengsten Trainings-Last. Prioritaet:
    ///   1. **`.cnsOverloaded`** — eine `isCNSOverloaded`-Session in den
    ///      letzten 48h. Hat Vorrang vor Plan-Ruhetag, weil "ZNS gegrillt"
    ///      ein wichtigerer Hinweis ist als "heute ist Mittwoch-Pause".
    ///   2. **`.restDay`** — heutiger Plan-Tag ist `.rest`.
    ///   3. Sonst nil (kein Coaching-Card auf dem Dashboard).
    /// Plateau-Detection + newPR sind Folge-Wellen — brauchen weitere
    /// Wochen-Aggregation (PR-Diff-Auswertung, Progressions-Slope).
    private var activeCoachingContext: CoachingContext? {
        if isRecentSessionCNSOverloaded { return .cnsOverloaded }
        guard let plan = activePlans.first, !plan.days.isEmpty else { return nil }
        let day = nextScheduledDay(in: plan)
        if day.type == .rest { return .restDay }
        return nil
    }

    /// True wenn die JUENGSTE abgeschlossene reale Session (kein Rest-Day-
    /// Marker, kein Adhoc-Empty) innerhalb der letzten 48h liegt UND
    /// `isCNSOverloaded == true`. 48h Fenster, weil das dem 72h-Recovery-
    /// Bucket aus `ExerciseScoring` entspricht — danach ist die ZNS-Last
    /// bereits weitgehend abgebaut.
    private var isRecentSessionCNSOverloaded: Bool {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? .distantPast
        // `completedSessions` ist die @Query oben (isCompleted == true). Wir
        // filtern Ruhetag-Marker und Snapshot-Ad-Hoc-Empties zusaetzlich raus
        // via `isRealWorkout`, sonst koennte ein "Tag im Plan abhaken"-Skip
        // den CNS-Status verfaelschen.
        let latest = completedSessions
            .filter { $0.isRealWorkout && $0.endTime >= cutoff }
            .sorted { $0.endTime > $1.endTime }
            .first
        return latest?.isCNSOverloaded ?? false
    }

    /// Sequential-rotation pick. Delegates to `PlanNavigator` (Core) so widgets
    /// + watch can reuse the exact same logic without dragging FitnessAppData in.
    private func nextScheduledDay(in plan: TrainingPlan) -> TrainingDay {
        let sortedDays = PlanNavigator.sortByWeekdayMondayFirst(plan.days)
        let completedCount = completedSessions.filter {
            $0.day?.plan?.persistentModelID == plan.persistentModelID
        }.count
        let idx = PlanNavigator.nextScheduledIndex(
            dayCount: sortedDays.count,
            completedSessions: completedCount
        ) ?? 0
        return sortedDays[idx]
    }

    /// Nachtrag 6. August (README 2.1): ersetzt die alte Fliesszeile mit
    /// Auslassungspunkten (`names.joined(separator: ", ")` + " …") durch
    /// echte Zeilen. Erste drei Uebungen sind immer sichtbar; bei mehr als
    /// drei kommt darunter eine Umschaltzeile dazu, die den Rest ein- und
    /// wieder ausblendet.
    @ViewBuilder
    private func exercisesList(for day: TrainingDay) -> some View {
        // DEL-049: archivierte Snapshots (Urlaubs-Modus) gehoeren nicht in
        // die Dashboard-Vorschau — sonst zeigt der Card "Bankdruecken" auch
        // wenn der User nur noch Liegestuetze trainiert.
        let sorted = day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
        let remaining = sorted.count - 3
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sorted.prefix(isExercisesExpanded ? sorted.count : 3), id: \.persistentModelID) { exercise in
                Text(exercise.displayName)   // DEL-111: lokalisierter Name fuer Library-Übungen
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            if remaining > 0 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExercisesExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExercisesExpanded
                             ? String(localized: "dashboard.exerciseList.showLess", bundle: .module)
                             : pluralizedShowMore(remaining: remaining))
                        Image(systemName: isExercisesExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Gleiches manuelles .one/.other-Muster wie `PlansListView.pluralizedCount`
    /// (siehe DEL-121/DEL-128) - Apple's format-as-key Plural-Convention
    /// chokt Xcode 26.4.1s GenerateStringSymbols-Step.
    private func pluralizedShowMore(remaining: Int) -> String {
        let suffix = remaining == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "dashboard.exerciseList.showMore.\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(remaining)")
    }

    /// DEL-042: Adaptive Start-Button. Drei States:
    ///   1. Keine offene Session       → "Direkt starten" (blau, neu)
    ///   2. Offene Session AUF DEM-Tag → "Fortsetzen" (orange, navigiert in
    ///      die existing Session — kein neuer Insert)
    ///   3. Offene Session AUF ANDEREM Tag → "Anderes Training läuft", Klick
    ///      triggert Conflict-Dialog mit drei Optionen.
    /// DEL-105: Alle Branches nutzen jetzt `.deltiqButtonStyle()` (Hero-CTA-
    /// Modifier aus DEL-102). Mode-Unterscheidung laeuft nur noch ueber Label
    /// + Icon, nicht ueber Farbe — das frueher blau-vs-orange Pattern stoerte
    /// das Markenbild.
    /// DEL-146: State 3 hatte bislang denselben Text wie State 1 ("Direkt
    /// starten"), obwohl ein Klick tatsaechlich den Conflict-Dialog oeffnet
    /// statt sofort zu starten — eigener Text macht das ehrlich sichtbar.
    @ViewBuilder
    private func activeWorkoutButton(plan: TrainingPlan, day: TrainingDay) -> some View {
        let matchingOpen = openSessionForDay(day)
        let hasOtherOpen = matchingOpen == nil && !openSessions.isEmpty

        Button {
            if let open = matchingOpen {
                resumeSession(open, plan: plan)
            } else if hasOtherOpen {
                pendingNewStart = {
                    actuallyStartNewWorkout(plan: plan, day: day)
                }
                showingActiveSessionConflict = true
            } else {
                actuallyStartNewWorkout(plan: plan, day: day)
            }
        } label: {
            // DEL-073/DEL-146: Alle drei Branches via xcstrings.
            Label {
                Text(matchingOpen != nil
                     ? "dashboard.action.resumeRunning"
                     : (hasOtherOpen ? "dashboard.action.otherRunning" : "dashboard.action.startDirect"),
                     bundle: .module)
            } icon: {
                Image(systemName: matchingOpen != nil ? "play.circle.fill" : (hasOtherOpen ? "exclamationmark.circle.fill" : "play.fill"))
            }
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
    }

    /// DEL-096: "Spontanes Workout"-Einstiegspunkt. Zwei Varianten:
    ///   * `prominent == true` — fetter DeltiqOrange-Hero-Button. Wird an
    ///     Ruhetagen + auf der Empty-Plan-Karte gerendert, wo es der einzige
    ///     Trainings-CTA ist.
    ///   * `prominent == false` — dezenter Text-Link unter dem regulaeren
    ///     "Direkt starten". Sekundaerer Pfad fuer User, die vom Plan
    ///     abweichen wollen, ohne dass ein zweiter Fett-CTA das visuelle
    ///     Gewicht des primaeren Plan-Buttons schluckt.
    @ViewBuilder
    private func adHocWorkoutButton(prominent: Bool) -> some View {
        Button {
            startAdHocWorkout()
        } label: {
            if prominent {
                HStack {
                    Spacer()
                    Label {
                        Text("dashboard.action.adHoc.primary", bundle: .module)
                    } icon: {
                        Image(systemName: "bolt.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.deltiqOrange.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("dashboard.action.adHoc.secondary", bundle: .module)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.deltiqOrange)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("dashboard.action.adHoc.a11y", bundle: .module))
    }

    /// Liefert eine offene Session, deren `.day` mit dem uebergebenen Day
    /// uebereinstimmt — fuer den "Fortsetzen"-Pfad.
    private func openSessionForDay(_ day: TrainingDay) -> WorkoutSession? {
        openSessions.first { $0.day?.persistentModelID == day.persistentModelID }
    }

    /// Navigiert in die existing offene Session, OHNE eine neue zu erstellen.
    private func resumeSession(_ session: WorkoutSession, plan: TrainingPlan) {
        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(plan)
        if let day = session.day {
            navigation.workoutPath.append(day)
        }
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// Verwirft alle ANDEREN offenen Sessions + startet eine neue. Wird vom
    /// ConfirmationDialog im Conflict-Path aufgerufen.
    private func discardOtherOpenSessionsAndStartNew() {
        for open in openSessions {
            modelContext.delete(open)
        }
        try? modelContext.save()
        pendingNewStart?()
        pendingNewStart = nil
    }

    /// Resume-Pfad fuer den Conflict-Dialog: springt in die existing Session
    /// (welche auch immer die juengste offene ist).
    private func resumeAnyOpenFromConflict() {
        guard let open = openSessions.first else { return }
        let plan = open.day?.plan ?? activePlans.first
        if let plan {
            resumeSession(open, plan: plan)
        }
        pendingNewStart = nil
    }

    // MARK: - DEL-215 Resume-Tile (spontane / planfremde offene Sessions)

    /// DEL-215: Offene Session, die im Dashboard sonst unsichtbar waere.
    /// Die PlanDayCard zeigt den Running-State nur, wenn die Session zu
    /// einem Tag des AKTIVEN Plans gehoert UND das nextWorkout-Widget
    /// eingeschaltet ist. Alles andere (Ad-hoc-Session, Session auf einem
    /// inaktiven Plan, Widget abgeschaltet) faellt durch — dafuer rendert
    /// das Dashboard die Resume-Tile direkt unter den Hero-Metrics.
    private var unrepresentedOpenSession: WorkoutSession? {
        guard let open = openSessions.first else { return nil }
        let planCardCoversIt = activeDashboardWidgets.contains(.nextWorkout)
            && activePlans.first.map { plan in
                open.day?.plan?.persistentModelID == plan.persistentModelID
            } ?? false
        return planCardCoversIt ? nil : open
    }

    /// DEL-215: "Aktuelles Training fortsetzen"-Tile. Orange-Gradient als
    /// hoechste visuelle Prioritaet, pulsierender Live-Punkt + mitlaufender
    /// Timer (TimelineView im Sekundentakt). Tap springt in die Session.
    private func resumeSessionTile(_ session: WorkoutSession) -> some View {
        Button {
            resumeOpenSession(session)
        } label: {
            HStack(spacing: 12) {
                PulsingLiveDot()
                VStack(alignment: .leading, spacing: 2) {
                    Text("dashboard.resume.caption", bundle: .module)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)
                    Text(session.displayDayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedTimeString(since: session.startTime, now: context.date))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.deltiqOrange.gradient,
                in: RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("dashboard.resume.caption", bundle: .module))
    }

    /// DEL-215: Resume fuer beliebige offene Sessions. Plan-gebundene
    /// Sessions bauen den vollen Stack (Plan → Day → Active), Ad-hoc-
    /// Sessions springen direkt in die ActiveWorkoutView — identisch zum
    /// Start-Pfad in `startAdHocWorkout()`.
    private func resumeOpenSession(_ session: WorkoutSession) {
        if let plan = session.day?.plan {
            resumeSession(session, plan: plan)
        } else {
            navigation.workoutPath = NavigationPath()
            navigation.workoutPath.append(ActiveSessionRoute(session: session))
            navigation.selectedTab = .plan
        }
    }

    /// DEL-215: Laufzeit seit Session-Start als H:MM:SS bzw. MM:SS.
    private func elapsedTimeString(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - DEL-239 Absenz-Deload-Rückfrage

    /// Faengt einen Trainingsstart ab, wenn nach einer langen Pause gefragt
    /// werden soll.
    ///
    /// - Returns: `true`, wenn abgefangen wurde — der Aufrufer bricht dann ab.
    ///   Die uebergebene Fortsetzung laeuft, sobald der Nutzer entschieden hat.
    ///
    /// Spiegelt das bestehende `pendingNewStart`-Muster des Konflikt-Dialogs
    /// (DEL-042), damit hier kein zweites Start-Unterbrechungs-Konzept entsteht.
    /// Reihenfolge bei Kollision: der Konflikt-Dialog laeuft VOR dieser Frage,
    /// weil er ueber `pendingNewStart` ohnehin erst in die Startfunktion
    /// zurueckkehrt — dann greift hier der Abfang.
    private func interceptForComeback(_ continuation: @escaping () -> Void) -> Bool {
        guard deloadEnabled else { return false }
        guard comebackAssessment == nil else { return false }
        guard let assessment = AbsenceDeload.assess(in: modelContext) else { return false }
        pendingComebackStart = continuation
        comebackAssessment = assessment
        return true
    }

    /// Der Nutzer hat entschieden. `factor == nil` = volle Last.
    private func resolveComeback(factor: Double?) {
        let assessment = comebackAssessment
        comebackAssessment = nil
        if let factor {
            // Fehler bewusst geschluckt: ein fehlgeschlagener Schreibvorgang
            // darf den Trainingsstart nicht blockieren. Der Nutzer sieht dann
            // seine unveraenderten Gewichte — das ist der sichere Ausgang.
            try? AbsenceDeload.apply(in: modelContext, factor: factor)
        } else if let assessment {
            // Ablehnung merken, damit nicht bei jedem Start erneut gefragt wird.
            AbsenceDeload.remember(declinedAtGapDays: assessment.gapDays)
        }
        // Erst jetzt starten — die Gewichte stehen bereits.
        let start = pendingComebackStart
        pendingComebackStart = nil
        start?()
    }

    /// Deep-link from Dashboard into ActiveWorkout: build a stack [plan, day, active]
    /// on the workout tab so the user can back out to DayEditor (after Discard) or
    /// PlanEditor without losing context.
    private func actuallyStartNewWorkout(plan: TrainingPlan, day: TrainingDay) {
        guard !day.activeExercises.isEmpty else { return }
        // DEL-239: Vor dem Anlegen der Session fragen. Danach ist es zu spaet —
        // `SetRow` sperrt sich per `didInit` gegen ein zweites Befuellen, eine
        // spaetere Gewichtsaenderung erreicht die Felder nicht mehr.
        // Bugfix (Comeback-Advisor bei Zeitformat-Sessions): reine
        // Zeitformat-Tage werden nie abgefangen — siehe `actuallyStartNewSession`
        // in DayEditorView fuer die Begruendung.
        if day.timeFormat == nil {
            guard !interceptForComeback({ actuallyStartNewWorkout(plan: plan, day: day) }) else { return }
        }

        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: day.activeExercises.count,
            isCompleted: false,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)

        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(plan)
        navigation.workoutPath.append(day)
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// DEL-096: Spontanes Ad-Hoc-Workout starten. Erzeugt einen ephemeren
    /// `TrainingDay` ohne Plan-Anbindung (damit der ActiveWorkoutView-
    /// Paginator + Add-Exercise-Flow weiterhin durch die normale
    /// `day.activeExercises`-Pipeline laufen koennen) und eine
    /// `WorkoutSession` mit `isAdHoc = true`. Empty-State-Logik und
    /// Discard-Sweep-Logik in der ActiveWorkoutView lesen diesen Flag.
    private func startAdHocWorkout() {
        // DEL-239: siehe `actuallyStartNewWorkout` — Rueckfrage vor dem Insert.
        guard !interceptForComeback({ startAdHocWorkout() }) else { return }
        // Ephemerer Tag — kein `plan`, taucht in keinem PlanEditor/PlansList
        // auf, weil alle Plan-Queries `plan != nil`-implizit filtern (via
        // `\TrainingPlan.days`-Inverse).
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        // DEL-150: localizationKey statt nur DE-`name`. Der Display-Pfad
        // (`WorkoutSession.displayDayName` → `TrainingDay.displayName`)
        // resolved den Key in die aktuelle Locale, sodass spontane Workouts
        // im Verlauf nicht als eingefrorenes "Spontanes Workout" haengen
        // bleiben. `name` bleibt als sprachneutraler DE-Anchor erhalten.
        let adHocDay = TrainingDay(
            name: "Spontanes Training",
            weekday: todayWeekday,
            type: .custom,
            plan: nil,
            localizationKey: "session.adHoc.dayName"
        )
        modelContext.insert(adHocDay)

        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: 0,
            isCompleted: false,
            isAdHoc: true,
            // DEL-150: kein DE-Snapshot mehr — die lebende Day-Reference
            // (mit localizationKey) ist die Source-of-Truth fuer den Titel.
            dayName: nil,
            day: adHocDay
        )
        modelContext.insert(session)

        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// Erzeugt eine "skipped"-WorkoutSession fuer einen Ruhetag. Die Session
    /// ist `isCompleted=true` (damit der PlanNavigator-Pointer auf den
    /// naechsten echten Tag advanced), `isRestDay=true` (damit History,
    /// Trophy-Room und Recent-Workouts-Card sie nicht anzeigen).
    private func markRestDaySkipped(plan: TrainingPlan, day: TrainingDay) {
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
    }

    // MARK: - Compound Lift Chart

    /// Die fuenf kanonischen Compound-Lifts fuer den Trend-Chart.
    ///
    /// DEL-230: Der frühere Kommentar behauptete, diese Liste entspreche
    /// `isSystemCompound: true` in `ExerciseLibraryData`. Das stimmt seit
    /// DEL-162 nicht mehr — dort sind inzwischen zehn Langhantel-Verbundlifts
    /// geflaggt (zusaetzlich Box Squat, Trap-Bar-/Deficit-Kreuzheben, Reissen,
    /// Umsetzen & Stossen). Die Auswahl hier ist bewusst eine kuratierte
    /// Fuenfer-Liste und NICHT vom Flag abgeleitet: zehn Serien in einem Chart
    /// waeren unlesbar, und die Big Five sind die Lifts, an denen der User
    /// seinen Fortschritt misst. Wer den Chart erweitern will, entscheidet das
    /// hier — nicht als Nebeneffekt einer Bibliotheks-Erweiterung.
    ///
    /// Hart kodiert, damit der Dashboard-Render nicht bei jedem Durchlauf die
    /// Seed-Bibliothek abfragt.
    private static let compoundLiftNames = [
        "Kniebeuge",
        "Bankdrücken",
        "Kreuzheben (konventionell)",
        "Schulterdrücken (stehend)",
        "Rudern vorgebeugt"
    ]

    /// Signature-Geruest 2.16: validierte, CVD-sichere Fuenfer-Kategorie-
    /// Palette (dataviz-Skill, adjacent-pairs-Check fuer Linien-Charts,
    /// beide Modi PASS) - feste Reihenfolge, nie zyklisch neu zugeordnet.
    /// Passend zu `compoundLiftNames` per Index gepaart in
    /// `compoundColorScale`, nicht hartcodiert auf einen bestimmten Lift,
    /// weil die Legenden-Beschriftung lokalisiert ist (siehe dort).
    private static let compoundLiftColors: [Color] = [
        Color(deltiqLight: Color(red: 0.165, green: 0.471, blue: 0.839),
              deltiqDark: Color(red: 0.224, green: 0.529, blue: 0.898)),
        Color(deltiqLight: Color(red: 0.922, green: 0.408, blue: 0.204),
              deltiqDark: Color(red: 0.851, green: 0.349, blue: 0.149)),
        Color(deltiqLight: Color(red: 0.106, green: 0.686, blue: 0.478),
              deltiqDark: Color(red: 0.098, green: 0.620, blue: 0.439)),
        Color(deltiqLight: Color(red: 0.929, green: 0.631, blue: 0.000),
              deltiqDark: Color(red: 0.788, green: 0.522, blue: 0.000)),
        Color(deltiqLight: Color(red: 0.910, green: 0.482, blue: 0.643),
              deltiqDark: Color(red: 0.835, green: 0.318, blue: 0.506))
    ]

    /// Bindet jeden Lift-NAMEN (lokalisiert, wie er auch als `.value("Lift",
    /// ...)`-Plot-Key verwendet wird) an eine feste Farbe aus
    /// `compoundLiftColors` - `chartForegroundStyleScale` braucht eine
    /// garantierte Zuordnung, sonst kann Swift Charts Farben zwischen
    /// Zeitraum-Filterwechseln neu vergeben (Serie B haette dann nicht mehr
    /// dieselbe Farbe wie vorher). Nimmt bewusst nur die Namen der gerade
    /// SICHTBAREN Serien (nicht immer alle fuenf moeglichen) als Scale-
    /// Domain - eine explizite Scale mit allen fuenf Namen wuerde die
    /// Legende auch dann komplett zeigen, wenn der Zeitraum-Filter nur
    /// zwei der fuenf Lifts mit Daten uebrig laesst. Die Farbe pro Lift
    /// bleibt trotzdem stabil, weil sie immer vom selben, festen Index in
    /// `compoundLiftNames` kommt - nur die Domain schrumpft mit der
    /// aktuellen Auswahl.
    ///
    /// CI-Fix: `chartForegroundStyleScale` hat KEINE Ueberladung, die ein
    /// `[String: Color]`-Dictionary annimmt - nur `KeyValuePairs<...>`
    /// (ausschliesslich per Literal an der Aufrufstelle konstruierbar,
    /// nicht aus einer Variable) oder `domain:`/`range:` als zwei parallele
    /// Arrays. Dieser Fehler war vorher durch den Type-Checker-Timeout im
    /// LineMark-Block DARUEBER maskiert - der Compiler kam nie bis zu
    /// dieser Zeile. Rueckgabetyp deshalb auf das Array-Paar umgestellt.
    private func compoundColorScale(for series: [CompoundSeries]) -> (domain: [String], range: [Color]) {
        let visibleNames = Set(series.map(\.exerciseName))
        let allNames = Self.compoundLiftNames.map { Exercise.resolvedDisplayName(forStoredName: $0) }
        let pairs = zip(allNames, Self.compoundLiftColors).filter { visibleNames.contains($0.0) }
        return (domain: pairs.map(\.0), range: pairs.map(\.1))
    }

    /// One series per compound lift. Each series carries one point per session
    /// (the best estimated 1RM of any set in that session). Lifts with fewer
    /// than 2 data points are dropped — a "trend" needs at least two sessions.
    private var compoundSeries: [CompoundSeries] {
        let liftNames = Set(Self.compoundLiftNames)

        return Self.compoundLiftNames.compactMap { name in
            // DEL-051: Snapshot-first — auch wenn die Plan-Uebung
            // inzwischen aus dem Plan geloescht/getauscht wurde, identifizieren
            // sich Logs ueber `resolvedExerciseName` selbst, sodass der
            // Compound-Trend kontinuierlich bleibt.
            let liftLogs = completedSessions.flatMap { session in
                session.logs.filter { log in
                    guard let logName = log.resolvedExerciseName else { return false }
                    return liftNames.contains(logName) && logName == name
                }
            }

            // Group by session, pick best 1RM per session
            let bySession = Dictionary(grouping: liftLogs) { log in
                log.session?.persistentModelID
            }

            let points: [CompoundPoint] = bySession.compactMap { (_, logs) -> CompoundPoint? in
                let estimates = logs.compactMap { log -> Double? in
                    ExerciseCalculations.estimate1RMAverage(weightKg: log.weight, reps: log.reps)
                }
                // DEL-147: session.startTime statt log.date als X-Achsen-
                // Wert. log.date ist der Speicher-Timestamp eines Sets —
                // ueberlebt User-Edits am Session-Datum NICHT (Editing-
                // Mode in WorkoutSummaryView updated nur session.startTime,
                // nicht die Child-Logs). Resultat war: User datiert ein
                // Workout zurueck, der Chart-Point bleibt auf dem
                // urspruenglichen Save-Datum hängen. Logs in einer
                // bySession-Gruppe teilen sich denselben Session-Backref,
                // also reicht `logs.first?.session?.startTime`. Orphan-
                // Logs (session-Backref nullified) fallen auf log.date
                // zurück — kein perfekter Wert, aber besser als nil.
                let representativeDate = logs.first?.session?.startTime
                                       ?? logs.map(\.date).min()
                guard let best = estimates.max(),
                      let pointDate = representativeDate else { return nil }
                return CompoundPoint(date: pointDate, oneRM: best)
            }
            .sorted { $0.date < $1.date }

            // Need ≥2 points for a meaningful line
            guard points.count >= 2 else { return nil }
            // DEL-149: Chart-Legend rendert ueber `line.exerciseName` —
            // wir wandeln den DE-Base hier einmalig in die aktuelle Locale,
            // damit die Legende mit dem User-Sprachsetting matched. Stable
            // innerhalb eines Frames, also Series-Grouping bleibt korrekt.
            return CompoundSeries(
                exerciseName: Exercise.resolvedDisplayName(forStoredName: name),
                points: points
            )
        }
    }

    /// DEL-152: Filtert Compound-Serien auf den gewaehlten Zeitbereich.
    /// `cutoff == nil` (`.max`) → unveraendert. Serien behalten ihre Linie
    /// solange >=1 Punkt im Bereich liegt — ein einzelner Punkt rendert als
    /// Dot, sodass kuerzlich begonnene Lifts im 1M-View nicht verschwinden.
    private func filteredCompound(_ series: [CompoundSeries], cutoff: Date?) -> [CompoundSeries] {
        guard let cutoff else { return series }
        return series.compactMap { line in
            let pts = line.points.filter { $0.date >= cutoff }
            guard !pts.isEmpty else { return nil }
            return CompoundSeries(exerciseName: line.exerciseName, points: pts)
        }
    }

    // MARK: - DEL-179 Compound-Forecast

    /// Wieviele Wochen voraus projizieren wir? 4 Wochen ist der Schoenfeld-
    /// "messbar progress"-Bereich — kürzer ist Noise, länger linear-
    /// extrapoliert utopisch. UI rendert genau diesen einen Endpunkt; die
    /// gestrichelte Linie verbindet ihn mit dem letzten echten Datenpunkt.
    private static let compoundForecastWeeksAhead = 4

    /// Pro Compound-Series eine Forecast-Mini-Series mit genau ZWEI
    /// Punkten: dem letzten echten + dem projizierten Endpunkt 4 Wochen
    /// in die Zukunft. Lifts, deren Trend als unreliable markiert ist,
    /// fliegen raus.
    private func compoundForecastPoints(for series: [CompoundSeries]) -> [CompoundSeries] {
        series.compactMap { line in
            let samples = line.points.map { OneRMSample(date: $0.date, oneRM: $0.oneRM) }
            // Brauchen einen letzten echten Punkt als Verbindungs-Anker.
            guard let lastReal = line.points.last else { return nil }
            // Forecast-Punkt 4 Wochen ab dem letzten REAL-Datum (nicht ab
            // jetzt) — sonst wird ein Lift, der seit 6 Wochen pausiert ist,
            // unter den Forecast-Daten wieder ausgegraben.
            guard let forecast = OneRMForecaster.forecastPoint(
                samples: samples,
                weeksAhead: Self.compoundForecastWeeksAhead,
                now: lastReal.date
            ) else { return nil }
            let connecting = CompoundPoint(date: lastReal.date, oneRM: lastReal.oneRM)
            let projected = CompoundPoint(date: forecast.date, oneRM: forecast.oneRM)
            return CompoundSeries(
                exerciseName: line.exerciseName,
                points: [connecting, projected]
            )
        }
    }

    /// Erweitert die Domain um die Forecast-Endpunkte, damit das Chart die
    /// gestrichelte Linie nicht clipped. Linke Kante bleibt unverändert,
    /// rechte Kante geht bis zum spätesten Forecast-Datum.
    private func compoundDomain(
        base: ClosedRange<Date>,
        forecastPoints: [CompoundSeries]
    ) -> ClosedRange<Date> {
        let allForecastDates = forecastPoints.flatMap(\.points).map(\.date)
        guard let latestForecast = allForecastDates.max(),
              latestForecast > base.upperBound else {
            return base
        }
        return base.lowerBound...latestForecast
    }

    @ViewBuilder
    private var compoundLiftChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.compoundChart.title", bundle: .module)
                    .font(.headline)
                Spacer()
                Text("dashboard.compoundChart.legend", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // DEL-152: Zeitfilter — auf alle (>=2-Punkt-)Serien angewandt, dann
            // auf den Bereich geklemmt. Empty-State greift, wenn nach dem
            // Filter keine Punkte mehr im Bereich liegen.
            // DEL-165: harte Domain mit `now` als rechtem Ende; fuer `.max`
            // liefert der aelteste Datenpunkt die linke Kante.
            // DEL-179: Forecast-Punkte (4w) erweitern den OLDEST-Lookup nicht,
            // aber das RECHTE Ende der Domain. Wir bauen die Domain manuell,
            // damit die gestrichelte Forecast-Linie sichtbar im Chart-Frame
            // landet, statt rechts überzulaufen.
            let allCompound = compoundSeries
            let oldestCompound = allCompound.flatMap(\.points).map(\.date).min()
            let series = filteredCompound(allCompound, cutoff: compoundChartRange.cutoff())
            let forecastSamples = compoundForecastPoints(for: series)
            let domain = compoundDomain(
                base: compoundChartRange.domain(oldestDataDate: oldestCompound),
                forecastPoints: forecastSamples
            )
            let colorScale = compoundColorScale(for: series)
            // Signature-Geruest 2.16: datengetriebene y-Achse statt Swift-
            // Charts-Automatik - die rundete bei Werten zwischen 60-110 kg
            // auf "schoene" Ticks wie 0/50/100/150 und liess die obere
            // Haelfte des Charts leer.
            let allOneRMValues = series.flatMap(\.points).map(\.oneRM)
                + forecastSamples.flatMap(\.points).map(\.oneRM)
            let yMin = allOneRMValues.min() ?? 0
            let yMax = allOneRMValues.max() ?? 100
            let yPadding = max((yMax - yMin) * 0.1, 5)
            let yDomain = max(0, yMin - yPadding)...(yMax + yPadding)
            if allCompound.isEmpty {
                // UX-201: Premium-Empty-State (icon + headline + description
                // + CTA). Vorher: kompakte HStack ohne Aktion.
                // UX-Refine 2026-05-21: kein CTA — Compound-Chart-Empty
                // braucht denselben "starte ein Workout"-Trigger wie History
                // + Trophy, die alle vom Recent-Workouts-CTA bedient werden.
                DashboardEmptyState(
                    icon: "chart.xyaxis.line",
                    title: "dashboard.compoundChart.empty.title",
                    description: "dashboard.compoundChart.empty.description"
                )
            } else {
                ChartTimeRangePicker(selection: $compoundChartRange)
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points) { point in
                            // Gleicher Fix wie beim Forecast-Segment unten:
                            // LineMark(x:y:series:) plus zwei weitere
                            // ueberladene `.value(...)`-Aufrufe in
                            // `.foregroundStyle(by:)`/`.symbol(by:)` zwingen
                            // den Type-Checker, alle Ueberladungen gemeinsam
                            // aufzuloesen - erst als eigene, typisierte
                            // `let`s vorab macht jede Aufloesung billig und
                            // unabhaengig.
                            let xValue: PlottableValue<Date> = .value("Datum", point.date)
                            let yValue: PlottableValue<Double> = .value("1RM (kg)", point.oneRM)
                            let seriesValue: PlottableValue<String> = .value("Lift", line.exerciseName)
                            let liftStyleValue: PlottableValue<String> = .value("Lift", line.exerciseName)
                            LineMark(x: xValue, y: yValue, series: seriesValue)
                                .interpolationMethod(.monotone)
                                .foregroundStyle(by: liftStyleValue)
                                .symbol(by: liftStyleValue)

                            PointMark(x: xValue, y: yValue)
                                .foregroundStyle(by: liftStyleValue)
                                .symbolSize(40)
                        }
                    }
                    // DEL-179: gestrichelte Forecast-Linie pro Lift —
                    // verbindet den letzten echten Punkt mit dem
                    // projizierten 4-Wochen-Wert. Nur für Lifts, deren
                    // Trend nicht als "unreliable" markiert ist.
                    // Signature-Geruest 2.16: eigener `series`-Schluessel
                    // ("-forecast"-Suffix) trennt das Prognose-Segment vom
                    // Ist-Verlauf - vorher teilten sich beide denselben
                    // "Lift"-Series-Key, wodurch Swift Charts beide Segmente
                    // als EINEN durchgehenden Pfad interpretieren konnte.
                    // `foregroundStyle(by:)` bleibt auf dem echten Lift-Namen,
                    // damit die Farbe trotzdem an den Ist-Verlauf gekoppelt ist.
                    ForEach(forecastSamples) { line in
                        let forecastSeriesKey = "\(line.exerciseName)-forecast"
                        // Auf DIESER Ebene deklariert (nicht in der inneren
                        // ForEach-Closure) - der Forecast-Endpunkt-PointMark
                        // gleich unten ist ein GESCHWISTER-Statement der
                        // inneren ForEach, braucht also seinen eigenen
                        // Zugriff auf denselben Wert.
                        let liftStyleValue: PlottableValue<String> = .value("Lift", line.exerciseName)
                        ForEach(line.points) { point in
                            // Fix Runde 2 (Release-Gate-Log): das Auslagern
                            // der Serien-Strings allein reichte nicht - der
                            // Type-Checker haengt weiterhin an den drei
                            // gemeinsam aufgeloesten `.value(...)`-Ueberladungen
                            // INNERHALB des LineMark-Aufrufs. Jeden Plot-Wert
                            // vorab einzeln binden trennt die Ueberladungs-
                            // Aufloesung in drei billige Einzelschritte statt
                            // einem gemeinsamen.
                            let xValue: PlottableValue<Date> = .value("Datum", point.date)
                            let yValue: PlottableValue<Double> = .value("1RM (kg)", point.oneRM)
                            let seriesValue: PlottableValue<String> = .value("Serie", forecastSeriesKey)
                            LineMark(x: xValue, y: yValue, series: seriesValue)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(by: liftStyleValue)
                                .opacity(0.6)
                        }
                        // Forecast-Endpunkt als hohler Ring — visuell als
                        // "Projektion" erkennbar, kein voller PointMark.
                        if let last = line.points.last {
                            let lastXValue: PlottableValue<Date> = .value("Datum", last.date)
                            let lastYValue: PlottableValue<Double> = .value("1RM (kg)", last.oneRM)
                            PointMark(x: lastXValue, y: lastYValue)
                                .symbol(.circle.strokeBorder(lineWidth: 1.5))
                                .symbolSize(50)
                                .foregroundStyle(by: liftStyleValue)
                                .opacity(0.8)
                        }
                    }
                    // Signature-Geruest 2.16: "Heute"-Markierung, damit
                    // gemessene und projizierte Punkte unterscheidbar bleiben.
                    if !forecastSamples.isEmpty {
                        RuleMark(x: .value("Heute", Date()))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .trailing) {
                                Text("dashboard.compoundChart.today", bundle: .module)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartForegroundStyleScale(domain: colorScale.domain, range: colorScale.range)
                .chartXScale(domain: domain)
                .chartXAxis {
                    // DEL-153: feste Kalender-Anker statt daten-getriebener
                    // Stride — Labels springen nicht mehr je nach Datenlage.
                    if let dates = compoundChartRange.axisDates() {
                        AxisMarks(values: dates) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    } else {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisTick()
                            // DEL-103: Achsen-Labels mit rounded/monospaced Design,
                            // damit die Datums-Ticks zum sportlichen Numerik-Look passen.
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYScale(domain: yDomain)
                .chartLegend(position: .bottom, alignment: .leading)
                // Signature-Geruest 2.16: 220 -> 260, damit bei bis zu fuenf
                // Serien (Farbe + Symbol je Eintrag) die Legende umbrechen
                // kann, ohne die Plot-Flaeche zusammenzudruecken.
                .frame(height: 260)
                .fitnessNumberStyle()
            }
        }
        // DEL-103: Bento-Card als outer Container.
        .deltiqCardStyle()
    }

    // MARK: - DEL-069 Wochen-Zusammenfassung

    /// "Diese Woche" Aggregat: Strength-Volumen + Cardio-Distanz.
    /// `Calendar.current` mit firstWeekday respektiert das User-Locale —
    /// in DE startet die Woche Mo, in US So. Wir filtern session.logs auf
    /// `date >= startOfCurrentWeek`.
    @ViewBuilder
    private var weeklySummaryCard: some View {
        let startOfWeek = currentWeekStart()
        let weekLogs = completedSessions
            .filter { ($0.startTime) >= startOfWeek }
            .flatMap(\.logs)
        let volumeKg = weekLogs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        let distanceKm = weekLogs.compactMap(\.distanceKm).reduce(0.0, +)

        if volumeKg > 0 || distanceKm > 0 {
            DeltiqCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "dashboard.weeklySummary.title", bundle: .module).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.deltiqOrange)
                    HStack(spacing: 12) {
                        if volumeKg > 0 {
                            // Signature-Geruest 1.7: Indigo war die semantische
                            // Differenzierung zum Cardio-Orange-Tile — das
                            // Geruest erlaubt aber nur Orange als Icon-Tint,
                            // beide Kacheln teilen sich die Farbe jetzt.
                            weeklyStatTile(
                                label: String(localized: "dashboard.weeklySummary.volume", bundle: .module),
                                value: formatVolumeKg(volumeKg),
                                unit: "kg",
                                icon: "scalemass.fill",
                                tint: Color.deltiqOrange
                            )
                        }
                        if distanceKm > 0 {
                            weeklyStatTile(
                                label: String(localized: "dashboard.weeklySummary.distance", bundle: .module),
                                value: formatDistance(distanceKm),
                                unit: "km",
                                icon: "figure.run",
                                tint: Color.deltiqOrange
                            )
                        }
                    }
                }
            }
        }
    }

    private func weeklyStatTile(
        label: String,
        value: String,
        unit: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(label.uppercased()).deltiqLabel()
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // DEL-103: fitnessNumberStyle vereinheitlicht den Stil ueber alle
                // Stats-Surfaces (Hero-Metrics, Weekly-Tiles, Heatmap-Zahlen).
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .fitnessNumberStyle()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // Tiles sitzen IN einer Bento-Card (Surface-Background), also
        // brauchen sie selbst nur einen ganz leichten Tint, um sich
        // abzuheben — Signature-Geruest-Fuellfarbe statt Ad-hoc-Opacity.
        .background(Color.Deltiq.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// User-Locale-respektierende "Anfang der aktuellen Kalenderwoche".
    private func currentWeekStart() -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    private func formatVolumeKg(_ kg: Double) -> String {
        // Signature-Geruest 2.16: Volumen ist eine diskrete Groesse - "0,00 KG"
        // taeuschte eine Praezision vor, die hier niemand braucht.
        kg.truncated(to: 0).formattedNoDecimals
    }

    private func formatDistance(_ km: Double) -> String {
        if km == km.rounded() { return "\(Int(km))" }
        return km.truncated(to: 2).formattedTwoDecimals
    }

    // MARK: - DEL-082 Muscle-Heatmap

    /// Vier-Spalten-Grid mit einem Tile pro Muskelgruppe. Farbe nach Wochen-
    /// Volumen-Bucket; Tile zeigt Set-Anzahl + Status-Label.
    ///
    /// PRAGMATISCH-CUT statt Silhouette: Eine echte 2D-Koerper-Map waere
    /// tagelanges Custom-Artwork. Grid-Tiles liefern 80% des Werts (User
    /// sieht sofort welche Gruppe untertrainiert ist) ohne Asset-Pipeline.
    @ViewBuilder
    // MARK: - DEL-178 Volume-Over-Time Chart

    /// Wochen-Strength-Volume als BarMark-Trend. Visualisiert
    /// Volumen-Schwankungen über mehrere Wochen — wird im Hypertrophie-
    /// Coaching gerne als "Bin ich progressively überloading?"-Indikator
    /// genutzt. Cardio-Logs werden ausgeklammert (kein Volume-Begriff).
    private var volumeOverTimeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.volumeChart.title", bundle: .module)
                    .font(.headline)
                Spacer()
                Text("dashboard.volumeChart.legend", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Window-Berechnung analog zum Compound-Chart: harte Domain
            // mit `now` rechts, Range-bedingte linke Kante.
            let points = volumeByWeek
            let hasData = points.contains { $0.volumeKg > 0 }
            if !hasData {
                DashboardEmptyState(
                    icon: "chart.bar.fill",
                    title: "dashboard.volumeChart.empty.title",
                    description: "dashboard.volumeChart.empty.description"
                )
            } else {
                ChartTimeRangePicker(selection: $volumeChartRange)
                let rawDomain = volumeChartRange.domain(
                    oldestDataDate: points.first?.weekStart
                )
                // Signature-Geruest 2.16: 3 Tage Nachlauf-Puffer rechts -
                // die harte Obergrenze `now` liess Swift Charts das letzte
                // Achsen-Label (Tag + Monat) genau am rechten Plot-Rand
                // zentrieren, wo es ohne reservierten Rand abgeschnitten
                // wurde (nur die fuehrende Tagesziffer blieb sichtbar).
                let domain = rawDomain.lowerBound...rawDomain.upperBound.addingTimeInterval(3 * 86_400)
                let maxVolumeKg = points.map(\.volumeKg).max() ?? 0
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            // Wochen-Anker: wir taggen den BarMark auf den
                            // Mittwoch der Woche, damit die Bar visuell
                            // in der Woche zentriert wirkt (BarMark wird
                            // mit point-width gerendert; Mo wäre links-
                            // bündig + sehe wackelig aus, wenn der erste
                            // sichtbare Bucket teilweise außerhalb der
                            // Domain liegt).
                            x: .value("Woche", point.weekStart.addingTimeInterval(2.5 * 86_400)),
                            y: .value("Volumen (kg)", point.volumeKg)
                        )
                        .foregroundStyle(point.volumeKg > 0
                                         ? Color.deltiqOrange.gradient
                                         : Color.secondary.opacity(0.12).gradient)
                        .cornerRadius(4)
                    }
                }
                .chartXScale(domain: domain)
                .chartXAxis {
                    if let dates = volumeChartRange.axisDates() {
                        AxisMarks(values: dates) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    } else {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                // Signature-Geruest 2.16: Balken starten bei 0 (kein
                // Bar-Chart mit verschobener Grundlinie), oben 15% Puffer
                // statt Swift-Charts-Automatik.
                .chartYScale(domain: 0...(maxVolumeKg * 1.15))
                .frame(height: 220)
                .fitnessNumberStyle()
            }
        }
        .deltiqCardStyle()
    }

    /// Wochen-Buckets von Strength-Volume innerhalb des aktuell gewählten
    /// Range-Fensters. Pure-function-Aggregation in Core, View liefert nur
    /// das Tuple-Array.
    private var volumeByWeek: [VolumeWeekPoint] {
        let calendar = Calendar.current
        let now = Date()
        // Linke Fenster-Kante. Bei .max: 26 Wochen zurück als pragmatischer
        // Default — sonst tönen wir hunderte Bars in den Chart, was am
        // iPhone-Screen unleserlich wird. User kann via Range zwischen 1M /
        // 3M / Max wählen; Max ist hier "ein halbes Jahr".
        let windowStart: Date = {
            if let cutoff = volumeChartRange.cutoff(now: now, calendar: calendar) {
                return cutoff
            }
            return calendar.date(byAdding: .weekOfYear, value: -26, to: now) ?? now
        }()
        let logs = completedSessions
            .filter(\.isRealWorkout)
            .flatMap(\.logs)
            .map { log -> (date: Date, weightKg: Double, reps: Int, isCardio: Bool, isTimeBased: Bool) in
                let when = log.session?.startTime ?? log.date
                return (when, log.weight, log.reps, log.resolvedIsCardio, log.resolvedIsTimeBased)
            }
        return VolumeOverTimeAggregator.aggregate(
            logs: logs,
            windowStart: windowStart,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - DEL-197 Trainings-Kalender

    /// Monats-Kalender mit Workout-Dots + Wochen-Streak. Aggregation lebt
    /// testbar in Core (`TrainingCalendarAggregator`), die Card selbst ist
    /// eine eigene Komponente (Components/TrainingCalendarCard.swift) —
    /// bewusst KEINE weitere Inline-View in dieser ohnehin großen Datei.
    private var trainingCalendarCard: some View {
        let realDates = completedSessions
            .filter(\.isRealWorkout)
            .map(\.startTime)
        return TrainingCalendarCard(
            workoutDays: TrainingCalendarAggregator.workoutDays(of: realDates),
            // DEL-203: Streak respektiert das Wochenziel aus dem Profil
            // (Default 1 = altes Verhalten).
            streak: TrainingCalendarAggregator.weekStreak(
                workoutDates: realDates,
                goalPerWeek: profiles.first?.weeklyWorkoutGoal ?? 1
            ),
            // DEL-202: Tap auf einen Workout-Dot → Tages-Detail-Sheet.
            onDaySelected: { day in
                selectedCalendarDay = CalendarDaySelection(day: day)
            }
        )
        .sheet(item: $selectedCalendarDay) { selection in
            calendarDaySheet(for: selection.day)
        }
    }

    /// DEL-202: Sessions eines getappten Kalendertags. Eigene
    /// NavigationStack im Sheet, Rows verlinken in die Read-Only-Summary —
    /// gleiche Ziel-View wie die Recent-Workouts-Liste.
    ///
    /// Gruppe B (Sheet): `.sheet(item:)`-praesentiert mit nativem
    /// "Schliessen"-Toolbar-Button, kein Push, daher bewusst KEIN
    /// DeltiqHeader - die List traegt die Deltiq-Karten-Flaeche.
    private func calendarDaySheet(for day: Date) -> some View {
        let sessions = completedSessions.filter {
            $0.isRealWorkout && Calendar.current.isDate($0.startTime, inSameDayAs: day)
        }
        return NavigationStack {
            List {
                ForEach(sessions, id: \.persistentModelID) { session in
                    NavigationLink {
                        WorkoutSummaryView(session: session, isReadOnly: true)
                    } label: {
                        DashboardSessionRow(session: session)
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        selectedCalendarDay = nil
                    } label: {
                        Text("common.close", bundle: .module)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // @ViewBuilder explizit nötig, weil der Body let-Bindings + ein
    // `if`-Statement ohne else hat. Xcode 26.4 ist hier strenger als
    // frühere Versionen — ohne den Marker erkennt der Compiler den
    // implicit-return-Pfad nicht und meldet "no return statements".
    @ViewBuilder
    private var muscleHeatmapCard: some View {
        let aggregate = weeklyMuscleVolume
        let anyTraining = aggregate.contains { $0.setsCount > 0 }
        if anyTraining {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("dashboard.heatmap.title", bundle: .module)
                        .font(.headline)
                    Spacer()
                    Text("dashboard.heatmap.legend", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // DEL-103: Grid sitzt direkt auf der Bento-Surface — kein
                // zusaetzlicher Container-Background, sonst wirkt es nested.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 84), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(aggregate) { entry in
                        MuscleHeatmapTile(entry: entry)
                    }
                }
            }
            // DEL-103: Bento-Card als outer Container.
            .deltiqCardStyle()
        }
    }

    /// Wochen-Aggregat ueber alle abgeschlossenen Logs der aktuellen
    /// Kalenderwoche. Muscle-Mapping via Exercise-Name-Lookup gegen die
    /// `ExerciseLibraryData.all`-Liste.
    private var weeklyMuscleVolume: [MuscleWeeklyVolume] {
        let weekStart = Self.currentWeekStart()
        let weekLogs = completedSessions
            .filter { $0.startTime >= weekStart }
            // DEL-223: `loggedSets` statt `logs` — nie ausgefuellte
            // Platzhalter-Zeilen (0/0 aus dem History-Nachtrag) zaehlten hier
            // als vollwertiger Satz und liessen die Woche trainierter
            // aussehen, als sie war.
            .flatMap(\.loggedSets)
            .compactMap { log -> (date: Date, exerciseName: String, isCardio: Bool)? in
                guard let name = log.resolvedExerciseName else { return nil }
                return (date: log.date, exerciseName: name, isCardio: log.resolvedIsCardio)
            }
        return MuscleVolumeAggregator.aggregate(
            logs: weekLogs,
            weekStart: weekStart,
            nameToMuscle: Self.muscleForName
        )
    }

    /// Statischer Lookup vom Library-Namen auf MuscleGroup. Custom-Uebungen
    /// und Unbekannte returnen nil → zaehlen nicht ins Volume mit.
    private static func muscleForName(_ name: String) -> MuscleGroup? {
        ExerciseLibraryData.all.first { $0.name == name }?.primaryMuscle
    }

    private static func currentWeekStart() -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    // MARK: - DEL-065 Cardio-Trend-Chart

    /// DEL-065: Pace-Trend ueber Zeit fuer Hybrid-Athleten. Eine Linie pro
    /// Cardio-Uebung (Easy Run / Long Run / Intervalle). Y-Achse als
    /// "min/km" — niedriger = besser. Wir invertieren die Achse NICHT
    /// (waere visuell verwirrend), sondern lassen die Linie nach unten gehen
    /// und beschriften die Achse explizit "min/km · niedriger = besser".
    private var cardioSeries: [CardioPaceSeries] {
        // Alle Cardio-Logs aus completed Sessions, gruppiert per Uebung.
        let allCardioLogs = completedSessions.flatMap { session in
            session.logs.filter { $0.exerciseIsCardioSnapshot || ($0.exercise?.isCardio == true) }
        }
        // DEL-156: Gruppierung nach (Name, Equipment) — eine Linie pro
        // Modalitaet. Laufband-Laeufe und Fahrradfahrten derselben Uebung
        // bilden getrennte Trend-Linien.
        let byName = Dictionary(grouping: allCardioLogs) { log in
            CardioGroupKey(name: log.resolvedExerciseName ?? "—",
                           equipment: log.resolvedCardioEquipment)
        }
        return byName.compactMap { (key, logs) -> CardioPaceSeries? in
            let name = key.name
            // Pro Session aggregieren (Datum = Session-Start, Pace = total/total).
            let bySession = Dictionary(grouping: logs) { log in
                log.session?.persistentModelID
            }
            let points: [CardioPacePoint] = bySession.compactMap { (_, sessionLogs) -> CardioPacePoint? in
                let totalKm = sessionLogs.compactMap(\.distanceKm).reduce(0.0, +)
                let totalSec = sessionLogs.compactMap(\.durationSeconds).reduce(0, +)
                // DEL-147: session.startTime statt log.date — selber
                // Bugfix-Pattern wie im Compound-Chart oben (siehe
                // ausführlicher Kommentar dort).
                let representativeDate = sessionLogs.first?.session?.startTime
                                       ?? sessionLogs.map(\.date).min()
                guard totalKm > 0, totalSec > 0,
                      let pace = PaceCalculator.minutesPerKm(distanceKm: totalKm, durationSeconds: totalSec),
                      let date = representativeDate
                else { return nil }
                return CardioPacePoint(date: date, paceMinPerKm: pace, distanceKm: totalKm)
            }
            .sorted { $0.date < $1.date }
            guard points.count >= 2 else { return nil }
            // DEL-149: dieselbe Lokalisierung wie im Compound-Chart oben —
            // Legende soll in der aktuellen Sprache erscheinen, nicht
            // hardcoded auf den DE-Base-Namen.
            // DEL-156: Equipment-Suffix in der Legende, damit getrennte
            // Modalitaets-Linien unterscheidbar sind ("Laufen · Laufband").
            let baseName = Exercise.resolvedDisplayName(forStoredName: name)
            let label = key.equipment == .none
                ? baseName
                : "\(baseName) · \(String(localized: key.equipment.localizedName))"
            return CardioPaceSeries(
                exerciseName: label,
                points: points
            )
        }
        .sorted { $0.exerciseName < $1.exerciseName }
    }

    /// DEL-080: True wenn das Cardio-Chart ueberhaupt angezeigt werden darf.
    /// Reine Bodybuilder sollen kein leeres Cardio-Surface sehen; Hybrid-
    /// und Lauf-Athleten kriegen es bedingungslos.
    ///
    /// Sichtbar wenn EINS der zwei zutrifft:
    ///   1. User hat in den letzten 30 Tagen mind. ein Workout mit
    ///      `log.resolvedIsCardio && distanceKm > 0` absolviert.
    ///   2. Aktiver Trainingsplan enthaelt mind. eine Uebung mit
    ///      `isCardio == true`.
    private var shouldShowCardioChart: Bool {
        // Branch 1: letzte 30 Tage Cardio-Aktivitaet?
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let hasRecentCardio = completedSessions.contains { session in
            session.startTime >= thirtyDaysAgo
                && session.logs.contains { $0.resolvedIsCardio && ($0.distanceKm ?? 0) > 0 }
        }
        if hasRecentCardio { return true }
        // Branch 2: aktiver Plan mit Cardio-Uebung?
        return activePlans.first?.days.contains { day in
            day.activeExercises.contains { $0.isCardio }
        } ?? false
    }

    /// DEL-152: Filtert Cardio-Serien auf den gewaehlten Zeitbereich.
    /// Analog zu `filteredCompound` — Serien mit >=1 Punkt im Bereich bleiben.
    /// (Erratum: vorher fälschlich @ViewBuilder annotiert — Funktion liefert
    /// `[CardioPaceSeries]`, kein View, daher entfernt. Xcode 26.4 würgt
    /// daran mit "ViewBuilder disabled by explicit return"-Warning.)
    private func filteredCardio(_ series: [CardioPaceSeries], cutoff: Date?) -> [CardioPaceSeries] {
        guard let cutoff else { return series }
        return series.compactMap { line in
            let pts = line.points.filter { $0.date >= cutoff }
            guard !pts.isEmpty else { return nil }
            return CardioPaceSeries(exerciseName: line.exerciseName, points: pts)
        }
    }

    @ViewBuilder
    private var cardioPaceChart: some View {
        // DEL-165: harte Domain mit `now` als rechtem Ende; `.max` nutzt den
        // aeltesten Cardio-Datenpunkt als linke Kante.
        let allCardio = cardioSeries
        let oldestCardio = allCardio.flatMap(\.points).map(\.date).min()
        let domain = cardioChartRange.domain(oldestDataDate: oldestCardio)
        let series = filteredCardio(allCardio, cutoff: cardioChartRange.cutoff())
        // Sichtbarkeit haengt an der Gesamt-Datenlage (shouldShowCardioChart +
        // ungefilterte Serien), nicht am gewaehlten Zeitfilter — sonst wuerde
        // ein leerer 1M-Bereich den ganzen Chart verschwinden lassen statt
        // eine leere Achse zu zeigen.
        if shouldShowCardioChart, !allCardio.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("dashboard.cardioChart.title", bundle: .module)
                        .font(.headline)
                    Spacer()
                    Text("dashboard.cardioChart.legend", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ChartTimeRangePicker(selection: $cardioChartRange)
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points) { point in
                            // Gleicher Type-Checker-Fix wie beim Compound-
                            // Lift-Chart oben: LineMark(x:y:series:) plus
                            // zwei weitere ueberladene `.value(...)`-Aufrufe
                            // in `.foregroundStyle(by:)`/`.symbol(by:)`
                            // erst als eigene, typisierte `let`s vorab
                            // aufloesen statt gemeinsam inline.
                            let xValue: PlottableValue<Date> = .value("Datum", point.date)
                            let yValue: PlottableValue<Double> = .value("Pace (min/km)", point.paceMinPerKm)
                            let seriesValue: PlottableValue<String> = .value("Lauf", line.exerciseName)
                            let runStyleValue: PlottableValue<String> = .value("Lauf", line.exerciseName)
                            LineMark(x: xValue, y: yValue, series: seriesValue)
                                .interpolationMethod(.monotone)
                                .foregroundStyle(by: runStyleValue)
                                .symbol(by: runStyleValue)

                            PointMark(x: xValue, y: yValue)
                                .foregroundStyle(by: runStyleValue)
                                .symbolSize(40)
                        }
                    }
                }
                .chartXScale(domain: domain)
                .chartXAxis {
                    // DEL-153: feste Kalender-Anker (siehe Compound-Chart).
                    if let dates = cardioChartRange.axisDates() {
                        AxisMarks(values: dates) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    } else {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pace = value.as(Double.self) {
                                let total = Int((pace * 60.0).rounded())
                                Text(String(format: "%d:%02d", total / 60, total % 60))
                            }
                        }
                    }
                }
                .frame(height: 180)
                // DEL-103: Achsen-Tick-Labels (sowohl Datum als auch Pace)
                // bekommen den rounded/monospaced Numerik-Stil.
                .fitnessNumberStyle()
            }
            // DEL-103: Bento-Card.
            .deltiqCardStyle()
        }
        // Kein Empty-State — der Chart ist optional fuer reine Strength-User
        // und blendet sich einfach aus, wenn keine Cardio-Daten existieren.
    }

    // MARK: - Recent workouts

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.recent.title", bundle: .module)
                    .font(.headline)
                Spacer()
                if completedSessions.contains(where: { !$0.isRestDay }) {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Text("dashboard.recent.viewAll", bundle: .module)
                            .font(.subheadline)
                    }
                }
            }

            // Rest-day-marker sessions don't count as "Trainingseinheiten".
            let realRecentSessions = completedSessions.filter { !$0.isRestDay }
            if realRecentSessions.isEmpty {
                // UX-201: Premium-Empty-State mit CTA (vorher: kompaktes
                // Icon+2-Liner ohne Aktion).
                DashboardEmptyState(
                    icon: "dumbbell.fill",
                    title: "dashboard.recent.empty.title",
                    description: "dashboard.recent.empty.description",
                    ctaTitle: "dashboard.empty.cta.startWorkout",
                    ctaAction: { navigation.selectedTab = .plan }
                )
            } else {
                let recent = Array(realRecentSessions.prefix(5))
                // DEL-103: Rows sitzen direkt auf der Bento-Surface — keine
                // doppelte Container-Schachtelung mehr. Divider trennen die
                // Eintraege visuell.
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { idx, session in
                        NavigationLink {
                            WorkoutSummaryView(session: session, isReadOnly: true)
                        } label: {
                            DashboardSessionRow(session: session)
                        }
                        .buttonStyle(.plain)

                        if idx < recent.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        // DEL-103: Bento-Card als outer Container.
        .deltiqCardStyle()
    }
}

// MARK: - Compound Lift Chart data

@available(iOS 17.0, macOS 14.0, *)
struct CompoundPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let oneRM: Double
}

@available(iOS 17.0, macOS 14.0, *)
struct CompoundSeries: Identifiable {
    let id = UUID()
    let exerciseName: String
    let points: [CompoundPoint]
}

// MARK: - DEL-082 Muscle-Heatmap Tile

@available(iOS 17.0, macOS 14.0, *)
private struct MuscleHeatmapTile: View {
    let entry: MuscleWeeklyVolume

    var body: some View {
        // DEL-180: Lokalisierte Strings für Render UND Accessibility.
        // Muscle-Name via existierende DomainEnums+Localization-Extension,
        // Bucket-Label via lokaler Catalog-Lookup. Voher hartcodiert deutsch
        // (Brust/Rücken/etc.) — übersetzte App rendert jetzt sauber TR/EN.
        let muscleName = String(localized: entry.group.localizedName)
        let bucketLabel = bucketLocalizedLabel(entry.bucket)
        VStack(alignment: .leading, spacing: 4) {
            Text(muscleName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // DEL-103: fitnessNumberStyle vereinheitlicht den Numerik-Look
                // ueber Hero-Stats, Weekly-Tiles und Heatmap.
                Text("\(entry.setsCount)")
                    .font(.system(size: 22, weight: .bold))
                    .fitnessNumberStyle()
                    .foregroundStyle(textColor)
                Text(bucketLabel.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(textColor.opacity(0.85))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: String(localized: "dashboard.heatmap.a11y.tile", bundle: .module),
            muscleName, entry.setsCount, bucketLabel
        ))
    }

    /// DEL-180: Lokalisierte Bucket-Labels. Spiegelt das raw enum aus Core
    /// (`MuscleVolumeBucket.label` ist hartcodiert deutsch und bleibt es —
    /// View-Layer ist der richtige Ort für i18n, Core bleibt sprachfest).
    private func bucketLocalizedLabel(_ bucket: MuscleVolumeBucket) -> String {
        switch bucket {
        case .untrained:    return String(localized: "muscleVolume.bucket.untrained", bundle: .module)
        case .maintenance:  return String(localized: "muscleVolume.bucket.maintenance", bundle: .module)
        case .optimal:      return String(localized: "muscleVolume.bucket.optimal", bundle: .module)
        case .overreaching: return String(localized: "muscleVolume.bucket.overreaching", bundle: .module)
        }
    }

    private var tileBackground: Color {
        switch entry.bucket {
        case .untrained:     return Color.secondary.opacity(0.12)
        case .maintenance:   return Color.deltiqOrange.opacity(0.22)
        case .optimal:       return Color.deltiqOrange.opacity(0.55)
        case .overreaching:  return Color.red.opacity(0.55)
        }
    }

    private var textColor: Color {
        switch entry.bucket {
        case .untrained:     return .secondary
        case .maintenance, .optimal, .overreaching:
            return .primary
        }
    }

}

// MARK: - DEL-065 Cardio-Pace Chart data

@available(iOS 17.0, macOS 14.0, *)
struct CardioPacePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    /// Pace in min/km (lower = better).
    let paceMinPerKm: Double
    /// Aggregierte Distanz dieser Session in km — fuer Tooltip-Reservierung.
    let distanceKm: Double
}

@available(iOS 17.0, macOS 14.0, *)
struct CardioPaceSeries: Identifiable {
    let id = UUID()
    let exerciseName: String
    let points: [CardioPacePoint]
}

/// DEL-156: Composite-Gruppierungs-Schluessel fuer den Cardio-Pace-Chart —
/// eine Trend-Linie pro (Uebung, Equipment).
@available(iOS 17.0, macOS 14.0, *)
private struct CardioGroupKey: Hashable {
    let name: String
    let equipment: CardioEquipment
}

// MARK: - Recent-row subview

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-129: lokalisierter Display-Name via Extension. Vorher
                // wurde der DE-Snapshot `session.dayName` direkt gerendert,
                // sodass ein türkisches iPhone "Ganzkörper A" statt "Tüm
                // Vücut A" sah.
                Text(session.displayDayName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                    // Signature-Geruest 2.16: 0 Min ist typischerweise eine
                    // Unter-Minuten-Session (Ganzzahl-Trunkierung bei der
                    // Dauer-Berechnung) oder ein CSV-Import ohne Dauer-
                    // Spalte - beides zeigt man besser gar nicht als eine
                    // irrefuehrende Null.
                    if session.durationMinutes > 0 {
                        Text("•")
                        Text(minutesText)
                    }
                    Text("•")
                    Text(setsText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var minutesText: String {
        String(
            format: String(localized: "dashboard.recent.minutesShort", bundle: .module),
            session.durationMinutes
        )
    }

    /// Signature-Geruest 2.16: "Sätze" war hartes Deutsch ohne Katalog-
    /// Schluessel - gleiches .one/.other-Muster wie `PlanRow.pluralized`
    /// bzw. `DashboardView.pluralizedShowMore` (DEL-121/DEL-128).
    private var setsText: String {
        let count = session.totalSets
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "dashboard.recent.sets.\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct MetricCard: View {
    let label: String
    let value: String
    let unit: String?
    let delta: Double?

    var body: some View {
        // Signature-Geruest 1.6/1.8: Hero-Kachel-Label wird zum Eyebrow-Stil
        // (vorher 12pt Regular Weiss 60%), Radius 14 -> 20 (1.4: 10/14/16
        // verschwinden aus Container-Hintergruenden), kompaktes Padding 12
        // bleibt (die drei Kacheln sitzen nebeneinander in einer Reihe).
        DeltiqCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // UX-Fix 2026-05-21: Label-Layout-Hardening.
                //   * .lineLimit(2): max 2 Zeilen (wie "Body Fat (Navy)") —
                //     verhindert dass extreme Sprachen unbegrenzt wachsen.
                //   * .minimumScaleFactor(0.85): wenn ein 1-Zeilen-Label knapp
                //     ist, lieber leicht runterskalieren statt umbrechen.
                //   * .fixedSize(vertical: true): zwingt SwiftUI die intrinsische
                //     Hoehe zu reporten (sonst kollabiert das Label bei Equal-
                //     Height-Layouts unsichtbar zusammen).
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.deltiqOrange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    // Signature-Geruest 1.8: Kachel-Wert-Rolle (22pt/Weight800)
                    // statt der bisherigen .title2.semibold.
                    Text(value)
                        .font(.system(size: 22, weight: .heavy))
                        .fitnessNumberStyle()
                    if let unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
                if let delta {
                    deltaLabel(delta)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
                // UX-Fix 2026-05-21: Spacer drueckt den Card-Inhalt nach oben,
                // wenn der HStack-Container der MetricCard mehr Hoehe gibt als
                // ihr intrinsischer Inhalt braucht. So bleiben Label oben +
                // Wert oben, statt vertikal zentriert zu rendern.
                Spacer(minLength: 0)
            }
            // UX-Fix 2026-05-21: maxHeight: .infinity expandiert jede Card auf
            // die Hoehe der hoechsten Geschwister-Karte im HStack (siehe
            // `heroMetrics` Container-Modifier). topLeading alignment haelt
            // den Inhalt oben-links statt zentriert.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func deltaLabel(_ delta: Double) -> some View {
        let prefix = delta > 0 ? "+" : (delta < 0 ? "" : "±")
        // Signature-Geruest 2.16: eine Nachkommastelle wie beim Gewicht selbst
        // ("+1,00 kg" -> "+1,0 kg") - gleiche Begruendung wie beim Hero-Wert.
        let formatted = abs(delta).truncated(to: 1).formattedOneDecimal
        let arrow = delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus")
        return HStack(spacing: 2) {
            Image(systemName: arrow)
            Text("\(prefix)\(formatted) kg")
            Text("metric.weeklyDelta.suffix", bundle: .module)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .monospacedDigit()
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EmptyMetricsCard: View {
    var body: some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("dashboard.trend.emptyTitle", bundle: .module)
                } icon: {
                    Image(systemName: "scalemass")
                }
                .font(.headline)
                Text("dashboard.trend.emptyDescription", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// UX-201: `EmptyTrendCard` ist durch `DashboardEmptyState` (Trend-Variante
// mit "Messung hinzufügen"-CTA) abgeloest worden. Der alte 2-teilige
// Label-Renderer ist entfernt — der xcstrings-Key `dashboard.trend.empty`
// bleibt im Catalog (für eventuelle Re-Use, kein Symbol-Conflict mit
// `dashboard.trend.emptyTitle`/`emptyDescription`).

@available(iOS 17.0, macOS 14.0, *)
private struct InsufficientDataCard: View {
    let currentCount: Int

    var body: some View {
        // DEL-073: Insufficient-Data-String laesst den Count direkt im
        // String-Format. xcstrings-Key mit %lld erlaubt EN/TR-Uebersetzer
        // den Zahlen-Slot zu positionieren.
        Label {
            Text(
                String(localized: "dashboard.trend.insufficient", bundle: .module)
                    .replacingOccurrences(of: "%lld", with: "\(currentCount)")
            )
        } icon: {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

/// DEL-215: Pulsierender Live-Indikator fuer die Resume-Tile. Eigener
/// View, damit der repeatForever-Animations-State nicht den Dashboard-
/// Body invalidiert. Reduce-Motion-User bekommen einen statischen Punkt.
@available(iOS 17.0, macOS 14.0, *)
private struct PulsingLiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 10, height: 10)
            .opacity(pulsing ? 0.35 : 1.0)
            .scaleEffect(pulsing ? 0.8 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard mit 6 Wochen Daten") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard ohne Daten (Empty State)") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard mit nur 1 Wert") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.singleMeasurementContainer)
}
#endif
#endif
