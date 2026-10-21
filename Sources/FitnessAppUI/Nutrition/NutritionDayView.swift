#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Task 8: reine, UI-unabhaengige Gruppierung/Summierung ueber bereits
/// geladene `[MealEntry]`. Synchron, kein `ModelContext`-Zugriff — der
/// Caller (`NutritionDayView`) liefert die Tages-Auswahl per `@Query` +
/// In-Memory-Filter, exakt das gleiche Prinzip wie
/// `WaterTrackerView.todayEntries` (siehe dortiger Kommentar zu
/// `Calendar.startOfDay` + `#Predicate`-Unzuverlaessigkeit).
@available(iOS 17.0, macOS 14.0, *)
public enum NutritionDayAggregator {
    public static func grouped(meals: [MealEntry]) -> [MealType: [MealEntry]] {
        Dictionary(grouping: meals, by: \.mealType)
    }

    public static func dailyTotal(meals: [MealEntry]) -> NutrientValues {
        NutrientValues.sum(meals.flatMap { $0.items.map(\.nutrientsSnapshot) })
    }
}

/// Task 8: Tagesuebersicht ueber alle erfassten Mahlzeiten eines Tages.
/// Datumsnavigation (ein Tag vor/zurueck), Sektionen pro `MealType` (nur
/// gerendert wenn sie Mahlzeiten enthaelt), Tagessumme, Fortschrittsbalken
/// NUR fuer tatsaechlich gesetzte Ziele aus `UserBodyProfile` (Task 5, vier
/// unabhaengige Felder) und ein Empty State fuer Tage ohne Eintraege.
///
/// Zusaetzlich (Controller-Ruling, siehe Plan-Ledger): ein Zahnrad-
/// Header-Action oeffnet `NutritionGoalsView` (Task 5) als Sheet — der
/// Screen hatte sonst in den 10 Plan-Tasks keinen Navigations-Einstieg.
///
/// Zusaetzlich (eigene Ergaenzung ueber den Brief hinaus): Tippen auf eine
/// Mahlzeit oeffnet `AddMealView(editing:)` (Task 7) als Sheet — Task 7
/// hat den Edit-Pfad komplett gebaut, aber nirgends verdrahtet. Dieser
/// Screen ist der einzige Ort im ganzen Plan, der einzelne `MealEntry`s
/// listet, also der einzig sinnvolle Ort fuer den Einstieg.
@available(iOS 17.0, macOS 14.0, *)
public struct NutritionDayView: View {

    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]

    /// Alle Mahlzeiten (chronologisch absteigend) — die View filtert auf den
    /// ausgewaehlten Tag client-seitig herunter. Gleiches Prinzip wie
    /// `WaterTrackerView.allEntries`/`todayEntries`.
    @Query(sort: \MealEntry.date, order: .reverse)
    private var allMeals: [MealEntry]

    @State private var selectedDate: Date = Date()
    @State private var showingAddMeal = false
    @State private var showingGoals = false
    @State private var editingMeal: MealEntry?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "nutrition.day.title", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    DeltiqHeaderAction(
                        systemImage: "plus",
                        accessibilityLabel: String(localized: "nutrition.day.addMeal.button", bundle: .module)
                    ) {
                        showingAddMeal = true
                    },
                    DeltiqHeaderAction(
                        systemImage: "gearshape",
                        accessibilityLabel: String(localized: "nutrition.day.goals.button", bundle: .module)
                    ) {
                        showingGoals = true
                    }
                ]
            )

            VStack(alignment: .leading, spacing: 18) {
                dateNavCard
                dayTotalCard
                if let profile = profiles.first {
                    goalsProgressSection(profile)
                }
                if mealsForSelectedDate.isEmpty {
                    emptyState
                } else {
                    mealSections
                }
            }
            .deltiqScreen()
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
        .sheet(isPresented: $showingAddMeal) {
            AddMealView(date: selectedDate)
        }
        .sheet(isPresented: $showingGoals) {
            NutritionGoalsView()
        }
        .sheet(item: $editingMeal) { meal in
            AddMealView(editing: meal)
        }
    }

    // MARK: Sections

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

    private var dayTotalCard: some View {
        let total = dailyTotal
        return DeltiqCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "nutrition.day.total.label", bundle: .module).uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.deltiqOrange)
                nutrientRow(String(localized: "nutrition.goals.calorie.label", bundle: .module), value: total.kcal, unit: "kcal")
                nutrientRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: total.proteinG, unit: "g")
                nutrientRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: total.carbsG, unit: "g")
                nutrientRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: total.fatG, unit: "g")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nutrientRow(_ label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text("\(value.truncated(to: 2).formattedTwoDecimals) \(unit)")
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
    }

    /// Nur gerenderte Ziele (Spec 7, "Tagesziele"): vier unabhaengige
    /// Conditionals statt eines All-oder-Nichts-Blocks — jedes
    /// `UserBodyProfile`-Zielfeld ist einzeln optional (Task 5).
    @ViewBuilder
    private func goalsProgressSection(_ profile: UserBodyProfile) -> some View {
        let total = dailyTotal
        let rows = goalRows(profile, total: total)
        if !rows.isEmpty {
            DeltiqSection(String(localized: "nutrition.goals.title", bundle: .module).uppercased()) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    goalProgressRow(row, showsDivider: index < rows.count - 1)
                }
            }
        }
    }

    private func goalProgressRow(_ row: GoalRow, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.label)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text("\(row.current.truncated(to: 0).formattedTwoDecimals) / \(row.goal.truncated(to: 0).formattedTwoDecimals) \(row.unit)")
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .fitnessNumberStyle()
                }
                ProgressView(value: row.fraction)
                    .tint(Color.deltiqOrange)
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

    @ViewBuilder
    private var emptyState: some View {
        DashboardEmptyState(
            icon: "fork.knife",
            title: "nutrition.day.empty.title",
            description: "nutrition.day.empty.message",
            ctaTitle: "nutrition.day.addMeal.button",
            ctaAction: { showingAddMeal = true }
        )
        .deltiqCardStyle()
    }

    /// Nur Sektionen fuer `MealType`s, die am ausgewaehlten Tag tatsaechlich
    /// Mahlzeiten haben (Spec: "nur rendern wenn sie Eintraege hat").
    private var mealSections: some View {
        ForEach(MealType.allCases, id: \.self) { type in
            if let meals = grouped[type], !meals.isEmpty {
                mealTypeSection(type, meals: meals)
            }
        }
    }

    private func mealTypeSection(_ type: MealType, meals: [MealEntry]) -> some View {
        DeltiqSection(String(localized: String.LocalizationValue(type.localizationKey), bundle: .module).uppercased()) {
            ForEach(Array(meals.enumerated()), id: \.element.persistentModelID) { index, meal in
                mealEntryRow(meal, showsDivider: index < meals.count - 1)
            }
        }
    }

    /// Tippen oeffnet den Edit-Pfad aus Task 7 (siehe Typ-Doku oben) — bisher
    /// der einzige Aufrufer von `AddMealView(editing:)` im ganzen Plan.
    private func mealEntryRow(_ meal: MealEntry, showsDivider: Bool) -> some View {
        Button {
            editingMeal = meal
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(meal.items.enumerated()), id: \.element.persistentModelID) { _, item in
                            Text(item.nameSnapshot)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.primary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(mealTotal(meal).kcal.truncated(to: 0).formattedTwoDecimals) kcal")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                        Text(meal.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textTertiary)
                    }
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
        .buttonStyle(.plain)
    }

    // MARK: Derived

    private var mealsForSelectedDate: [MealEntry] {
        let start = Calendar.current.startOfDay(for: selectedDate)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        return allMeals.filter { $0.date >= start && $0.date < end }
    }

    private var grouped: [MealType: [MealEntry]] {
        NutritionDayAggregator.grouped(meals: mealsForSelectedDate)
    }

    private var dailyTotal: NutrientValues {
        NutritionDayAggregator.dailyTotal(meals: mealsForSelectedDate)
    }

    private func mealTotal(_ meal: MealEntry) -> NutrientValues {
        NutritionDayAggregator.dailyTotal(meals: [meal])
    }

    private struct GoalRow {
        let label: String
        let current: Double
        let goal: Double
        let unit: String

        var fraction: Double {
            goal > 0 ? min(current / goal, 1.0) : 0
        }
    }

    private func goalRows(_ profile: UserBodyProfile, total: NutrientValues) -> [GoalRow] {
        var rows: [GoalRow] = []
        if let goal = profile.dailyCalorieGoalKcal {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.calorie.label", bundle: .module), current: total.kcal, goal: Double(goal), unit: "kcal"))
        }
        if let goal = profile.dailyProteinGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.protein.label", bundle: .module), current: total.proteinG, goal: goal, unit: "g"))
        }
        if let goal = profile.dailyCarbGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.carbs.label", bundle: .module), current: total.carbsG, goal: goal, unit: "g"))
        }
        if let goal = profile.dailyFatGoalG {
            rows.append(GoalRow(label: String(localized: "nutrition.goals.fat.label", bundle: .module), current: total.fatG, goal: goal, unit: "g"))
        }
        return rows
    }

    // MARK: Actions

    private func changeDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        selectedDate = newDate
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Mahlzeiten") {
    let container = try! ModelContainer(
        for: Schema(AppSchema.types),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    ctx.insert(UserBodyProfile(
        birthDate: Calendar.current.date(byAdding: .year, value: -32, to: Date()) ?? Date(),
        heightCm: 180,
        profile: .male,
        goalWeightKg: 78,
        environment: .gym
    ))
    let breakfast = MealEntry(date: Date(), mealType: .breakfast)
    ctx.insert(breakfast)
    ctx.insert(MealItem(catalogID: nil, nameSnapshot: "Haferflocken", quantity: 80, unit: .gram,
                         nutrients: NutrientValues(kcal: 300, proteinG: 10, carbsG: 50, fatG: 6), meal: breakfast))
    let lunch = MealEntry(date: Date(), mealType: .lunch)
    ctx.insert(lunch)
    ctx.insert(MealItem(catalogID: nil, nameSnapshot: "Haehnchenbrust", quantity: 150, unit: .gram,
                         nutrients: NutrientValues(kcal: 250, proteinG: 45, carbsG: 0, fatG: 5), meal: lunch))
    return NavigationStack {
        NutritionDayView()
    }
    .modelContainer(container)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Leerer Tag") {
    let container = try! ModelContainer(
        for: Schema(AppSchema.types),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        NutritionDayView()
    }
    .modelContainer(container)
}
#endif
#endif
