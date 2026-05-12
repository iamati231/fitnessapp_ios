#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Daily water-intake tracker. Target = `weight × 35 ml` from the most recent
/// measurement (falls back to profile goal-weight, then to a 70-kg default).
/// Quick-add buttons insert `WaterEntry` rows; today's list shows entries with
/// swipe-to-delete.
@available(iOS 17.0, macOS 14.0, *)
public struct WaterTrackerView: View {

    @Environment(\.modelContext) private var modelContext

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
        List {
            heroSection
            quickAddSection
            todaySection
        }
        .navigationTitle("Wasser")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Heute zurücksetzen", role: .destructive) {
                        deleteTodayEntries()
                    }
                    .disabled(todayEntries.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: Sections

    private var heroSection: some View {
        Section {
            VStack(spacing: 12) {
                progressRing
                if progress >= 1.0 {
                    Label("Tagesziel erreicht", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(targetMl - todayMl) ml bis zum Ziel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } footer: {
            Text("Tagesziel = Gewicht × 35 ml. Quelle: \(targetSourceLabel).")
                .font(.footnote)
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 18)
                .foregroundStyle(.gray.opacity(0.18))
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(progress >= 1.0 ? Color.green.gradient : Color.cyan.gradient)
                .animation(.easeInOut(duration: 0.4), value: progress)
            VStack(spacing: 2) {
                Text("\(todayMl)")
                    .font(.system(size: 44, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text("ml von \(targetMl)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: 200, height: 200)
    }

    private var quickAddSection: some View {
        Section {
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
            .padding(.vertical, 4)
        } header: {
            Text("Schnell-Eintrag")
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
            .background(Color.cyan.opacity(0.15))
            .foregroundStyle(.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var todaySection: some View {
        Section {
            if todayEntries.isEmpty {
                Text("Trag deinen ersten Schluck mit den Buttons oben ein.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayEntries) { entry in
                    WaterEntryRow(entry: entry)
                }
                .onDelete(perform: deleteEntries)
            }
        } header: {
            HStack {
                Text("Heute")
                Spacer()
                if !todayEntries.isEmpty {
                    Text("\(todayEntries.count) Einträge")
                        .font(.caption)
                        .textCase(nil)
                        .foregroundStyle(.secondary)
                }
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
        if measurements.first?.weightKg ?? 0 > 0 { return "letzte Messung" }
        if profiles.first?.goalWeightKg ?? 0 > 0 { return "Profil-Zielgewicht" }
        return "Default 70 kg"
    }

    private var progress: Double {
        targetMl > 0 ? min(Double(todayMl) / Double(targetMl), 1.0) : 0.0
    }

    // MARK: Actions

    private func addEntry(amount: Int) {
        let entry = WaterEntry(date: Date(), amountMl: amount)
        modelContext.insert(entry)
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entries = todayEntries
        for offset in offsets {
            modelContext.delete(entries[offset])
        }
    }

    private func deleteTodayEntries() {
        for entry in todayEntries {
            modelContext.delete(entry)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct WaterEntryRow: View {
    let entry: WaterEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .foregroundStyle(.cyan)
            Text("\(entry.amountMl) ml")
                .monospacedDigit()
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
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
