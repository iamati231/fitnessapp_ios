#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import FitnessAppCore
import FitnessAppData

/// Home screen — landing surface answering three questions on app open:
///   1. Where am I (latest weight + body-fat + FFMI)?
///   2. What's next (today's training day from the active plan)?
///   3. What did I do recently (last completed workouts + weight trend)?
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

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

    /// DEL-042: ConfirmationDialog-State fuer den Konflikt-Pfad.
    /// pendingNewStart-Closure wird aufgerufen wenn der User "Altes verwerfen"
    /// waehlt — sie liefert die Aktion fuer einen frischen Insert.
    @State private var showingActiveSessionConflict = false
    @State private var pendingNewStart: (() -> Void)?

    public init() {}

    public var body: some View {
        ScrollView {
            // DEL-103: Konsistentes 16pt-Spacing zwischen allen Bento-Cards.
            // VStack-spacing + uniformes horizontales 16pt-Padding sind die
            // einzige geometrische Quelle der Wahrheit — nicht mehr pro-Card
            // .padding(.horizontal) etc.
            VStack(alignment: .leading, spacing: 16) {
                // DEL-109: heroMetrics bleibt statisch ueber den
                // konfigurierbaren Widgets — zu zentral fuer das Brand,
                // nicht via Toggle abschaltbar.
                heroMetrics

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
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // DEL-102: Off-Weiss / Off-Schwarz-Background, gegen den die
        // Bento-Cards (Surface) abheben. Im Light-Mode identisch zu
        // systemGroupedBackground, im Dark-Mode warmer (#0A0A0A statt #000).
        .background(Color.Deltiq.background.ignoresSafeArea())
        // DEL-073: Navigation-Title aus xcstrings.
        .navigationTitle(Text("dashboard.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: MeasurementView()) {
                    Label {
                        Text("dashboard.newMeasurement", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
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
    private var trophyRoomCard: some View {
        NavigationLink {
            PRHistoryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.yellow.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("dashboard.trophy.title", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if prCount == 0 {
                        Text("dashboard.trophy.empty", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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

    private var prCount: Int { personalRecords.count }

    /// "Bankdrücken vor 2 Tagen" — short last-PR teaser when the table has rows.
    private var latestPRSummary: String? {
        guard let latest = personalRecords.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: latest.date, relativeTo: Date())
        return "\(latest.exerciseName) \(relative)"
    }

    // MARK: - History teaser (DEL-019)

    /// Prominent entry point to the full WorkoutHistoryView. Mirror der Trophy-
    /// Room-Card: kompakt, klickbar, mit Count und letztem-Workout-Teaser.
    /// Vorher war die History nur ueber "Alle anzeigen" am Ende der Recent-
    /// Workouts-Sektion erreichbar — User-Feedback war "find ich nicht".
    private var historyCard: some View {
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

    // DEL-120: drei Varianten via xcstrings:
    //   * empty            -> "dashboard.history.empty"
    //   * count + last     -> "dashboard.history.countWithLast" (2-Arg-Format)
    //   * count nur        -> "dashboard.history.countOnly"
    private var historyTeaserText: String {
        let real = completedSessions.filter { !$0.isRestDay }
        if real.isEmpty {
            return String(localized: "dashboard.history.empty", bundle: .module)
        }
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

    private var heroMetrics: some View {
        Group {
            if let latest = measurements.first {
                HStack(spacing: 12) {
                    MetricCard(
                        label: String(localized: "metric.weight", bundle: .module),
                        value: latest.weightKg.truncated(to: 2).formattedTwoDecimals,
                        unit: "kg",
                        delta: weeklyWeightDelta()
                    )
                    MetricCard(
                        label: String(localized: "metric.kfaNavy", bundle: .module),
                        value: latest.navyBodyFatPct?.truncated(to: 2).formattedTwoDecimals ?? "—",
                        unit: latest.navyBodyFatPct != nil ? "%" : nil,
                        delta: nil
                    )
                    MetricCard(
                        label: String(localized: "metric.ffmi", bundle: .module),
                        value: latest.ffmi?.truncated(to: 2).formattedTwoDecimals ?? "—",
                        unit: nil,
                        delta: nil
                    )
                }
            } else {
                EmptyMetricsCard()
            }
        }
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
                EmptyTrendCard()
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
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Datum", p.date),
                            y: .value("Gewicht (kg)", p.weight)
                        )
                        .foregroundStyle(.blue)
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
                                                              with: goal.truncated(to: 2).formattedTwoDecimals))
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
            let day = nextScheduledDay(in: plan)
            // Nur explizit als .rest markierte Tage gelten als Ruhetag.
            // Leere Trainingstage (User noch nicht fertig konfiguriert) sind
            // KEINE Ruhetage — sie zeigen den disabled "Training starten"-
            // Button mit Hint, dass Uebungen fehlen (DEL-021/023).
            let isRestDay = day.type == .rest
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // DEL-105: Brand-Akzent fuer Trainings-Tage statt iOS-Blau.
                    // Rest-Day-Branch bleibt Purple — semantische Farbe fuer Ruhe.
                    Image(systemName: isRestDay ? "bed.double.fill" : "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background((isRestDay ? Color.purple : Color.deltiqOrange).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRestDay
                             ? "dashboard.plan.todayRestDay"
                             : "dashboard.plan.nextWorkout",
                             bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(day.name)
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
                    Text(exercisesPreview(for: day))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
                            Text("dashboard.plan.checkoffRestDay", bundle: .module)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
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
            // DEL-102: Bento-Card.
            .deltiqCardStyle()
        } else {
            // No active plan or active plan has no days yet.
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activePlans.isEmpty
                             ? "dashboard.plan.noActivePlan"
                             : "dashboard.plan.planEmpty",
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
            // DEL-102: Bento-Card.
            .deltiqCardStyle()
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
        if let context = activeCoachingContext, let profile = profiles.first {
            let message = CoachingMessageProvider.message(
                for: context,
                tone: profile.coachingTone,
                goal: profile.trainingGoal
            )
            if !message.isEmpty {
                // DEL-100 + DEL-102: Bento-Card mit warmem DeltiqOrange-Tint.
                // Bewusst NICHT die generische .deltiqCardStyle() — die
                // Coaching-Insight haben wir absichtlich orange-getoent fuer
                // visuelle Differenzierung vom Plan-Card.
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                        .font(.title3)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.deltiqOrange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.deltiqOrange.opacity(0.20), lineWidth: 1)
                )
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

    private func exercisesPreview(for day: TrainingDay) -> String {
        // DEL-049: archivierte Snapshots (Urlaubs-Modus) gehoeren nicht in
        // die Dashboard-Vorschau — sonst zeigt der Card "Bankdruecken" auch
        // wenn der User nur noch Liegestuetze trainiert.
        let active = day.activeExercises
        let names = active
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map { $0.displayName }   // DEL-111: lokalisierter Name fuer Library-Übungen
        let joined = names.joined(separator: ", ")
        // DEL-121: Apple's format-as-key Plural-Convention war
        // "%lld Übungen — %@" mit variations.plural. Xcode 26.4.1's
        // GenerateStringSymbols-Step chokes auf den format-pattern-keys,
        // daher umgestellt auf explizite one/other namespace-Keys mit
        // manueller %lld/%@-Substitution.
        let key: String.LocalizationValue = active.count == 1
            ? "dashboard.exercisesPreview.one"
            : "dashboard.exercisesPreview.other"
        let raw = String(localized: key, bundle: .module)
        let template = raw
            .replacingOccurrences(of: "%1$lld", with: "\(active.count)")
            .replacingOccurrences(of: "%2$@",   with: joined)
        return active.count > 3 ? template + " …" : template
    }

    /// DEL-042: Adaptive Start-Button. Drei States:
    ///   1. Keine offene Session       → "Direkt starten" (blau, neu)
    ///   2. Offene Session AUF DEM-Tag → "Fortsetzen" (orange, navigiert in
    ///      die existing Session — kein neuer Insert)
    ///   3. Offene Session AUF ANDEREM Tag → "Direkt starten", Klick
    ///      triggert Conflict-Dialog mit drei Optionen.
    /// DEL-105: Beide Branches nutzen jetzt `.deltiqButtonStyle()` (Hero-CTA-
    /// Modifier aus DEL-102). Mode-Unterscheidung "Fortsetzen" vs "Direkt
    /// starten" laeuft nur noch ueber Label + Icon, nicht ueber Farbe — das
    /// frueher blau-vs-orange Pattern stoerte das Markenbild.
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
            // DEL-073: Beide Branches via xcstrings.
            Label {
                Text(matchingOpen != nil
                     ? "dashboard.action.resumeRunning"
                     : "dashboard.action.startDirect",
                     bundle: .module)
            } icon: {
                Image(systemName: matchingOpen != nil ? "play.circle.fill" : "play.fill")
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

    /// Deep-link from Dashboard into ActiveWorkout: build a stack [plan, day, active]
    /// on the workout tab so the user can back out to DayEditor (after Discard) or
    /// PlanEditor without losing context.
    private func actuallyStartNewWorkout(plan: TrainingPlan, day: TrainingDay) {
        guard !day.activeExercises.isEmpty else { return }

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
        // Ephemerer Tag — kein `plan`, taucht in keinem PlanEditor/PlansList
        // auf, weil alle Plan-Queries `plan != nil`-implizit filtern (via
        // `\TrainingPlan.days`-Inverse).
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let adHocDay = TrainingDay(
            name: "Spontanes Workout",
            weekday: todayWeekday,
            type: .custom,
            plan: nil
        )
        modelContext.insert(adHocDay)

        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: 0,
            isCompleted: false,
            isAdHoc: true,
            dayName: "Spontanes Workout",
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

    /// Names of the five canonical compound lifts (matches `isSystemCompound: true`
    /// in `ExerciseLibraryData`). Hard-coded here so the dashboard doesn't need to
    /// query the seed library at every render.
    private static let compoundLiftNames = [
        "Kniebeuge",
        "Bankdrücken",
        "Kreuzheben (konventionell)",
        "Schulterdrücken (stehend)",
        "Rudern vorgebeugt"
    ]

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
                guard let best = estimates.max(),
                      let firstDate = logs.map(\.date).min() else { return nil }
                return CompoundPoint(date: firstDate, oneRM: best)
            }
            .sorted { $0.date < $1.date }

            // Need ≥2 points for a meaningful line
            guard points.count >= 2 else { return nil }
            return CompoundSeries(exerciseName: name, points: points)
        }
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

            let series = compoundSeries
            if series.isEmpty {
                // DEL-103: Empty-State erbt die Bento-Surface vom outer
                // .deltiqCardStyle() — kein eigenes Background mehr noetig.
                HStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.compoundChart.empty.title", bundle: .module)
                            .font(.subheadline)
                        Text("dashboard.compoundChart.empty.hint", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points) { point in
                            LineMark(
                                x: .value("Datum", point.date),
                                y: .value("1RM (kg)", point.oneRM),
                                series: .value("Lift", line.exerciseName)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(by: .value("Lift", line.exerciseName))
                            .symbol(by: .value("Lift", line.exerciseName))

                            PointMark(
                                x: .value("Datum", point.date),
                                y: .value("1RM (kg)", point.oneRM)
                            )
                            .foregroundStyle(by: .value("Lift", line.exerciseName))
                            .symbolSize(40)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        // DEL-103: Achsen-Labels mit rounded/monospaced Design,
                        // damit die Datums-Ticks zum sportlichen Numerik-Look passen.
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 220)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("dashboard.weeklySummary.title", bundle: .module)
                    .font(.headline)
                HStack(spacing: 12) {
                    if volumeKg > 0 {
                        // DEL-105: Indigo statt iOS-Default-Blau fuer Strength —
                        // erhaelt die semantische Differenzierung zum Cardio-
                        // Orange-Tile, ohne wieder in den System-Akzent zu fallen.
                        weeklyStatTile(
                            label: String(localized: "dashboard.weeklySummary.volume", bundle: .module),
                            value: formatVolumeKg(volumeKg),
                            unit: "kg",
                            icon: "scalemass.fill",
                            tint: .indigo
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
            // DEL-103: Bento-Card als outer Container fuer Header+Tiles.
            .deltiqCardStyle()
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
        // DEL-103: Tiles sitzen IN einer Bento-Card (Surface-Background), also
        // brauchen sie selbst nur einen ganz leichten Tint, um sich abzuheben.
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// User-Locale-respektierende "Anfang der aktuellen Kalenderwoche".
    private func currentWeekStart() -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    private func formatVolumeKg(_ kg: Double) -> String {
        let rounded = kg.truncated(to: 0)
        return rounded.formattedTwoDecimals
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
            .flatMap(\.logs)
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
        let byName = Dictionary(grouping: allCardioLogs) { log in
            log.resolvedExerciseName ?? "—"
        }
        return byName.compactMap { (name, logs) -> CardioPaceSeries? in
            // Pro Session aggregieren (Datum = Session-Start, Pace = total/total).
            let bySession = Dictionary(grouping: logs) { log in
                log.session?.persistentModelID
            }
            let points: [CardioPacePoint] = bySession.compactMap { (_, sessionLogs) -> CardioPacePoint? in
                let totalKm = sessionLogs.compactMap(\.distanceKm).reduce(0.0, +)
                let totalSec = sessionLogs.compactMap(\.durationSeconds).reduce(0, +)
                guard totalKm > 0, totalSec > 0,
                      let pace = PaceCalculator.minutesPerKm(distanceKm: totalKm, durationSeconds: totalSec),
                      let date = sessionLogs.map(\.date).min()
                else { return nil }
                return CardioPacePoint(date: date, paceMinPerKm: pace, distanceKm: totalKm)
            }
            .sorted { $0.date < $1.date }
            guard points.count >= 2 else { return nil }
            return CardioPaceSeries(exerciseName: name, points: points)
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

    @ViewBuilder
    private var cardioPaceChart: some View {
        let series = cardioSeries
        if shouldShowCardioChart, !series.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("dashboard.cardioChart.title", bundle: .module)
                        .font(.headline)
                    Spacer()
                    Text("dashboard.cardioChart.legend", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(series) { line in
                        ForEach(line.points) { point in
                            LineMark(
                                x: .value("Datum", point.date),
                                y: .value("Pace (min/km)", point.paceMinPerKm),
                                series: .value("Lauf", line.exerciseName)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(by: .value("Lauf", line.exerciseName))
                            .symbol(by: .value("Lauf", line.exerciseName))

                            PointMark(
                                x: .value("Datum", point.date),
                                y: .value("Pace (min/km)", point.paceMinPerKm)
                            )
                            .foregroundStyle(by: .value("Lauf", line.exerciseName))
                            .symbolSize(40)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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
                // DEL-103: Empty-State sitzt direkt auf der Bento-Surface.
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.recent.empty.title", bundle: .module)
                            .font(.subheadline)
                        Text("dashboard.recent.empty.hint", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(localizedMuscleName)
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
                Text(entry.bucket.label.uppercased())
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
        .accessibilityLabel("\(localizedMuscleName), \(entry.setsCount) Sätze, \(entry.bucket.label)")
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

    /// Deutsche User-Labels — Single-Source-of-Truth waere
    /// `DomainEnums+Localization.localizedName`, aber das ist eine
    /// LocalizedStringResource — fuer die kompakte Tile-Zeile reicht der
    /// einfache String-Mapping.
    private var localizedMuscleName: String {
        switch entry.group {
        case .chest:      return "Brust"
        case .back:       return "Rücken"
        case .shoulders:  return "Schultern"
        case .biceps:     return "Bizeps"
        case .triceps:    return "Trizeps"
        case .quads:      return "Quads"
        case .hamstrings: return "Hams"
        case .glutes:     return "Gesäß"
        case .calves:     return "Waden"
        case .core:       return "Core"
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
                Text(session.dayName ?? "Training")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                    Text("•")
                    Text("\(session.durationMinutes) Min")
                    Text("•")
                    Text("\(session.totalSets) Sätze")
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
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct MetricCard: View {
    let label: String
    let value: String
    let unit: String?
    let delta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // DEL-102: fitnessNumberStyle ersetzt das manuelle
                // .monospacedDigit() + erzwingt zusaetzlich .fontDesign(.rounded),
                // damit die Hero-Zahlen sportlicher und kohaerent mit Timer-
                // Anzeigen sind.
                Text(value)
                    .font(.title2.weight(.semibold))
                    .fitnessNumberStyle()
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let delta {
                deltaLabel(delta)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        // DEL-102: Sub-Card-Format (kleiner Corner-Radius, kompakteres Padding)
        // — die Metric-Cards sind enthalten in einer Reihe von drei und sollten
        // schmaler wirken als die Top-Level-Bento-Cards.
        .deltiqCardStyle(padding: 12, cornerRadius: 14)
    }

    private func deltaLabel(_ delta: Double) -> some View {
        let prefix = delta > 0 ? "+" : (delta < 0 ? "" : "±")
        let formatted = abs(delta).truncated(to: 2).formattedTwoDecimals
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
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EmptyTrendCard: View {
    var body: some View {
        Label {
            Text("dashboard.trend.empty", bundle: .module)
        } icon: {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

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
