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
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PersonalRecordEntry.date, order: .reverse)
    private var entries: [PersonalRecordEntry]

    /// Settings-Epic Phase 6 (EXLIB-07/09): fuer die ID-first-Aufloesung des
    /// aktuellen Anzeige-Namens pro Trophy-Gruppe (`grouped`). ~Hunderte
    /// Zeilen — ein `Dictionary`-Aufbau pro Render ist vernachlaessigbar,
    /// gleiches Performance-Argument wie `ExerciseTemplate+DisplayName.swift`.
    @Query private var allTemplates: [ExerciseTemplate]

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
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt vom Dashboard gepusht (kein
            // eigener Zwischen-Hub).
            // Fix-Runde 1 (Finding 3): die Eyebrow nutzte bisher den
            // `tab.dashboard`-Key, dessen Wert main-navigation Task 1 auf
            // "Heute" umbenannt hat — diese Liste ist aber eine All-Time-
            // Rekordliste, kein Tages-Scope. Eigener `trophy.eyebrow`-Key.
            DeltiqHeader(
                eyebrow: String(localized: "trophy.eyebrow", bundle: .module).uppercased(),
                title: String(localized: "dashboard.trophy.title", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    DeltiqHeaderAction(systemImage: "ellipsis", menu: {
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
                    })
                ]
            )

            if entries.isEmpty {
                emptyState
            } else {
                content
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
        .deltiqSwipeBackEnabled()
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
        VStack(alignment: .leading, spacing: 18) {
            if completedSessions.isEmpty {
                DashboardEmptyState(
                    icon: "trophy",
                    title: "trophy.empty.title",
                    description: "trophy.empty.description.firstWorkout"
                )
                .deltiqCardStyle()
            } else {
                DashboardEmptyState(
                    icon: "trophy",
                    title: "trophy.empty.title",
                    description: "trophy.empty.description.hasWorkouts",
                    ctaTitle: "trophy.empty.cta.detect",
                    ctaAction: { showRebuildConfirm = true }
                )
                .deltiqCardStyle()
            }
        }
        .deltiqScreen()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            kindFilterCard
            ForEach(grouped) { group in
                ExerciseTrophySection(
                    group: group,
                    selectedKind: selectedKind
                )
            }
        }
        .deltiqScreen()
    }

    // MARK: Filter chips

    private var kindFilterCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "trophy.totalRecords", bundle: .module), filteredCount))
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
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
        }
    }

    private var availableKinds: [PersonalRecord.Kind] {
        let raw = Set(entries.compactMap(\.kind))
        // DEL-218: `Kind.displayOrder` statt eines lokalen Literals. Das
        // frühere Literal liess .longestDistance und .fastestPace weg —
        // Cardio-PRs waren dadurch nicht filterbar.
        return PersonalRecord.Kind.displayOrder.filter { raw.contains($0) }
    }

    private var filteredCount: Int {
        guard let kind = selectedKind else { return entries.count }
        return entries.filter { $0.kind == kind }.count
    }

    // MARK: Grouping

    /// Entries grouped by exercise identity, with the headline kind chosen
    /// per exercise. Sorted by most-recent-PR first so the Trophy Room
    /// "tells a story" — what the user has set lately bubbles up.
    private var grouped: [ExerciseTrophyGroup] {
        let filtered = selectedKind.map { kind in
            entries.filter { $0.kind == kind }
        } ?? entries

        // DEL-156: Gruppierung nach (Identitaet, Cardio-Equipment). Non-
        // Cardio-PRs tragen .none → effektiv "nur nach Identitaet". Cardio-
        // PRs splitten nach Modalitaet (Laufband ≠ Fahrrad) in eigene
        // Trophy-Reihen.
        //
        // Settings-Epic Phase 6 (EXLIB-07/09): Identitaet ist bevorzugt die
        // stabile `exerciseTemplateID` (ueberlebt ein Umbenennen); nur
        // Eintraege ohne aufloesbare ID gruppieren weiterhin per Name
        // (unveraendertes Alt-Verhalten).
        let byExercise = Dictionary(grouping: filtered) { entry in
            TrophyGroupKey(
                identity: entry.exerciseTemplateID.map(TrophyGroupKey.Identity.id) ?? .name(entry.exerciseName),
                equipment: entry.cardioEquipment
            )
        }
        let templatesByID = Dictionary(uniqueKeysWithValues: allTemplates.map { ($0.id, $0) })
        return byExercise.compactMap { (key, rows) -> ExerciseTrophyGroup? in
            guard !rows.isEmpty else { return nil }
            let sorted = rows.sorted { $0.date > $1.date }
            let fallbackName = sorted.first?.exerciseName ?? ""
            let templateID: UUID? = if case .id(let id) = key.identity { id } else { nil }
            // ID aufloesbar + Vorlage noch vorhanden → deren LIVE-Name
            // (ueberlebt Umbenennen). Sonst: bisherige Snapshot-Namens-
            // Aufloesung (Sprachfest ueber Reverse-Lookup), unveraendert.
            let resolvedName = templateID.flatMap { templatesByID[$0] }?.displayName
                ?? Exercise.resolvedDisplayName(forStoredName: fallbackName)
            return ExerciseTrophyGroup(
                exerciseTemplateID: templateID,
                exerciseName: fallbackName,
                displayName: resolvedName,
                cardioEquipment: key.equipment,
                entries: sorted,
                latestDate: sorted.first?.date ?? .distantPast
            )
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    // MARK: Actions

    private func rebuild() {
        let inserted = PersonalRecordSync.rebuild(in: modelContext)
        // Audit-Fix (Save-Fehler): zeigte bisher UNBEDINGT "N Rekorde
        // detektiert", auch wenn der Save fehlschlug - schlimmer als ein
        // stilles Verschlucken, weil es aktiv einen nie gespeicherten Erfolg
        // behauptet. Jetzt nur bei tatsaechlich erfolgreichem Save.
        let message: String
        do {
            try modelContext.save()
            message = "\(inserted) Rekorde detektiert"
        } catch {
            message = String(localized: "day.editor.save.failed", bundle: .module)
        }
        withAnimation(.easeOut(duration: 0.2)) {
            rebuildToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                rebuildToast = nil
            }
        }
    }
}

// MARK: - Exercise group container

/// DEL-156 / Settings-Epic Phase 6 (EXLIB-07/09): Composite-Gruppierungs-
/// Schluessel fuer den Trophy-Room. Identitaet ist ID-first — siehe
/// `PRHistoryView.grouped` fuer die Begruendung (nie ID und Name gemischt,
/// sonst koennte ein zufaelliger Namens-Treffer zwei Uebungen zusammenlegen).
@available(iOS 17.0, macOS 14.0, *)
struct TrophyGroupKey: Hashable {
    enum Identity: Hashable {
        case id(UUID)
        case name(String)
    }
    let identity: Identity
    let equipment: CardioEquipment
}

@available(iOS 17.0, macOS 14.0, *)
struct ExerciseTrophyGroup: Identifiable {
    /// Composite-ID, damit Laufband- und Fahrrad-Reihen derselben Uebung als
    /// getrennte DisclosureGroups erscheinen (DEL-156). Nutzt die stabile
    /// `exerciseTemplateID`, wenn vorhanden, sonst den Namens-Snapshot.
    var id: String { "\(exerciseTemplateID?.uuidString ?? exerciseName)|\(cardioEquipment.rawValue)" }
    /// Settings-Epic Phase 6 (EXLIB-07/09): stabile Vorlagen-ID, falls
    /// aufloesbar — `nil` fuer Alt-Gruppen ohne Backfill-Treffer.
    let exerciseTemplateID: UUID?
    /// Snapshot-Name der juengsten PR-Zeile — Fallback-Anzeige, wenn sich
    /// `exerciseTemplateID` nicht (mehr) zu einer lebenden Vorlage aufloesen
    /// laesst (z.B. geloescht).
    let exerciseName: String
    /// Bereits aufgeloester Anzeige-Name (live Vorlagen-Name bei ID-Treffer,
    /// sonst sprachfeste Snapshot-Aufloesung) — siehe `PRHistoryView.grouped`.
    let displayName: String
    let cardioEquipment: CardioEquipment
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
        DisclosureGroup(isExpanded: $isExpanded) {
            expansionContent
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        } label: {
            headerLabel
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .deltiqCardStyle(padding: 0)
    }

    // MARK: Header

    private var headerLabel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // DEL-149: Snapshot-resolver — der Group-Key bleibt der
                // stabile DE-Base-Name (gruppe Sortierung/Identitaet); die
                // sichtbare Anzeige laeuft via Library-Lookup in die aktuelle
                // Sprache.
                // DEL-156: Bei Cardio-Gruppen mit konkretem Equipment haengen
                // wir das Equipment-Label an, damit Laufband-/Fahrrad-Reihen
                // unterscheidbar sind.
                HStack(spacing: 6) {
                    Text(group.displayName)
                        .font(.body.weight(.semibold))
                    if group.cardioEquipment != .none {
                        Label {
                            Text(group.cardioEquipment.localizedName)
                        } icon: {
                            Image(systemName: group.cardioEquipment.iconName)
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.deltiqOrange.opacity(0.15))
                        .foregroundStyle(Color.deltiqOrange)
                        .clipShape(Capsule())
                    }
                }
                Text("\(group.entries.count) PR\(group.entries.count == 1 ? "" : "s") • zuletzt \(group.latestDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            Spacer()
            // Handoff 1.10 (ein Akzent): alle Kind-Icons teilen sich jetzt
            // dasselbe Orange (wie PRBadge in WorkoutSummaryView) statt einer
            // Sieben-Farben-Skala — Unterscheidung laeuft ueber die Icon-Form.
            ForEach(uniqueKinds.prefix(3), id: \.self) { kind in
                Image(systemName: PRKindStyle.icon(kind))
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.deltiqOrange.gradient)
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
            Rectangle()
                .fill(Color.Deltiq.divider)
                .frame(height: 1)
            entriesList
        }
        .padding(.top, 4)
        .onAppear {
            // Default the chart to the most-impressive kind we have.
            // Reihenfolge: PersonalRecord.Kind.displayOrder (DEL-218).
            chartKind = uniqueKinds.first ?? chartKind
        }
    }

    @ViewBuilder
    private var kindPicker: some View {
        if uniqueKinds.count > 1 {
            DeltiqSegmentedPicker(
                options: uniqueKinds.map { kind in
                    DeltiqSegmentedOption(kind, label: PRKindStyle.shortLabel(kind))
                },
                selection: $chartKind
            )
        }
    }

    @ViewBuilder
    private var chartView: some View {
        let series = chartPoints
        if series.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(PRKindStyle.shortLabel(chartKind)) - Verlauf")
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Chart {
                    ForEach(series) { point in
                        LineMark(
                            x: .value("Datum", point.date),
                            y: .value(PRKindStyle.yAxisLabel(chartKind), point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.deltiqOrange)

                        PointMark(
                            x: .value("Datum", point.date),
                            y: .value(PRKindStyle.yAxisLabel(chartKind), point.value)
                        )
                        .foregroundStyle(Color.deltiqOrange)
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
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    @ViewBuilder
    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("prHistory.allRecords", bundle: .module)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
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
                    Rectangle()
                        .fill(Color.Deltiq.divider)
                        .frame(height: 1)
                }
            }
        }
    }

    // MARK: Derived

    /// Unique kinds in this exercise's entry list, in display-priority order.
    /// Filtered to the currently-selected chip if any.
    private var uniqueKinds: [PersonalRecord.Kind] {
        let raw = Set(group.entries.compactMap(\.kind))
        // DEL-218: siehe `availableKinds` — das lokale Literal hier war der
        // Grund, warum ein reiner Cardio-Nutzer weder Kind-Picker noch Chart
        // sah: `uniqueKinds` blieb leer, obwohl Cardio-Einträge vorlagen.
        let ordered = PersonalRecord.Kind.displayOrder.filter { raw.contains($0) }
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
                .background(Color.deltiqOrange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(PRKindStyle.shortLabel(entry.kind ?? .heaviestWeight))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Text(detailLine)
                    .font(.callout.monospacedDigit())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                // Handoff 1.10: Gruen bleibt reserviert fuer "Rekord" - hier die
                // Verbesserung ggue. dem vorherigen Bestwert, statt einer der
                // sieben Kind-Farben. Spiegelt PRBadge.improvementPill 1:1.
                if let improvementText {
                    Text(improvementText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.Deltiq.success)
                        .fitnessNumberStyle()
                }
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }

    /// DEL-064: fastestPace ist lower-is-better — die Verbesserung ist ein
    /// negativer Delta, daher invertiertes Vorzeichen (siehe
    /// PRBadge.improvementPill in WorkoutSummaryView). fastestTime (README
    /// 2.9) ist aus demselben Grund ebenfalls lower-is-better.
    private var improvementText: String? {
        guard entry.previousValue > 0, let kind = entry.kind else { return nil }
        let isLowerBetter = (kind == .fastestPace || kind == .fastestTime)
        let raw = (entry.value - entry.previousValue) / entry.previousValue
        let improvement = isLowerBetter ? -raw : raw
        guard improvement > 0 else { return nil }
        return "+\(improvement.formattedPercentRounded)"
    }

    private var detailLine: String {
        guard let kind = entry.kind else {
            return "\(entry.value.formattedWholeOrTwoDecimals)"
        }
        switch kind {
        case .maxReps:
            return "\(entry.reps) Wdh (vorher \(Int(entry.previousValue.rounded())))"
        case .maxHoldSeconds:
            return "\(entry.reps) Sek (vorher \(Int(entry.previousValue.rounded())) Sek)"
        case .heaviestWeight, .estimated1RM:
            return "\(entry.value.formattedWholeOrTwoDecimals) kg (vorher \(entry.previousValue.formattedWholeOrTwoDecimals) kg)"
        case .bestSet:
            return "\(entry.weightKg.formattedWholeOrTwoDecimals) kg × \(entry.reps) = \(entry.value.formattedWholeOrTwoDecimals) kg-Vol"
        // DEL-064 Cardio-PRs — Xcode-26-strict braucht alle Cases.
        case .longestDistance:
            return "\(entry.value.formattedWholeOrTwoDecimals) km (vorher \(entry.previousValue.formattedWholeOrTwoDecimals) km)"
        case .fastestPace:
            return "\(PaceCalculator.formatPace(entry.value)) (vorher \(PaceCalculator.formatPace(entry.previousValue)))"
        // Zeitformate (README 2.9) — Xcode-26-strict braucht alle Cases.
        case .mostRounds:
            // Nutzer-Feedback (13. August, zweite Runde): `partialReps` wird
            // seit `AMRAPPlayerView.finishBar` wieder befuellt (Ticket A hatte
            // die Eingabe entfernt, das Feld selbst blieb aber immer im
            // Modell) - der "+ N Wdh."-Zusatz gilt also wieder fuer neue PRs,
            // nicht nur fuer aeltere Bestandsdaten. `entry.reps == 0` bleibt
            // trotzdem der richtige Guard, sonst stuende bei jeder Session
            // ohne angebrochene Runde faelschlich "+ 0 Wdh" dabei.
            guard entry.reps > 0 else {
                return "\(Int(entry.value)) Runden (vorher \(Int(entry.previousValue)) Runden)"
            }
            return "\(Int(entry.value)) Runden + \(entry.reps) Wdh (vorher \(Int(entry.previousValue)) Runden)"
        case .fastestTime:
            return "\(PaceCalculator.formatDuration(Int(entry.value.rounded()))) (vorher \(PaceCalculator.formatDuration(Int(entry.previousValue.rounded()))))"
        }
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
                    .stroke(isSelected ? Color.clear : Color.Deltiq.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var label: String {
        guard let kind else { return "Alle" }
        return PRKindStyle.shortLabel(kind)
    }

    /// Handoff 1.10 (ein Akzent): alle Kinds teilen sich denselben Akzent —
    /// die fruehere Sieben-Farben-Skala pro Kind ist entfallen.
    /// `AnyGradient` ist ein `ShapeStyle`, kein `View` — Wrapping in ein
    /// Rectangle (geclippt vom Capsule-Parent) bleibt trotzdem noetig, weil
    /// diese Property `@ViewBuilder`/`some View` ist.
    @ViewBuilder
    private var background: some View {
        if isSelected {
            Rectangle().fill(Color.deltiqOrange.gradient)
        } else {
            Color.Deltiq.fill
        }
    }
}

// MARK: - Style mapping (single source of truth, shared with PRBadge)

/// Maps `PersonalRecord.Kind` to icon / labels for the Trophy Room. Mirrors
/// the `PRBadge` mapping in `WorkoutSummaryView` — keep in sync if you change
/// one, change the other (or refactor into Core if it grows).
///
/// Handoff 1.10 (ein Akzent): die fruehere `color(_:)`-Funktion (sieben
/// eigene Farben pro PR-Art) ist entfallen — alle Icon-Badges teilen sich
/// jetzt `Color.deltiqOrange`, genau wie `PRBadge.kindIcon` es bereits tut.
/// Unterscheidung laeuft nur noch ueber Icon-Form + `shortLabel`.
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
        // Zeitformate (README 2.9) — Spiegelung von PRBadge.kindIcon.
        case .mostRounds:      "repeat.circle.fill"
        case .fastestTime:     "stopwatch.fill"
        }
    }

    /// Short label for chips + segmented picker — full label lives in PRBadge.
    ///
    /// DEL-218: lokalisiert. Vorher hartkodiertes Deutsch, was durch das
    /// Sichtbarmachen der Cardio-Kinds erst aufgefallen ist — "Distanz" und
    /// "Pace" waeren sonst neu an EN/TR-Nutzer gegangen. Explizite
    /// Key-Literale (keine rawValue-Interpolation), damit das
    /// dead_catalog-Audit sie ohne Sonderregel findet.
    static func shortLabel(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .estimated1RM:    String(localized: "trophy.kind.short.estimated1RM", bundle: .module)
        case .heaviestWeight:  String(localized: "trophy.kind.short.heaviestWeight", bundle: .module)
        case .bestSet:         String(localized: "trophy.kind.short.bestSet", bundle: .module)
        case .maxReps:         String(localized: "trophy.kind.short.maxReps", bundle: .module)
        case .maxHoldSeconds:  String(localized: "trophy.kind.short.maxHoldSeconds", bundle: .module)
        case .longestDistance: String(localized: "trophy.kind.short.longestDistance", bundle: .module)
        case .fastestPace:     String(localized: "trophy.kind.short.fastestPace", bundle: .module)
        // Zeitformate (README 2.9) — dieselben Keys wie PRBadge.kindLabel.
        case .mostRounds:      String(localized: "pr.kind.mostRounds", bundle: .module)
        case .fastestTime:     String(localized: "pr.kind.fastestTime", bundle: .module)
        }
    }

    /// Y-axis label for the per-kind chart.
    ///
    /// DEL-218: lokalisiert (siehe `shortLabel`). Die Gewichts-Einheit steht
    /// weiterhin fest auf kg, weil PR-Werte in kg persistiert sind — die
    /// lbs-Umrechnung ist ein eigenes, groesseres Thema und betrifft die
    /// gesamte Anzeige-Schicht, nicht nur diesen Chart.
    static func yAxisLabel(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .estimated1RM, .heaviestWeight: return String(localized: "trophy.axis.weight", bundle: .module)
        case .bestSet:                       return String(localized: "trophy.axis.volume", bundle: .module)
        case .maxReps:                       return String(localized: "trophy.axis.reps", bundle: .module)
        case .maxHoldSeconds:                return String(localized: "trophy.axis.seconds", bundle: .module)
        case .longestDistance:               return String(localized: "trophy.axis.distance", bundle: .module)
        case .fastestPace:                   return String(localized: "trophy.axis.pace", bundle: .module)
        // Zeitformate (README 2.9).
        case .mostRounds:                    return String(localized: "trophy.axis.rounds", bundle: .module)
        case .fastestTime:                   return String(localized: "trophy.axis.seconds", bundle: .module)
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
