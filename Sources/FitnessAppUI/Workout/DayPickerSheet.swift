#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-088: Half-Sheet, das vor der Plan-Instanziierung erscheint und den
/// User exakt `requiredDayCount` Wochentage auswaehlen laesst. UI ist
/// Apple-Calendar-konform (1=So, 2=Mo, ..., 7=Sa), zeigt aber den
/// User-Locale-Wochenstart (Mo-first in DE).
@available(iOS 17.0, macOS 14.0, *)
public struct DayPickerSheet: View {

    /// Anzahl der Tage, die der Plan voraussetzt. Submit-Button ist disabled
    /// bis exakt diese Anzahl angekreuzt ist.
    public let requiredDayCount: Int
    /// Display-Name des Plans fuers Header-Title.
    public let planName: String
    /// Callback bei Submit. Uebergibt die Apple-Calendar-Wochentage
    /// (sortiert Mo→So).
    public let onConfirm: ([Int]) -> Void
    public let onCancel: () -> Void

    /// Pre-Selection — Caller kann z.B. die Defaults vom Instantiator
    /// uebergeben, sodass der User direkt ein vorbereitetes Set sieht und
    /// nur bei Bedarf umkonfiguriert.
    public let initialSelection: [Int]

    @State private var selected: Set<Int>

    public init(
        requiredDayCount: Int,
        planName: String,
        initialSelection: [Int] = [],
        onConfirm: @escaping ([Int]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.requiredDayCount = requiredDayCount
        self.planName = planName
        self.initialSelection = initialSelection
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // Default = initialSelection (falls befuellt) oder leer.
        self._selected = State(initialValue: Set(initialSelection))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    dayGrid
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(Text("dayPicker.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(planName)
                .font(.title2.weight(.semibold))
            Text(String(format: String(localized: "dayPicker.prompt", bundle: .module), requiredDayCount))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(selected.count) von \(requiredDayCount) ausgewählt")
                .font(.caption.monospacedDigit())
                .foregroundStyle(selected.count == requiredDayCount ? Color.deltiqOrange : .secondary)
        }
    }

    /// Wochentage Mo–So in User-Locale-Reihenfolge.
    /// Apple-Calendar-Index: 1=So, 2=Mo, ..., 7=Sa. Wir rendern Mo→So
    /// (europaeische Konvention), unabhaengig vom System-Locale.
    private var dayGrid: some View {
        let weekdayLabels: [(weekday: Int, label: String, short: String)] = [
            (2, "Montag",     "Mo"),
            (3, "Dienstag",   "Di"),
            (4, "Mittwoch",   "Mi"),
            (5, "Donnerstag", "Do"),
            (6, "Freitag",    "Fr"),
            (7, "Samstag",    "Sa"),
            (1, "Sonntag",    "So")
        ]
        return VStack(spacing: 8) {
            ForEach(weekdayLabels, id: \.weekday) { entry in
                dayRow(weekday: entry.weekday, label: entry.label, short: entry.short)
            }
        }
    }

    private func dayRow(weekday: Int, label: String, short: String) -> some View {
        let isSelected = selected.contains(weekday)
        return Button {
            toggle(weekday)
        } label: {
            HStack(spacing: 12) {
                Text(short)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && selected.count >= requiredDayCount)
        .opacity(!isSelected && selected.count >= requiredDayCount ? 0.4 : 1.0)
    }

    private func toggle(_ weekday: Int) {
        if selected.contains(weekday) {
            selected.remove(weekday)
        } else {
            // Strikte Cap auf `requiredDayCount` — neue Auswahl ueber dem
            // Limit wird im Button ohnehin disabled. Defensive nochmal hier.
            guard selected.count < requiredDayCount else { return }
            selected.insert(weekday)
        }
    }

    private var actionButton: some View {
        Button {
            // Mo→So sortieren beim Submit.
            let sorted = selected.sorted(by: weekdayLessThan)
            onConfirm(sorted)
        } label: {
            HStack {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                Text("dayPicker.startPlan", bundle: .module)
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                (selected.count == requiredDayCount ? Color.deltiqOrange : Color.secondary.opacity(0.3))
                    .gradient
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(selected.count != requiredDayCount)
    }

    /// Mo<Di<...<So (Apple-Index 2,3,4,5,6,7,1).
    private func weekdayLessThan(_ a: Int, _ b: Int) -> Bool {
        let weightA = a == 1 ? 8 : a
        let weightB = b == 1 ? 8 : b
        return weightA < weightB
    }
}
#endif
