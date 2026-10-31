#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Phase 4.1: Grundgerüst des Meal Planners. Zeigt Datumsnavigation und
/// Platzhalter-Sektionen für alle MealTypes. Keine Generator-Logik oder
/// SwiftData-Operationen in Phase 4.1 — folgen in späteren Phasen.
@available(iOS 17.0, macOS 14.0, *)
public struct MealPlannerView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.nutrition", bundle: .module).uppercased(),
                title: String(localized: "nutrition.mealPlanner.title", bundle: .module),
                onBack: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dateNavCard
                    ForEach(MealType.allCases, id: \.self) { type in
                        mealTypeSection(type)
                    }
                }
                .deltiqScreen()
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Date Navigation

    private var dateNavCard: some View {
        DeltiqCard {
            HStack {
                Button {
                    changeDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.back", bundle: .module))

                Spacer()

                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Spacer()

                Button {
                    changeDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Meal Type Sections

    private func mealTypeSection(_ type: MealType) -> some View {
        DeltiqSection(String(localized: String.LocalizationValue(type.localizationKey), bundle: .module).uppercased()) {
            HStack {
                Text("nutrition.mealPlanner.empty.placeholder", bundle: .module)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
        }
    }

    // MARK: - Actions

    private func changeDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        selectedDate = newDate
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mahlzeitenplan") {
    let container = try! ModelContainer(
        for: Schema(AppSchema.types),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        MealPlannerView()
    }
    .modelContainer(container)
    .environment(AppNavigation())
}
#endif
#endif
