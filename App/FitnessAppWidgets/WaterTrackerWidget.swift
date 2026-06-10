import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import FitnessAppCore
import FitnessAppData

// DEL-216: Interaktives Wasser-Widget (iOS 17 AppIntent-Buttons).
//
// Datenfluss:
//   * Lesen: TimelineProvider oeffnet den App-Group-Store read-only-artig
//     (SharedStore.widgetContainer()) und aggregiert die heutigen
//     WaterEntry-Rows + das Tagesziel (gleiche Quelle wie WaterTrackerView:
//     letzte Messung → Zielgewicht → 70-kg-Default via NutritionCalculations).
//   * Schreiben: LogWaterIntent laeuft im Extension-Prozess, inserted einen
//     WaterEntry in denselben Store und speichert. WidgetKit laedt die
//     Timeline nach einem Intent automatisch neu.
//   * Store fehlt (App nach Update noch nie gestartet, oder Entitlement
//     fehlt): Provider liefert `storeAvailable=false`, das Widget zeigt
//     einen Oeffne-die-App-Hinweis und der Intent ist ein No-op — das
//     Widget legt NIE selbst einen (leeren) Store an, sonst wuerde die
//     einmalige Store-Migration der App ausgetrickst (siehe SharedStore).

// MARK: - AppIntent

/// Loggt eine feste Wassermenge per Widget-Tap — ohne die App zu oeffnen.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser loggen"
    static var description = IntentDescription("Fügt der heutigen Wasserbilanz eine Menge hinzu.")

    @Parameter(title: "Menge (ml)")
    var amountMl: Int

    init() {}

    init(amountMl: Int) {
        self.amountMl = amountMl
    }

    func perform() async throws -> some IntentResult {
        guard let container = SharedStore.widgetContainer() else {
            // Kein Group-Store → still aussteigen; das Widget rendert den
            // "App oeffnen"-Hinweis, der Button ist nur defensiv erreichbar.
            return .result()
        }
        let context = ModelContext(container)
        context.insert(WaterEntry(date: Date(), amountMl: amountMl))
        try context.save()
        return .result()
    }
}

// MARK: - Timeline

struct WaterWidgetEntry: TimelineEntry {
    let date: Date
    let todayMl: Int
    let targetMl: Int
    let storeAvailable: Bool
}

struct WaterTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterWidgetEntry {
        WaterWidgetEntry(date: Date(), todayMl: 1250, targetMl: 2800, storeAvailable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Naechster geplanter Refresh: Mitternacht, damit der Ring den Tag
        // wechselt, auch wenn weder App noch Intent angefasst werden.
        // Intent-Taps und App-seitige reloadTimelines-Calls kommen on top.
        let startOfToday = Calendar.current.startOfDay(for: entry.date)
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? entry.date.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func loadEntry() -> WaterWidgetEntry {
        guard let container = SharedStore.widgetContainer() else {
            return WaterWidgetEntry(date: Date(), todayMl: 0, targetMl: 0, storeAvailable: false)
        }
        let context = ModelContext(container)
        let startOfToday = Calendar.current.startOfDay(for: Date())

        let entryDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= startOfToday }
        )
        let todayMl = ((try? context.fetch(entryDescriptor)) ?? [])
            .reduce(0) { $0 + $1.amountMl }

        // Referenzgewicht wie im WaterTrackerView: Messung → Zielgewicht → 70 kg.
        var weightKg = 70.0
        var measurementDescriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        measurementDescriptor.fetchLimit = 1
        if let measured = try? context.fetch(measurementDescriptor).first?.weightKg, measured > 0 {
            weightKg = measured
        } else if let goal = try? context.fetch(FetchDescriptor<UserBodyProfile>()).first?.goalWeightKg,
                  goal > 0 {
            weightKg = goal
        }

        return WaterWidgetEntry(
            date: Date(),
            todayMl: todayMl,
            targetMl: NutritionCalculations.dailyWaterTargetMl(weightKg: weightKg),
            storeAvailable: true
        )
    }
}

// MARK: - Views

struct WaterTrackerWidgetView: View {
    var entry: WaterWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var progress: Double {
        entry.targetMl > 0 ? min(Double(entry.todayMl) / Double(entry.targetMl), 1.0) : 0.0
    }

    var body: some View {
        if !entry.storeAvailable {
            unavailableView
        } else if family == .systemMedium {
            mediumLayout
        } else {
            smallLayout
        }
    }

    /// Group-Store existiert noch nicht — die App muss nach dem Update
    /// einmal gestartet werden, damit die Store-Migration laeuft.
    private var unavailableView: some View {
        VStack(spacing: 6) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
            Text("App einmal öffnen, um das Widget zu aktivieren.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var smallLayout: some View {
        VStack(spacing: 8) {
            progressRing(size: 72, lineWidth: 8)
            logButton(amountMl: 250, label: "+250 ml")
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            progressRing(size: 96, lineWidth: 10)
            VStack(alignment: .leading, spacing: 6) {
                Text("Wasser heute")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                logButton(amountMl: 250, label: "+250 ml")
                logButton(amountMl: 500, label: "+500 ml")
                logButton(amountMl: 1000, label: "+1 L")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func progressRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .foregroundStyle(.gray.opacity(0.18))
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(progress >= 1.0 ? Color.green : Color.cyan)
            VStack(spacing: 0) {
                Text("\(entry.todayMl)")
                    .font(.system(size: size * 0.22, weight: .bold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("/ \(entry.targetMl) ml")
                    .font(.system(size: size * 0.11))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
    }

    private func logButton(amountMl: Int, label: String) -> some View {
        Button(intent: LogWaterIntent(amountMl: amountMl)) {
            Label {
                Text(label)
                    .font(.caption.weight(.semibold))
            } icon: {
                Image(systemName: "drop.fill")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .tint(.cyan)
        .buttonStyle(.bordered)
    }
}

// MARK: - Widget

struct WaterTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SharedStore.waterWidgetKind,
            provider: WaterTrackerProvider()
        ) { entry in
            WaterTrackerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wasser-Tracker")
        .description("Heutige Wasseraufnahme — direkt vom Homescreen loggen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
