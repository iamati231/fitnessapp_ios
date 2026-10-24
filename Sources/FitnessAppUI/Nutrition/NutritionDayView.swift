#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppAI

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

    /// OFF-01: `true`, sobald an mindestens einer Position mindestens ein
    /// Naehrwert unbekannt ist — dann sind die Tagessummen lueckenhaft und
    /// die UI sagt das (statt eine zu kleine Zahl als Tatsache zu zeigen).
    public static func hasUnknownNutrients(meals: [MealEntry]) -> Bool {
        meals.contains { meal in meal.items.contains { $0.nutrientsSnapshot.partiallyKnown } }
    }

    public static func dailyTotal(meals: [MealEntry]) -> NutrientValues {
        NutrientValues.sum(meals.flatMap { $0.items.map(\.nutrientsSnapshot) })
    }
}

/// Task F: pure gating for the optional AI insight section — visible exactly
/// when the local AI is `.available` AND the selected day has at least one
/// meal (Brief). Pulled out as a free function (no SwiftUI/SwiftData) so the
/// exact condition can be unit-tested without instantiating the view.
@available(iOS 17.0, macOS 14.0, *)
enum NutritionInsightVisibility {
    static func isVisible(availability: NutritionAIAvailability, hasMeals: Bool) -> Bool {
        availability == .available && hasMeals
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
    // Task F: explicit UI locale instead of NutritionAIService's `.current`
    // default, same reasoning as AddMealView (Task E review, M2).
    @Environment(\.locale) private var locale

    @Query private var profiles: [UserBodyProfile]

    /// Alle Mahlzeiten (chronologisch absteigend) — die View filtert auf den
    /// ausgewaehlten Tag client-seitig herunter. Gleiches Prinzip wie
    /// `WaterTrackerView.allEntries`/`todayEntries`.
    @Query(sort: \MealEntry.date, order: .reverse)
    private var allMeals: [MealEntry]

    /// Bugfix (writing-block.md Punkt 6): fuer `resolvedMealItemName` — ein
    /// katalogbasierter Mahlzeit-Eintrag muss seinen Namen per aktueller
    /// `FoodCatalogEntry` (locale-abhaengig), nicht per eingefrorenem
    /// `nameSnapshot` zeigen.
    @Query(sort: \FoodCatalogEntry.catalogID)
    private var catalogEntries: [FoodCatalogEntry]

    @State private var selectedDate: Date = Date()
    @State private var showingAddMeal = false
    @State private var showingGoals = false
    @State private var editingMeal: MealEntry?
    /// Bugfix (writing-block.md 4.3, "Datum direkt auswaehlen"): die Pfeile
    /// decken nur +/-1 Tag ab - umstaendlich, wenn mehrere Tage uebersprungen
    /// werden sollen. Tippen auf das Datum oeffnet diesen Sheet.
    @State private var showingDatePicker = false

    // Task F: optional local AI coaching text. `nil` = not (yet) shown, either
    // still generating or the last attempt failed — the rest of the screen
    // (totals, goals, meal list) never depends on any of this.
    @State private var insightText: String?
    @State private var isGeneratingInsight = false

    /// main-navigation Plan, 2026-10-22, Task 1: seit diesem Tab-Root-Einsatz
    /// braucht der Screen zwei Modi, analog zu `MeasurementView.isEditMode`
    /// (Tab-Root -> kein Zurueck-Chevron, der sonst nichts taete). `true`
    /// wird vom Ernaehrungs-Tab-Root in `RootView.MainTabView`
    /// (`NutritionDayView(isTabRoot: true)`) gesetzt — der fruehere
    /// Dashboard-Push wurde in Task 2 durch einen Tab-Wechsel
    /// (`navigation.selectedTab = .nutrition`) ersetzt. `false` bleibt der
    /// Default fuer jedes andere Embedding, aktuell nur die Previews unten.
    private let isTabRoot: Bool

    public init(isTabRoot: Bool = false) {
        self.isTabRoot = isTabRoot
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                // main-navigation Plan, 2026-10-22, Task 1: Ernaehrung ist
                // jetzt ein eigener Tab, kein Calculators-Unterpunkt mehr -
                // die Eyebrow muss das eigene Tab-Label zeigen, nicht
                // "Rechner" (selbe Konvention wie CalculatorsView, deren
                // Eyebrow ebenfalls der eigene Tab-Name ist).
                eyebrow: String(localized: "tab.nutrition", bundle: .module).uppercased(),
                title: String(localized: "nutrition.day.title", bundle: .module),
                onBack: isTabRoot ? nil : { dismiss() },
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
                if showsInsightSection {
                    insightSection
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
        // Fix-Runde 1 (Finding 1): als Tab-Root ueberlebt dieser Screen
        // TabView-Selektionswechsel (siehe `isTabRoot`-Doku oben) -
        // `selectedDate` wurde daher nie auf "heute" zurueckgesetzt, wenn
        // der User zu einem frueheren Tag navigiert, den Tab wechselt und
        // zurueckkehrt (Spec: "Standarddatum: heute"). `.onAppear` feuert
        // bei jedem Tab-(Wieder-)Eintritt erneut — anders als bei einem
        // Sheet oder einem gepushten Child —, daher NUR hier gated auf
        // `isTabRoot`, nicht bei jedem Embedding (z.B. nicht beim
        // Dashboard-Push, falls der je zurueckkaeme).
        .onAppear {
            if isTabRoot {
                selectedDate = Date()
            }
        }
        // Task F: re-generates only when the underlying facts actually
        // change (not on every re-render) — `.task(id:)` also cancels any
        // in-flight generation for the previous id first, so there's never
        // more than one concurrent request from this screen.
        .task(id: insightContext) {
            await loadInsight()
        }
        .sheet(isPresented: $showingAddMeal) {
            AddMealView(date: selectedDate)
        }
        .sheet(isPresented: $showingGoals) {
            NutritionGoalsView()
        }
        .sheet(item: $editingMeal) { meal in
            AddMealView(editing: meal)
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
    }

    /// Bugfix (writing-block.md 4.3): `.graphical` DatePicker, dismissed
    /// explizit ueber "Fertig" statt sofort beim ersten Tag-Tap - gleiches
    /// Bestaetigungs-Prinzip wie jeder andere Editor in diesem Designsystem
    /// (kein stiller Auto-Dismiss). `selectedDate` ist dieselbe Quelle, die
    /// die Pfeile (`changeDay`) schon verwenden - bereits erfasste Mahlzeiten
    /// werden rein ueber dieses eine Binding gefiltert (`filteredMeals`
    /// unten), nie dupliziert oder umgeschrieben.
    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                String(localized: "summary.date", bundle: .module),
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("summary.date", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingDatePicker = false
                    } label: {
                        Text("common.done", bundle: .module)
                    }
                }
            }
        }
        .presentationDetents([.medium])
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

                Button {
                    showingDatePicker = true
                } label: {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)

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
                // OFF-01: Die Tagessumme ist nur vollstaendig, wenn jeder
                // einzelne Wert bekannt ist. Sonst sagen wir das hier
                // ausdruecklich, statt eine zu kleine Zahl als Tatsache
                // hinzustellen.
                if total.partiallyKnown || NutritionDayAggregator.hasUnknownNutrients(meals: mealsForSelectedDate) {
                    Text("nutrition.day.total.incomplete", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// OFF-01: Unbekannte Werte erscheinen als „-" (ueber
    /// `NutritionDisplay.unknownValue`), nie als 0.
    private func nutrientRow(_ label: String, value: KnownValue, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(NutritionDisplay.text(value, unit: unit))
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
                // OFF-01: mindestens ein Ziel-Fortschritt ist unbekannt, weil
                // die Tagessumme dieser Dimension unvollstaendig ist.
                if rows.contains(where: { $0.current.isUnknown }) {
                    Text("nutrition.day.total.incomplete", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
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
                    // OFF-01: unbekannte Tagessumme → "– / 150 g", kein
                    // Fortschrittsbalken (er wuerde 0 % suggerieren).
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

    /// Task F: optional local coaching/analysis text. Never rendered unless
    /// `showsInsightSection` is true (Brief: AI available AND day has >=1
    /// meal) — while generation is pending or failed, this just shows
    /// nothing but the (already-visible, because `showsInsightSection` is
    /// already true) section header, never an invented number.
    private var insightSection: some View {
        DeltiqSection(String(localized: "nutrition.day.insight.header", bundle: .module).uppercased()) {
            VStack(alignment: .leading, spacing: 6) {
                if isGeneratingInsight && insightText == nil {
                    ProgressView()
                } else if let insightText {
                    Text(insightText)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                }
                // Mandatory, visible labeling (Brief): every AI-generated
                // text must carry this — never unlabeled AI text next to the
                // deterministic numbers above.
                Text("nutrition.day.insight.disclaimer", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
                            // writing-block.md Punkt 6 ("Lebensmittelname
                            // folgt nicht der aktuellen App-Sprache"): dies
                            // ist die Tagesuebersicht - genau die Stelle, an
                            // der ein vor Wochen in einer anderen Sprache
                            // protokolliertes, katalogbasiertes Lebensmittel
                            // bisher den eingefrorenen `nameSnapshot` zeigte.
                            Text(resolvedMealItemName(nameSnapshot: item.nameSnapshot, catalogID: item.catalogID, catalogEntries: catalogEntries))
                                .font(.system(size: 15))
                                .foregroundStyle(Color.primary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(NutritionDisplay.text(mealTotal(meal).kcal, unit: "kcal"))
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
                // Audit-Fund (Geraetetest): ohne contentShape war nur der
                // Icon-/Namens-Bereich links tappbar, nicht der Spacer/
                // kcal-Bereich rechts — derselbe Fund wie beim Dashboard-
                // Nutrition-Tile, siehe dortigen Kommentar.
                .contentShape(Rectangle())
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

    // MARK: Task F — optional AI insight

    private var insightGenerator: NutritionInsightGenerator {
        // I2: `locale` passed to both the service (availability check) AND
        // the generator itself (the explicit language directive in its
        // instructions) — see `NutritionInsightGenerator`'s doc comment.
        NutritionInsightGenerator(service: NutritionAIService(locale: locale), locale: locale)
    }

    private var showsInsightSection: Bool {
        NutritionInsightVisibility.isVisible(
            availability: insightGenerator.availability(),
            hasMeals: !mealsForSelectedDate.isEmpty
        )
    }

    /// Identifies "the facts the insight is about" — `.task(id:)` re-runs
    /// `loadInsight()` only when one of these actually changes (new day,
    /// a meal added/edited/removed, or a goal changed), never on every
    /// unrelated re-render.
    private struct InsightContext: Equatable {
        let day: Date
        let total: NutrientValues
        let calorieGoal: Int?
        let proteinGoal: Double?
        let carbGoal: Double?
        let fatGoal: Double?
    }

    private var insightContext: InsightContext {
        let profile = profiles.first
        return InsightContext(
            day: Calendar.current.startOfDay(for: selectedDate),
            total: dailyTotal,
            calorieGoal: profile?.dailyCalorieGoalKcal,
            proteinGoal: profile?.dailyProteinGoalG,
            carbGoal: profile?.dailyCarbGoalG,
            fatGoal: profile?.dailyFatGoalG
        )
    }

    /// Computes the deterministic percent-of-goal/remaining fact for one
    /// nutrient via the shared `NutritionCalculations.goalProgress` (same
    /// formula as `GoalRow.fraction` above) and hands it to the AI prompt as
    /// a plain pre-computed number — the model never calculates this itself.
    /// `nil` whenever the goal itself is `nil`/not set.
    private func insightGoalProgress(current currentValue: KnownValue, goal: Double?) -> NutritionInsightInput.GoalProgress? {
        // OFF-01: ohne bekannte Tagessumme keine Prozent-/Restaussage an die KI.
        guard let current = currentValue.value,
              let goal,
              let progress = NutritionCalculations.goalProgress(current: current, goal: goal) else { return nil }
        return NutritionInsightInput.GoalProgress(percent: progress.percent, remaining: progress.remaining)
    }

    /// Minimal context only (Brief: "nur die fuer DIESE Analyse noetigen
    /// Werte") — the day's total plus whichever goals are actually set, never
    /// the full meal history.
    private func loadInsight() async {
        insightText = nil
        guard showsInsightSection else { return }
        let context = insightContext
        let input = NutritionInsightInput(
            totalKcal: context.total.kcal.value,
            totalProteinG: context.total.proteinG.value,
            totalCarbsG: context.total.carbsG.value,
            totalFatG: context.total.fatG.value,
            calorieGoalKcal: context.calorieGoal,
            proteinGoalG: context.proteinGoal,
            carbGoalG: context.carbGoal,
            fatGoalG: context.fatGoal,
            calorieGoalProgress: insightGoalProgress(current: context.total.kcal, goal: context.calorieGoal.map(Double.init)),
            proteinGoalProgress: insightGoalProgress(current: context.total.proteinG, goal: context.proteinGoal),
            carbGoalProgress: insightGoalProgress(current: context.total.carbsG, goal: context.carbGoal),
            fatGoalProgress: insightGoalProgress(current: context.total.fatG, goal: context.fatGoal)
        )
        isGeneratingInsight = true
        // `.unavailable` can't happen here (just checked by `showsInsightSection`
        // above), and any other failure (e.g. guardrail refusal) just leaves
        // `insightText` nil — the rest of the screen is unaffected either way.
        let result = try? await insightGenerator.generateInsight(for: input)
        // M2 fix: `.task(id:)` cancels this task when the user navigates to a
        // different day while generation is still in flight, but a cancelled
        // task's own code keeps running unless it checks for that itself — a
        // stale completion must never clear the spinner or write text for
        // what is by then the wrong day.
        guard !Task.isCancelled else { return }
        isGeneratingInsight = false
        insightText = result
    }

    private struct GoalRow {
        let label: String
        /// OFF-01: `.unknown`, sobald die Tagessumme dieser Dimension nicht
        /// vollstaendig ist.
        let current: KnownValue
        let goal: Double
        let unit: String

        // Shared with the AI insight prompt's percent/remaining facts — see
        // `NutritionCalculations.GoalProgress`'s doc comment.
        var fraction: Double {
            guard let current = current.value else { return 0 }
            return NutritionCalculations.goalProgress(current: current, goal: goal)?.fraction ?? 0
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
