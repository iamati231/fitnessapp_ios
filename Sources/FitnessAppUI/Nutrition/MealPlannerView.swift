#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Phase 4.2: Mahlzeitenplan mit echten Rezeptkarten und Tagesübersicht.
/// Laedt `DailyMealPlan` fuer das gewaehlte Datum aus SwiftData (kein
/// Auto-Generieren, kein Auto-Speichern — read-only); zeigt Nährwerte
/// aus `RecipeNutritionCalculator` gegen `UserBodyProfile`-Ziele.
///
/// OFF-01-konform: unbekannte oder fehlende Naehrwerte werden als "–"
/// angezeigt, niemals als 0.
@available(iOS 17.0, macOS 14.0, *)
public struct MealPlannerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    @State private var selectedDate: Date = Date()

    @Query private var allPlans: [DailyMealPlan]
    @Query private var profiles: [UserBodyProfile]

    // Static catalogs — `static let`, tatsächliche Daten einmalig geladen.
    private let recipeCatalog: [Recipe] = RecipeCatalogData.all
    private let foodCatalog: [FoodCatalogItem] = FoodCatalogData.all

    public init() {}

    // MARK: - Derived state

    private var userProfile: UserBodyProfile? { profiles.first }

    private var planForSelectedDate: DailyMealPlan? {
        let normalized = Calendar.current.startOfDay(for: selectedDate)
        return allPlans.first { $0.date == normalized }
    }

    private func assignments(for type: MealType) -> [PlannedMealAssignment] {
        planForSelectedDate?.assignments.filter { $0.mealType == type } ?? []
    }

    private func recipe(for assignment: PlannedMealAssignment) -> Recipe? {
        recipeCatalog.first { $0.id == assignment.recipeID }
    }

    private func nutrients(for assignment: PlannedMealAssignment) -> NutrientValues? {
        guard let r = recipe(for: assignment) else { return nil }
        if case .success(let v) = RecipeNutritionCalculator.nutrients(for: r, catalog: foodCatalog, portionMultiplier: assignment.portionMultiplier) {
            return v
        }
        return nil
    }

    /// Summiert alle Zuweisungen des Tages. `nil` wenn kein Plan vorhanden.
    /// `hasUnknownOrMissing` ist `true` wenn mindestens eine Zuweisung kein
    /// Rezept im Katalog hat oder ein Nährwert `unknown` ist.
    private var planTotals: (nutrients: NutrientValues, hasUnknownOrMissing: Bool)? {
        guard let plan = planForSelectedDate, !plan.assignments.isEmpty else { return nil }
        var values: [NutrientValues] = []
        var hasIssue = false
        for assignment in plan.assignments {
            guard let r = recipe(for: assignment) else { hasIssue = true; continue }
            switch RecipeNutritionCalculator.nutrients(for: r, catalog: foodCatalog, portionMultiplier: assignment.portionMultiplier) {
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
                title: String(localized: "nutrition.mealPlanner.title", bundle: .module),
                onBack: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dateNavCard
                    if let (totals, hasUnknown) = planTotals {
                        dayOverviewSection(totals: totals, hasUnknown: hasUnknown)
                    }
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

    // MARK: - Day Overview

    /// Tagesübersicht: Nährwerte aller geplanten Rezepte, optional mit Zielen.
    /// Gleiches Muster wie `goalsProgressSection` in NutritionDayView.
    @ViewBuilder
    private func dayOverviewSection(totals: NutrientValues, hasUnknown: Bool) -> some View {
        let profile = userProfile
        let rows = profile.map { goalRows(for: $0, total: totals) } ?? []
        DeltiqSection(String(localized: "nutrition.mealPlanner.overview.title", bundle: .module).uppercased()) {
            if rows.isEmpty {
                // Kein Profil mit Zielen → einfache Wertezeilen
                overviewNutrientRow(String(localized: "nutrition.goals.calorie.label", bundle: .module), value: totals.kcal, unit: "kcal")
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                overviewNutrientRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: totals.proteinG, unit: "g")
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                overviewNutrientRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: totals.carbsG, unit: "g")
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                overviewNutrientRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: totals.fatG, unit: "g")
            } else {
                // Ziele vorhanden → Fortschrittsbalken
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    goalProgressRow(row, showsDivider: index < rows.count - 1)
                }
            }
            if hasUnknown {
                Text("nutrition.day.total.incomplete", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private func overviewNutrientRow(_ label: String, value: KnownValue, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(NutritionDisplay.text(value, unit: unit))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Goal Progress (analog NutritionDayView.GoalRow)

    private struct GoalRow {
        let label: String
        let current: KnownValue
        let goal: Double
        let unit: String
        var fraction: Double {
            guard let current = current.value else { return 0 }
            return NutritionCalculations.goalProgress(current: current, goal: goal)?.fraction ?? 0
        }
    }

    private func goalRows(for profile: UserBodyProfile, total: NutrientValues) -> [GoalRow] {
        var rows: [GoalRow] = []
        if let g = profile.dailyCalorieGoalKcal {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.calorie.label", bundle: .module), current: total.kcal, goal: Double(g), unit: "kcal"))
        }
        if let g = profile.dailyProteinGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.protein.label", bundle: .module), current: total.proteinG, goal: g, unit: "g"))
        }
        if let g = profile.dailyCarbGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.carbs.label", bundle: .module), current: total.carbsG, goal: g, unit: "g"))
        }
        if let g = profile.dailyFatGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.fat.label", bundle: .module), current: total.fatG, goal: g, unit: "g"))
        }
        return rows
    }

    private func goalProgressRow(_ row: GoalRow, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.label)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    if let current = row.current.value {
                        Text("\(current.truncated(to: 0).formattedTwoDecimals) / \(row.goal.truncated(to: 0).formattedTwoDecimals) \(row.unit)")
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                    } else {
                        Text("\(NutritionDisplay.unknownValue) / \(row.goal.truncated(to: 0).formattedTwoDecimals) \(row.unit)")
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                    }
                }
                if row.current.value != nil {
                    ProgressView(value: row.fraction)
                        .tint(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Meal Type Sections

    @ViewBuilder
    private func mealTypeSection(_ type: MealType) -> some View {
        let typeAssignments = assignments(for: type)
        DeltiqSection(String(localized: String.LocalizationValue(type.localizationKey), bundle: .module).uppercased()) {
            if typeAssignments.isEmpty {
                HStack {
                    Text("nutrition.mealPlanner.empty.placeholder", bundle: .module)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
            } else {
                ForEach(Array(typeAssignments.enumerated()), id: \.offset) { index, assignment in
                    recipeCard(for: assignment, showsDivider: index < typeAssignments.count - 1)
                }
            }
        }
    }

    // MARK: - Recipe Card

    private func recipeCard(for assignment: PlannedMealAssignment, showsDivider: Bool) -> some View {
        let r = recipe(for: assignment)
        let n = nutrients(for: assignment)
        return Button {
            navigation.nutritionPath.append(MealPlannerRoute.recipeDetail(
                recipeID: assignment.recipeID,
                mealType: assignment.mealType,
                portionMultiplier: assignment.portionMultiplier,
                date: Calendar.current.startOfDay(for: selectedDate)
            ))
        } label: {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let r {
                        Text(String(localized: String.LocalizationValue(r.nameKey), bundle: .module))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    } else {
                        Text("nutrition.mealPlanner.recipe.unknown", bundle: .module)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                    Spacer()
                    if let n {
                        Text(NutritionDisplay.text(n.kcal, unit: "kcal"))
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                    }
                }
                if let n {
                    HStack(spacing: 16) {
                        macroText(String(localized: "nutrition.goals.protein.label", bundle: .module), value: n.proteinG)
                        macroText(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: n.carbsG)
                        macroText(String(localized: "nutrition.goals.fat.label", bundle: .module), value: n.fatG)
                    }
                }
                if assignment.portionMultiplier != 1.0 {
                    Text("×\(assignment.portionMultiplier.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
        }
        .buttonStyle(.plain)
    }

    private func macroText(_ label: String, value: KnownValue) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(Color.Deltiq.textSecondary)
            Text(NutritionDisplay.text(value, unit: "g"))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
        .font(.caption)
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
