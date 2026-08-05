#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Daily water-intake tracker. Target = `weight × 35 ml` from the most recent
/// measurement (falls back to profile goal-weight, then to a 70-kg default).
/// Quick-add buttons insert `WaterEntry` rows; today's list shows entries with
/// a per-row delete button (no more List, so no more swipe-to-delete).
@available(iOS 17.0, macOS 14.0, *)
public struct WaterTrackerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @Query private var profiles: [UserBodyProfile]

    /// All entries (chronologically reverse) — view filters down to "today" client-side.
    /// SwiftData's #Predicate doesn't currently support Calendar.startOfDay-style cutoffs
    /// reliably, so a small in-memory filter is more robust.
    @Query(sort: \WaterEntry.date, order: .reverse)
    private var allEntries: [WaterEntry]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: Eyebrow zeigt den unmittelbaren Elternscreen
            // (Rechner), nicht den Tab (Mehr) - das entspricht "der Kontext, aus
            // dem der Screen kommt" praeziser als der Tab-Name.
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "water.title", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    // Explizites `menu:`-Label statt bare trailing closure -
                    // sonst muss der Compiler zwischen den beiden
                    // DeltiqHeaderAction-Initializern per Typ-Inferenz
                    // entscheiden, was bei einem View-liefernden Closure-Body
                    // unnoetig fragil waere.
                    DeltiqHeaderAction(systemImage: "ellipsis", menu: {
                        Button(role: .destructive) {
                            deleteTodayEntries()
                        } label: {
                            Text("water.resetToday", bundle: .module)
                        }
                        .disabled(todayEntries.isEmpty)
                    })
                ]
            )

            VStack(alignment: .leading, spacing: 18) {
                heroCard
                quickAddCard
                if !todayEntries.isEmpty {
                    todayEntriesSection
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Sections

    private var heroCard: some View {
        DeltiqCard {
            VStack(spacing: 12) {
                progressRing
                if progress >= 1.0 {
                    Label {
                        Text("water.goalReached", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                    }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(String(format: String(localized: "water.remainingToGoal", bundle: .module), targetMl - todayMl))
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .monospacedDigit()
                }
                Text(String(format: String(localized: "water.heroFooter", bundle: .module), targetSourceLabel))
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 6)
                .foregroundStyle(Color.Deltiq.fill)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Handoff 2.3: Fortschritt in Akzent-Orange statt Cyan; "erledigt"
                // (Ziel erreicht) bleibt Gruen (1.7: Gruen nur fuer diesen Fall).
                // Explizites LinearGradient statt Color.green.gradient (AnyGradient) -
                // die beiden Ternary-Zweige muessen denselben konkreten Typ haben wie
                // Color.Deltiq.primaryGradient.
                .foregroundStyle(
                    progress >= 1.0
                        ? LinearGradient(
                            colors: [Color.Deltiq.success, Color.Deltiq.success.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : Color.Deltiq.primaryGradient
                )
                .animation(.easeInOut(duration: 0.4), value: progress)
            VStack(spacing: 2) {
                Text("\(todayMl)")
                    .font(.system(size: 26, weight: .heavy))
                    .fitnessNumberStyle()
                    .contentTransition(.numericText())
                Text(String(format: String(localized: "water.ofTotal", bundle: .module), targetMl))
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(width: 180, height: 180)
    }

    private var quickAddCard: some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "water.quickAdd.section", bundle: .module).uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.deltiqOrange)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        quickAddButton(amount: 125,  label: "+125 ml", systemImage: "drop")
                        quickAddButton(amount: 250,  label: "+250 ml", systemImage: "drop.fill")
                    }
                    HStack(spacing: 8) {
                        quickAddButton(amount: 500,  label: "+500 ml", systemImage: "cup.and.saucer.fill")
                        quickAddButton(amount: 1000, label: "+1 L",    systemImage: "waterbottle.fill")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quickAddButton(amount: Int, label: String, systemImage: String) -> some View {
        Button {
            addEntry(amount: amount)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.deltiqOrange.opacity(0.15))
            .foregroundStyle(Color.deltiqOrange)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Ersetzt das bisherige `.onDelete`-Swipe (List-exklusiv, funktioniert
    /// nicht mehr ausserhalb einer List) durch einen expliziten Loesch-Knopf
    /// pro Zeile — nebenbei entdeckungsfreundlicher als eine versteckte
    /// Swipe-Geste.
    private var todayEntriesSection: some View {
        DeltiqSection(String(localized: "water.todaySection.title", bundle: .module).uppercased()) {
            ForEach(Array(todayEntries.enumerated()), id: \.offset) { index, entry in
                waterEntryRow(entry, showsDivider: index < todayEntries.count - 1)
            }
        }
    }

    private func waterEntryRow(_ entry: WaterEntry, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .deltiqAccentIcon()
                Text("\(entry.amountMl) ml")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .fitnessNumberStyle()
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Button {
                    delete(entry)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.Deltiq.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    // MARK: Derived

    private var todayEntries: [WaterEntry] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.date >= startOfToday }
    }

    private var todayMl: Int {
        todayEntries.reduce(0) { $0 + $1.amountMl }
    }

    /// Daily target — delegates the math to `NutritionCalculations.dailyWaterTargetMl`
    /// (Core, widget-shareable). Reference weight falls through measurement →
    /// goal-weight → 70 kg default.
    private var targetMl: Int {
        NutritionCalculations.dailyWaterTargetMl(weightKg: referenceWeightKg)
    }

    private var referenceWeightKg: Double {
        if let measured = measurements.first?.weightKg, measured > 0 { return measured }
        if let goal = profiles.first?.goalWeightKg, goal > 0 { return goal }
        return 70.0
    }

    private var targetSourceLabel: String {
        // DEL-128: i18n der drei Quellen-Strings — vorher inline DE, was
        // im EN/TR-Mode als "Kaynak: letzte Messung" mit gemischten Sprachen
        // ausgegeben wurde (User-Smoke-Test-Befund).
        if measurements.first?.weightKg ?? 0 > 0 {
            return String(localized: "water.source.lastMeasurement", bundle: .module)
        }
        if profiles.first?.goalWeightKg ?? 0 > 0 {
            return String(localized: "water.source.goalWeight", bundle: .module)
        }
        let template = String(localized: "water.source.defaultFormat", bundle: .module)
        return template.replacingOccurrences(of: "%lld", with: "70")
    }

    private var progress: Double {
        targetMl > 0 ? min(Double(todayMl) / Double(targetMl), 1.0) : 0.0
    }

    // MARK: Actions

    private func addEntry(amount: Int) {
        let entry = WaterEntry(date: Date(), amountMl: amount)
        modelContext.insert(entry)
        reloadWaterWidget()
    }

    private func delete(_ entry: WaterEntry) {
        modelContext.delete(entry)
        reloadWaterWidget()
    }

    private func deleteTodayEntries() {
        for entry in todayEntries {
            modelContext.delete(entry)
        }
        reloadWaterWidget()
    }

    /// DEL-216: Stoesst den Timeline-Refresh des Home-Screen-Wasser-Widgets
    /// an, damit der Ring sofort den neuen Stand zeigt. Umgekehrt (Widget-
    /// Intent → App) ist kein Refresh noetig: die @Query laedt beim
    /// naechsten App-Foreground ohnehin frisch aus dem geteilten Store.
    private func reloadWaterWidget() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.waterWidgetKind)
        #endif
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        WaterTrackerView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}
#endif
#endif
