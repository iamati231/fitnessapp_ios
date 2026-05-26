#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import FitnessAppCore
import FitnessAppData

/// Trophy Room — every personal record the user has ever set, grouped by exercise.
/// Tapping a row expands a Swift-Charts line chart of that exercise's headline-kind
/// PR over time, plus a flat list of every individual record (across all kinds).
///
/// **Empty state** — first launch after this feature shipped, the table is empty.
/// The "Aus History neu berechnen" toolbar button runs a full backfill via
/// `PersonalRecordSync.rebuild` so existing users see their historic PRs without
/// waiting for the next workout.
@available(iOS 17.0, macOS 14.0, *)
public struct PRHistoryView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PersonalRecordEntry.date, order: .reverse)
    private var entries: [PersonalRecordEntry]

    /// Used by the empty-state CTA to know whether a backfill would actually
    /// produce anything.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true })
    private var completedSessions: [WorkoutSession]

    /// Active filter chip — `nil` means "all kinds".
    @State private var selectedKind: PersonalRecord.Kind? = nil

    /// Confirmation alert for the destructive rebuild action.
    @State private var showRebuildConfirm = false

    /// Toast message after a rebuild succeeds. Nil when no toast is showing.
    @State private var rebuildToast: String? = nil

    public init() {}

    public var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle(Text("dashboard.trophy.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showRebuildConfirm = true
                    } label: {
                        Label {
                            Text("trophy.rebuild.menu", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(completedSessions.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(Text("trophy.rebuild.confirm.title", bundle: .module), isPresented: $showRebuildConfirm) {
            Button(role: .cancel) { } label: {
                Text("common.cancel", bundle: .module)
            }
            Button(role: .destructive) {
                rebuild()
            } label: {
                Text("trophy.rebuild.confirm.cta", bundle: .module)
            }
        } message: {
            Text("trophy.rebuild.confirm.message", bundle: .module)
        }
        .overlay(alignment: .bottom) {
            if let toast = rebuildToast {
                Label(toast, systemImage: "checkmark.seal.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Empty + main content

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label {
                    Text("trophy.empty.title", bundle: .module)
                } icon: {
                    Image(systemName: "trophy")
                }
            } description: {
                Text(completedSessions.isEmpty
                     ? "trophy.empty.description.firstWorkout"
                     : "trophy.empty.description.hasWorkouts",
                     bundle: .module)
            } actions: {
                if !completedSessions.isEmpty {
                    Button {
                        showRebuildConfirm = true
                    } label: {
                        Label {
                            Text("trophy.empty.cta.detect", bundle: .module)
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var content: some View {
        List {
            kindFilterSection
            ForEach(grouped) { group in
                ExerciseTrophySection(
                    group: group,
                    selectedKind: selectedKind
                )
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: Filter chips

    private var kindFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    KindChip(kind: nil, isSelected: selectedKind == nil) {
                        selectedKind = nil
                    }
                    ForEach(availableKinds, id: \.self) { kind in
                        KindChip(kind: kind, isSelected: selectedKind == kind) {
                            selectedKind = (selectedKind == kind) ? nil : kind
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            HStack {
                Text(String(format: String(localized: "trophy.totalRecords", bundle: .module), filteredCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .textCase(nil)
        }
    }

    private var availableKinds: [PersonalRecord.Kind] {
        let raw = Set(entries.compactMap(\.kind))
        // Stable display order — same priority as PRDetector.kindOrder.
        return [.estimated1RM, .heaviestWeight, .bestSet, .maxReps, .maxHoldSeconds]
            .filter { raw.contains($0) }
    }

    private var filteredCount: Int {
        guard let kind = selectedKind else { return entries.count }
        return entries.filter { $0.kind == kind }.count
    }

    // MARK: Grouping

    /// Entries grouped by exerciseName, with the headline kind chosen per
    /// exercise. Sorted by most-recent-PR first so the Trophy Room "tells a
    /// story" — what the user has set lately bubbles up.
    private var grouped: [ExerciseTrophyGroup] {
        let filtered = selectedKind.map { kind in
            entries.filter { $0.kind == kind }
        } ?? entries

        let byExercise = Dictionary(grouping: filtered, by: \.exerciseName)
        return byExercise.compactMap { (name, rows) -> ExerciseTrophyGroup? in
            guard !rows.isEmpty else { return nil }
            let sorted = rows.sorted { $0.date > $1.date }
            return ExerciseTrophyGroup(
                exerciseName: name,
                entries: sorted,
                latestDate: sorted.first?.date ?? .distantPast
            )
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    // MARK: Actions

    private func rebuild() {
        let inserted = PersonalRecordSync.rebuild(in: modelContext)
        try? modelContext.save()
        withAnimation(.easeOut(duration: 0.2)) {
            rebuildToast = "\(inserted) Rekorde detektiert"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                rebuildToast = nil
            }
        }
    }
}

// MARK: - Exercise group container

@available(iOS 17.0, macOS 14.0, *)
struct ExerciseTrophyGroup: Identifiable {
    var id: String { exerciseName }
    let exerciseName: String
    let entries: [PersonalRecordEntry]
    let latestDate: Date
}

// MARK: - One exercise's section (DisclosureGroup with chart + flat list)

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseTrophySection: View {

    let group: ExerciseTrophyGroup
    let selectedKind: PersonalRecord.Kind?

    @State private var isExpanded: Bool = false
    @State private var chartKind: PersonalRecord.Kind = .estimated1RM

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                expansionContent
            } label: {
                headerLabel
            }
        }
    }

    // MARK: Header

    private var headerLabel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // DEL-149: Snapshot-resolver — der Group-Key bleibt der
                // stabile DE-Base-Name (gruppe Sortierung/Identitaet); die
                // sichtbare Anzeige laeuft via Library-Lookup in die aktuelle
                // Sprache.
                Text(Exercise.resolvedDisplayName(forStoredName: group.exerciseName))
                    .font(.body.weight(.semibold))
                Text("\(group.entries.count) PR\(group.entries.count == 1 ? "" : "s") • zuletzt \(group.latestDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(uniqueKinds.prefix(3), id: \.self) { kind in
                Image(systemName: PRKindStyle.icon(kind))
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(PRKindStyle.color(kind).gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    // MARK: Expansion

    @ViewBuilder
    private var expansionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            kindPicker
            chartView
            Divider()
            entriesList
        }
        .padding(.vertical, 4)
        .onAppear {
            // Default the chart to the most-impressive kind we have — 1RM > heaviest > bestSet > maxReps > maxHoldSeconds.
            chartKind = uniqueKinds.first ?? chartKind
        }
    }

    @ViewBuilder
    private var kindPicker: some View {
        if uniqueKinds.count > 1 {
            Picker("Kind", selection: $chartKind) {
                ForEach(uniqueKinds, id: \.self) { kind in
                    Text(PRKindStyle.shortLabel(kind)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var chartView: some View {
        let series = chartPoints
        if series.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(PRKindStyle.shortLabel(chartKind)) - Verlauf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(series) { point in
                        LineMark(
                            x: .value("Datum", point.date),
                            y: .value(PRKindStyle.yAxisLabel(chartKind), point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(PRKindStyle.color(chartKind))

                        PointMark(
                            x: .value("Datum", point.date),
                            y: .value(PRKindStyle.yAxisLabel(chartKind), point.value)
                        )
                        .foregroundStyle(PRKindStyle.color(chartKind))
                        .symbolSize(50)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 160)
            }
        } else if series.count == 1 {
            Label {
                Text(String(format: String(localized: "trophy.singleEntry", bundle: .module), PRKindStyle.shortLabel(chartKind)))
            } icon: {
                Image(systemName: "info.circle")
            }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Alle Rekorde")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            ForEach(visibleEntries) { entry in
                // NavigationLink only when the originating session still exists
                // (deleteRule on session is .nullify, so a deleted-session PRE
                // survives but loses its back-link). Disabled-row fallback is
                // visually identical, just non-tappable.
                if let session = entry.session {
                    NavigationLink {
                        WorkoutSummaryView(session: session, isReadOnly: true)
                    } label: {
                        PRHistoryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                } else {
                    PRHistoryRow(entry: entry)
                }
                if entry.id != visibleEntries.last?.id {
                    Divider().opacity(0.4)
                }
            }
        }
    }

    // MARK: Derived

    /// Unique kinds in this exercise's entry list, in display-priority order.
    /// Filtered to the currently-selected chip if any.
    private var uniqueKinds: [PersonalRecord.Kind] {
        let raw = Set(group.entries.compactMap(\.kind))
        let order: [PersonalRecord.Kind] = [
            .estimated1RM, .heaviestWeight, .bestSet, .maxReps, .maxHoldSeconds
        ]
        let ordered = order.filter { raw.contains($0) }
        if let selected = selectedKind {
            return ordered.filter { $0 == selected }
        }
        return ordered
    }

    private var chartPoints: [PRChartPoint] {
        group.entries
            .filter { $0.kind == chartKind }
            .sorted { $0.date < $1.date }
            .map { PRChartPoint(id: $0.persistentModelID, date: $0.date, value: $0.value) }
    }

    private var visibleEntries: [PersonalRecordEntry] {
        if let selected = selectedKind {
            return group.entries.filter { $0.kind == selected }
        }
        return group.entries
    }
}

// MARK: - Chart point value-type

@available(iOS 17.0, macOS 14.0, *)
struct PRChartPoint: Identifiable, Hashable {
    let id: PersistentIdentifier
    let date: Date
    let value: Double
}

// MARK: - One PR row

@available(iOS 17.0, macOS 14.0, *)
private struct PRHistoryRow: View {
    let entry: PersonalRecordEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: PRKindStyle.icon(entry.kind ?? .heaviestWeight))
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(PRKindStyle.color(entry.kind ?? .heaviestWeight).gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(PRKindStyle.shortLabel(entry.kind ?? .heaviestWeight))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(detailLine)
                    .font(.callout.monospacedDigit())
            }
            Spacer()
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private var detailLine: String {
        guard let kind = entry.kind else {
            return "\(formatNumber(entry.value))"
        }
        switch kind {
        case .maxReps:
            return "\(entry.reps) Wdh (vorher \(Int(entry.previousValue.rounded())))"
        case .maxHoldSeconds:
            return "\(entry.reps) Sek (vorher \(Int(entry.previousValue.rounded())) Sek)"
        case .heaviestWeight, .estimated1RM:
            return "\(formatNumber(entry.value)) kg (vorher \(formatNumber(entry.previousValue)) kg)"
        case .bestSet:
            return "\(formatNumber(entry.weightKg)) kg × \(entry.reps) = \(formatNumber(entry.value)) kg-Vol"
        // DEL-064 Cardio-PRs — Xcode-26-strict braucht alle Cases.
        case .longestDistance:
            return "\(formatKm(entry.value)) km (vorher \(formatKm(entry.previousValue)) km)"
        case .fastestPace:
            return "\(formatPace(entry.value)) (vorher \(formatPace(entry.previousValue)))"
        }
    }

    /// DEL-064: km-Formatter (Spiegelung von WorkoutSummaryView.formatKm).
    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 2).formattedTwoDecimals
    }

    /// DEL-064: Pace-Formatter (min/km Double → "5:42 /km").
    private func formatPace(_ minutesPerKm: Double) -> String {
        guard minutesPerKm.isFinite, minutesPerKm > 0 else { return "—:——" }
        let total = Int((minutesPerKm * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    private func formatNumber(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : value.truncated(to: 2).formattedTwoDecimals
    }
}

// MARK: - Filter chip

@available(iOS 17.0, macOS 14.0, *)
private struct KindChip: View {
    let kind: PersonalRecord.Kind?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let kind {
                    Image(systemName: PRKindStyle.icon(kind))
                        .font(.caption)
                }
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var label: String {
        guard let kind else { return "Alle" }
        return PRKindStyle.shortLabel(kind)
    }

    /// `AnyGradient` is a `ShapeStyle`, not a `View` — wrapping it in a Rectangle
    /// (clipped by the parent's Capsule) is the canonical workaround. Returning
    /// the gradient directly trips a `buildExpression` error in macOS 14's
    /// stricter ViewBuilder.
    @ViewBuilder
    private var background: some View {
        if isSelected {
            Rectangle()
                .fill((kind.map(PRKindStyle.color) ?? .accentColor).gradient)
        } else {
            Color.secondary.opacity(0.10)
        }
    }
}

// MARK: - Style mapping (single source of truth, shared with PRBadge)

/// Maps `PersonalRecord.Kind` to icon / color / labels for the Trophy Room.
/// Mirrors the `PRBadge` mapping in `WorkoutSummaryView` — keep in sync if you
/// change one, change the other (or refactor into Core if it grows).
@available(iOS 17.0, macOS 14.0, *)
enum PRKindStyle {
    static func icon(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .estimated1RM:    "bolt.fill"
        case .heaviestWeight:  "scalemass.fill"
        case .bestSet:         "chart.bar.fill"
        case .maxReps:         "arrow.up.arrow.down"
        case .maxHoldSeconds:  "stopwatch.fill"
        // DEL-064 Cardio-PRs (Spiegelung von WorkoutSummaryView's PRBadge).
        case .longestDistance: "figure.run.circle.fill"
        case .fastestPace:     "hare.fill"
        }
    }

    static func color(_ kind: PersonalRecord.Kind) -> Color {
        switch kind {
        case .estimated1RM:    .orange
        case .heaviestWeight:  .red
        case .bestSet:         .blue
        case .maxReps:         .purple
        case .maxHoldSeconds:  .yellow
        case .longestDistance: Color.deltiqOrange
        case .fastestPace:     .green
        }
    }

    /// Short label for chips + segmented picker — full label lives in PRBadge.
    static func shortLabel(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .estimated1RM:    "1RM"
        case .heaviestWeight:  "Max-Gewicht"
        case .bestSet:         "Bestsatz"
        case .maxReps:         "Max Reps"
        case .maxHoldSeconds:  "Bestzeit"
        case .longestDistance: "Distanz"
        case .fastestPace:     "Pace"
        }
    }

    /// Y-axis label for the per-kind chart.
    static func yAxisLabel(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .estimated1RM, .heaviestWeight: return "Gewicht (kg)"
        case .bestSet:                       return "Volumen (kg)"
        case .maxReps:                       return "Wdh"
        case .maxHoldSeconds:                return "Sekunden"
        case .longestDistance:               return "Distanz (km)"
        case .fastestPace:                   return "Pace (min/km)"
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Trophy Room") {
    NavigationStack {
        PRHistoryView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}
#endif
#endif
