#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Phase 5.1: Wochenübersicht im Deltiq Meal Planner.
/// Zeigt Montag bis Sonntag mit kompakten Nährwert-Karten.
/// Keine neuen SwiftData-Modelle, keine automatische Plangenerierung.
///
/// OFF-01: Unbekannte Nährwerte bleiben unbekannt (–), nie als 0.
/// Tage ohne Plan werden als "nicht geplant" dargestellt, nicht als 0 kcal.
@available(iOS 17.0, macOS 14.0, *)
public struct WeekPlannerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    @Query private var allPlans: [DailyMealPlan]

    @State private var weekStart: Date = WeekPlannerView.currentWeekMonday()

    private let recipeCatalog: [Recipe] = RecipeCatalogData.all
    private let foodCatalog: [FoodCatalogItem] = FoodCatalogData.all

    public init() {}

    // MARK: - Week helpers

    /// Montag der aktuellen Woche — DST-sicher via Kalender-Komponenten.
    static func currentWeekMonday(calendar: Calendar = .current) -> Date {
        mondayOfWeek(containing: Date(), calendar: calendar)
    }

    /// Montag der Woche, die `date` enthält. Explizit firstWeekday=2 (Montag).
    static func mondayOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(weekStart, equalTo: Self.currentWeekMonday(), toGranularity: .weekOfYear)
    }

    // MARK: - Nutrient calculation

    /// Nährwert-Summe für einen Tag. `nil` wenn kein Plan vorhanden.
    private func planTotals(for day: Date) -> (nutrients: NutrientValues, hasUnknown: Bool)? {
        let normalized = Calendar.current.startOfDay(for: day)
        guard let plan = allPlans.first(where: { $0.date == normalized }),
              !plan.assignments.isEmpty else { return nil }
        var values: [NutrientValues] = []
        var hasIssue = false
        for assignment in plan.assignments {
            guard let recipe = recipeCatalog.first(where: { $0.id == assignment.recipeID }) else {
                hasIssue = true; continue
            }
            switch RecipeNutritionCalculator.nutrients(for: recipe, catalog: foodCatalog, portionMultiplier: assignment.portionMultiplier) {
            case .success(let v): values.append(v)
            case .failure: hasIssue = true
            }
        }
        let total = NutrientValues.sum(values)
        return (total, hasIssue || total.partiallyKnown)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.nutrition", bundle: .module).uppercased(),
                title: String(localized: "mealPlanner.week.title", bundle: .module),
                onBack: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    weekNavCard
                    ForEach(weekDays, id: \.self) { day in
                        dayCard(for: day)
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

    // MARK: - Week navigation card

    private var weekNavCard: some View {
        DeltiqCard {
            HStack(spacing: 8) {
                Button {
                    weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("mealPlanner.week.prevWeek", bundle: .module))

                Spacer()

                VStack(spacing: 2) {
                    Text(weekRangeLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    if !isCurrentWeek {
                        Button {
                            weekStart = Self.currentWeekMonday()
                        } label: {
                            Text("mealPlanner.week.thisWeek", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(Color.deltiqOrange)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button {
                    weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("mealPlanner.week.nextWeek", bundle: .module))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var weekRangeLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let startStr = weekStart.formatted(.dateTime.day().month(.abbreviated))
        let endStr = end.formatted(.dateTime.day().month(.abbreviated))
        return "\(startStr) – \(endStr)"
    }

    // MARK: - Day card

    @ViewBuilder
    private func dayCard(for day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let totals = planTotals(for: day)

        Button {
            navigation.nutritionPath.append(MealPlannerRoute.plannerDay(day))
        } label: {
            DeltiqCard {
                HStack(alignment: .top, spacing: 12) {
                    // Left: weekday + date badge
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isToday ? Color.deltiqOrange : Color.Deltiq.textSecondary)
                            .textCase(.uppercase)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isToday ? Color.deltiqOrange : Color.primary)
                    }
                    .frame(width: 40)

                    // Divider
                    Rectangle()
                        .fill(isToday ? Color.deltiqOrange.opacity(0.5) : Color.Deltiq.divider)
                        .frame(width: 1)
                        .padding(.vertical, 2)

                    // Right: nutrients or no-plan label
                    if let (nutrients, hasUnknown) = totals {
                        VStack(alignment: .leading, spacing: 4) {
                            nutrientRow(
                                label: String(localized: "nutrition.goals.calorie.label", bundle: .module),
                                value: nutrients.kcal, unit: "kcal"
                            )
                            nutrientRow(
                                label: String(localized: "nutrition.goals.protein.label", bundle: .module),
                                value: nutrients.proteinG, unit: "g"
                            )
                            nutrientRow(
                                label: String(localized: "nutrition.goals.carbs.label", bundle: .module),
                                value: nutrients.carbsG, unit: "g"
                            )
                            nutrientRow(
                                label: String(localized: "nutrition.goals.fat.label", bundle: .module),
                                value: nutrients.fatG, unit: "g"
                            )
                            if hasUnknown {
                                Text("nutrition.day.total.incomplete", bundle: .module)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.Deltiq.textSecondary)
                            }
                        }
                    } else {
                        Text("mealPlanner.week.noplan", bundle: .module)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 2)
            }
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                        .strokeBorder(Color.deltiqOrange.opacity(0.4), lineWidth: 1.5)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    private func nutrientRow(label: String, value: KnownValue, unit: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(NutritionDisplay.text(value, unit: unit, decimals: 0))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .fitnessNumberStyle()
        }
    }
}
#endif
