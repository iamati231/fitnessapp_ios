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
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate: Date
    @State private var replacingAssignment: PlannedMealAssignment? = nil
    @State private var removingAssignment: PlannedMealAssignment? = nil
    @State private var generationError: String? = nil
    @State private var regeneratingAssignment: PlannedMealAssignment? = nil
    @State private var showRegenerationError = false
    @State private var optimizationProposal: OptimizedPlanProposal? = nil
    @State private var isOptimizing = false
    @State private var showOptimizationProtectedAlert = false
    @State private var showOptimizationNoGoalsAlert = false

    @Query private var allPlans: [DailyMealPlan]
    @Query private var profiles: [UserBodyProfile]

    // Static catalogs — `static let`, tatsächliche Daten einmalig geladen.
    private let recipeCatalog: [Recipe] = RecipeCatalogData.all
    private let foodCatalog: [FoodCatalogItem] = FoodCatalogData.all

    public init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

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
                    weekOverviewButton
                    if planForSelectedDate == nil {
                        generatePlanCard
                    }
                    if let (totals, hasUnknown) = planTotals {
                        dayOverviewSection(totals: totals, hasUnknown: hasUnknown)
                    }
                    if planForSelectedDate != nil {
                        optimizeCard
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
        .sheet(item: $replacingAssignment) { assignment in
            RecipePickerView(
                mealType: assignment.mealType,
                currentRecipeID: assignment.recipeID,
                preferences: userProfile?.nutritionPreferences ?? UserNutritionPreferences(),
                onSelect: { newRecipe in
                    swapAssignment(assignment, to: newRecipe)
                }
            )
        }
        .confirmationDialog(
            String(localized: "mealPlanner.remove.confirm.title", bundle: .module),
            isPresented: Binding(
                get: { removingAssignment != nil },
                set: { if !$0 { removingAssignment = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "mealPlanner.remove.confirm.action", bundle: .module), role: .destructive) {
                if let a = removingAssignment { removeAssignment(a) }
            }
            Button(String(localized: "common.cancel", bundle: .module), role: .cancel) {}
        }
        .alert(
            String(localized: "mealPlanner.regenerate.noAlternative.title", bundle: .module),
            isPresented: $showRegenerationError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("mealPlanner.regenerate.noAlternative.message", bundle: .module)
        }
        .sheet(item: $optimizationProposal) { proposal in
            optimizationPreviewSheet(proposal)
        }
        .alert(
            String(localized: "mealPlanner.optimize.protected.title", bundle: .module),
            isPresented: $showOptimizationProtectedAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("mealPlanner.optimize.protected.message", bundle: .module)
        }
        .alert(
            String(localized: "mealPlanner.optimize.noGoals", bundle: .module),
            isPresented: $showOptimizationNoGoalsAlert
        ) {
            Button("OK", role: .cancel) {}
        }
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

    private var weekOverviewButton: some View {
        Button {
            navigation.nutritionPath.append(MealPlannerRoute.weekOverview)
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.deltiqOrange)
                Text("mealPlanner.week.button", bundle: .module)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.Deltiq.fill)
            .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
        }
        .buttonStyle(.plain)
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
        return VStack(alignment: .leading, spacing: 0) {
            // Tappable area: navigiert zur Rezeptdetailseite
            Button {
                navigation.nutritionPath.append(MealPlannerRoute.recipeDetail(
                    recipeID: assignment.recipeID,
                    mealType: assignment.mealType,
                    portionMultiplier: assignment.portionMultiplier,
                    date: Calendar.current.startOfDay(for: selectedDate)
                ))
            } label: {
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
                            macroText(String(localized: "nutrition.macro.protein.short", bundle: .module), value: n.proteinG)
                            macroText(String(localized: "nutrition.macro.carbs.short", bundle: .module), value: n.carbsG)
                            macroText(String(localized: "nutrition.macro.fat.short", bundle: .module), value: n.fatG)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Portions-Stepper: außerhalb des Navigations-Buttons
            portionStepper(for: assignment)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
        .overlay {
            if regeneratingAssignment === assignment {
                Color.Deltiq.background.opacity(0.8)
                    .overlay { ProgressView() }
            }
        }
        .contextMenu {
            Button {
                regenerateAssignment(assignment)
            } label: {
                Label(String(localized: "mealPlanner.action.regenerate", bundle: .module), systemImage: "sparkles")
            }
            Button {
                replacingAssignment = assignment
            } label: {
                Label(String(localized: "mealPlanner.action.swap", bundle: .module), systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                removingAssignment = assignment
            } label: {
                Label(String(localized: "mealPlanner.action.remove", bundle: .module), systemImage: "trash")
            }
        }
    }

    private func portionStepper(for assignment: PlannedMealAssignment) -> some View {
        HStack(spacing: 10) {
            Button {
                adjustPortion(assignment, by: -0.5)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.Deltiq.fill)
                    .clipShape(Circle())
                    .foregroundStyle(assignment.portionMultiplier <= 0.5 ? Color.Deltiq.textSecondary : Color.deltiqOrange)
            }
            .buttonStyle(.plain)
            .disabled(assignment.portionMultiplier <= 0.5)
            .accessibilityLabel(Text("mealPlanner.portion.decrease", bundle: .module))

            Text("×\(assignment.portionMultiplier.formatted(.number.precision(.fractionLength(0...1))))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.Deltiq.textSecondary)
                .frame(minWidth: 30)

            Button {
                adjustPortion(assignment, by: 0.5)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.Deltiq.fill)
                    .clipShape(Circle())
                    .foregroundStyle(assignment.portionMultiplier >= 5.0 ? Color.Deltiq.textSecondary : Color.deltiqOrange)
            }
            .buttonStyle(.plain)
            .disabled(assignment.portionMultiplier >= 5.0)
            .accessibilityLabel(Text("mealPlanner.portion.increase", bundle: .module))
        }
    }

    // MARK: - Edit Actions

    private func adjustPortion(_ assignment: PlannedMealAssignment, by delta: Double) {
        let clamped = min(max(assignment.portionMultiplier + delta, 0.5), 5.0)
        guard clamped != assignment.portionMultiplier else { return }
        assignment.portionMultiplier = clamped
        if let plan = assignment.plan { plan.isManuallyAdjusted = true }
        try? modelContext.save()
    }

    private func swapAssignment(_ assignment: PlannedMealAssignment, to newRecipe: Recipe) {
        assignment.recipeID = newRecipe.id
        assignment.portionMultiplier = 1.0
        if let plan = assignment.plan { plan.isManuallyAdjusted = true }
        try? modelContext.save()
    }

    private func removeAssignment(_ assignment: PlannedMealAssignment) {
        if let plan = assignment.plan { plan.isManuallyAdjusted = true }
        modelContext.delete(assignment)
        try? modelContext.save()
        removingAssignment = nil
    }

    private func regenerateAssignment(_ assignment: PlannedMealAssignment) {
        guard regeneratingAssignment == nil else { return }
        regeneratingAssignment = assignment
        Task { @MainActor in
            defer { regeneratingAssignment = nil }
            let prefs = userProfile?.nutritionPreferences ?? UserNutritionPreferences()
            let usedIDs = Set(planForSelectedDate?.assignments.map(\.recipeID) ?? [])
            guard let alternative = MealPlanGenerator.alternativeRecipe(
                for: assignment.mealType,
                excluding: assignment.recipeID,
                preferExcluding: usedIDs,
                from: recipeCatalog,
                preferences: prefs
            ) else {
                showRegenerationError = true
                return
            }
            assignment.recipeID = alternative.id
            assignment.portionMultiplier = 1.0
            if let plan = assignment.plan { plan.isManuallyAdjusted = true }
            try? modelContext.save()
        }
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

    // MARK: - Generate Plan

    private var generatePlanCard: some View {
        DeltiqCard {
            VStack(spacing: 10) {
                if let error = generationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    generatePlan()
                } label: {
                    Text("nutrition.mealPlanner.generate.button", bundle: .module)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.deltiqOrange)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func generatePlan() {
        generationError = nil
        let prefs = userProfile?.nutritionPreferences ?? UserNutritionPreferences()
        let result = MealPlanGenerator.generate(
            for: selectedDate,
            mealTypes: MealType.allCases,
            preferences: prefs,
            dailyCalorieGoalKcal: userProfile?.dailyCalorieGoalKcal,
            dailyProteinGoalG: userProfile?.dailyProteinGoalG,
            dailyCarbGoalG: userProfile?.dailyCarbGoalG,
            dailyFatGoalG: userProfile?.dailyFatGoalG,
            recentRecipeIDs: [], // shortcut: no recency tracking, upgrade in Phase 6
            recipeCatalog: recipeCatalog,
            foodCatalog: foodCatalog
        )
        switch result {
        case .success(let plan):
            let assignments = plan.assignments.map { a -> PlannedMealAssignment in
                let pa = PlannedMealAssignment(recipeID: a.recipeID, mealType: a.mealType, portionMultiplier: a.portionMultiplier)
                modelContext.insert(pa)
                return pa
            }
            try? DailyMealPlan.upsertGenerated(
                date: selectedDate,
                assignments: assignments,
                warning: plan.insufficientSelectionWarning,
                in: modelContext
            )
        case .failure:
            generationError = String(localized: "nutrition.mealPlanner.generate.noRecipe", bundle: .module)
        }
    }

    // MARK: - Optimize Plan

    private var optimizeCard: some View {
        DeltiqCard {
            Button {
                Task { await startOptimization() }
            } label: {
                if isOptimizing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("mealPlanner.optimize.button", bundle: .module)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.deltiqOrange)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .disabled(isOptimizing)
        }
    }

    @MainActor
    private func startOptimization() async {
        guard let plan = planForSelectedDate else { return }
        guard !plan.isManuallyAdjusted else {
            showOptimizationProtectedAlert = true
            return
        }
        let profile = userProfile
        guard profile?.dailyCalorieGoalKcal != nil
            || profile?.dailyProteinGoalG != nil
            || profile?.dailyCarbGoalG != nil
            || profile?.dailyFatGoalG != nil else {
            showOptimizationNoGoalsAlert = true
            return
        }
        isOptimizing = true
        defer { isOptimizing = false }
        let assignments = plan.assignments.map {
            (recipeID: $0.recipeID, mealType: $0.mealType, portionMultiplier: $0.portionMultiplier)
        }
        let prefs = profile?.nutritionPreferences ?? UserNutritionPreferences()
        let result = MealPlanOptimizer.optimize(
            assignments: assignments,
            calorieGoal: profile?.dailyCalorieGoalKcal,
            proteinGoal: profile?.dailyProteinGoalG,
            carbGoal: profile?.dailyCarbGoalG,
            fatGoal: profile?.dailyFatGoalG,
            recipeCatalog: recipeCatalog,
            foodCatalog: foodCatalog,
            preferences: prefs
        )
        if case .success(let proposal) = result {
            optimizationProposal = proposal
        }
    }

    private func applyOptimization(_ proposal: OptimizedPlanProposal) {
        guard let plan = planForSelectedDate else { return }
        for change in proposal.changes where change.hasChange {
            guard let assignment = plan.assignments.first(where: {
                $0.mealType == change.mealType && $0.recipeID == change.currentRecipeID
            }) else { continue }
            assignment.recipeID = change.proposedRecipeID
            assignment.portionMultiplier = change.proposedMultiplier
        }
        plan.isManuallyAdjusted = true
        try? modelContext.save()
        optimizationProposal = nil
    }

    @ViewBuilder
    private func optimizationPreviewSheet(_ proposal: OptimizedPlanProposal) -> some View {
        NavigationStack {
            List {
                if let warning = proposal.warning {
                    Section {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
                Section(String(localized: "mealPlanner.optimize.preview.before", bundle: .module)) {
                    nutrientPreviewRow("kcal", value: proposal.currentTotals.kcal, unit: "kcal")
                    nutrientPreviewRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: proposal.currentTotals.proteinG, unit: "g")
                    nutrientPreviewRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: proposal.currentTotals.carbsG, unit: "g")
                    nutrientPreviewRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: proposal.currentTotals.fatG, unit: "g")
                }
                Section(String(localized: "mealPlanner.optimize.preview.after", bundle: .module)) {
                    nutrientPreviewRow("kcal", value: proposal.proposedTotals.kcal, unit: "kcal")
                    nutrientPreviewRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: proposal.proposedTotals.proteinG, unit: "g")
                    nutrientPreviewRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: proposal.proposedTotals.carbsG, unit: "g")
                    nutrientPreviewRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: proposal.proposedTotals.fatG, unit: "g")
                }
                let changedSlots = proposal.changes.filter { $0.hasChange }
                if !changedSlots.isEmpty {
                    Section {
                        ForEach(changedSlots) { change in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: String.LocalizationValue(change.mealType.localizationKey), bundle: .module))
                                    .font(.caption)
                                    .foregroundStyle(Color.Deltiq.textSecondary)
                                HStack(spacing: 6) {
                                    Text("×\(change.currentMultiplier.formatted(.number.precision(.fractionLength(0...1))))")
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                    Text("×\(change.proposedMultiplier.formatted(.number.precision(.fractionLength(0...1))))")
                                        .bold()
                                    if change.recipeChanged {
                                        Spacer()
                                        Text("mealPlanner.optimize.swap.label", bundle: .module)
                                            .font(.caption2)
                                            .foregroundStyle(Color.deltiqOrange)
                                    }
                                }
                                .font(.system(size: 14))
                            }
                        }
                    }
                }
                if !proposal.hasChanges {
                    Section {
                        Text("mealPlanner.optimize.noChange", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(String(localized: "mealPlanner.optimize.preview.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .module)) {
                        optimizationProposal = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "mealPlanner.optimize.preview.confirm", bundle: .module)) {
                        applyOptimization(proposal)
                    }
                    .disabled(!proposal.hasChanges)
                }
            }
        }
    }

    private func nutrientPreviewRow(_ label: String, value: KnownValue, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(NutritionDisplay.text(value, unit: unit))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
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
