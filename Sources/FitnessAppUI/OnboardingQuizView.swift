#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-090: Smart Onboarding Quiz. Fuenf kompakte Fragen (Goal, Experience,
/// preferredDays, Environment, Equipment) → `PlanMatchmaker` ranked die 19
/// Templates → Result-Screen praesentiert den Top-Match + Liste der
/// Alternativen.
///
/// Der Caller (OnboardingView Step 3) gibt das vor-ausgewaehlte
/// Environment (aus dem Profile-Setup) mit; der Quiz bietet es als
/// Default an, der User kann es noch korrigieren.
@available(iOS 17.0, macOS 14.0, *)
public struct OnboardingQuizView: View {

    /// Pre-Selection fuers Environment aus dem Profile-Step.
    public let preselectedEnvironment: EnvironmentType
    /// Callback wenn der User einen Plan ausgewaehlt hat. Liefert das
    /// Template — Caller oeffnet danach den DayPicker fuer die Wochentage.
    public let onPlanSelected: (ProgramTemplate) -> Void
    public let onCancel: () -> Void

    @State private var step: QuizStep = .goal
    @State private var goal: GoalType = .hypertrophy
    @State private var experience: ExperienceLevel = .intermediate
    @State private var preferredDays: Int = 3
    @State private var environment: EnvironmentType
    /// README 2.19: fehlte bisher komplett - `QuizAnswers` wurde ohne
    /// `equipmentPreferences` gebaut, der DEL-170-Filter lief im Onboarding
    /// also immer leer.
    @State private var equipmentPreferences: Set<Equipment> = []

    public init(
        preselectedEnvironment: EnvironmentType,
        preselectedGoal: GoalType? = nil,
        onPlanSelected: @escaping (ProgramTemplate) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.preselectedEnvironment = preselectedEnvironment
        self.onPlanSelected = onPlanSelected
        self.onCancel = onCancel
        self._environment = State(initialValue: preselectedEnvironment)
        // DEL-207: Trainingsziel aus dem Coaching-Step vorbelegen — der
        // User hat es gerade erst gewählt; der Quiz soll nicht wieder bei
        // "Muskelaufbau" starten, wenn "Abnehmen" angegeben wurde. Die
        // Frage bleibt sichtbar (Korrektur möglich), nur der Startwert
        // ist informiert statt hardcoded.
        if let preselectedGoal {
            self._goal = State(initialValue: preselectedGoal)
        }
    }

    enum QuizStep: Int, CaseIterable {
        case goal, experience, days, environment, equipment, result
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider()
                Group {
                    switch step {
                    case .goal:        goalStep
                    case .experience:  experienceStep
                    case .days:        daysStep
                    case .environment: environmentStep
                    case .equipment:   equipmentStep
                    case .result:      resultStep
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)
                Divider()
                navigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(Text("quiz.title", bundle: .module))
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

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(QuizStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.deltiqOrange : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: Goal

    private var goalStep: some View {
        quizQuestion(
            title: String(localized: "quiz.goal.title", bundle: .module),
            subtitle: String(localized: "quiz.goal.subtitle", bundle: .module)
        ) {
            ForEach(GoalType.allCases, id: \.self) { g in
                quizOption(
                    label: String(localized: g.localizedName),
                    icon: g.symbol,
                    isSelected: goal == g
                ) {
                    goal = g
                }
            }
        }
    }

    // MARK: - Step 2: Experience

    private var experienceStep: some View {
        quizQuestion(
            title: String(localized: "quiz.experience.title", bundle: .module),
            subtitle: String(localized: "quiz.experience.subtitle", bundle: .module)
        ) {
            ForEach(ExperienceLevel.allCases, id: \.self) { e in
                quizOption(
                    label: String(localized: e.localizedName),
                    icon: e.symbol,
                    isSelected: experience == e
                ) {
                    experience = e
                }
            }
        }
    }

    // MARK: - Step 3: Days

    private var daysStep: some View {
        quizQuestion(
            title: String(localized: "quiz.days.title", bundle: .module),
            subtitle: String(localized: "quiz.days.subtitle", bundle: .module)
        ) {
            ForEach([2, 3, 4, 5, 6], id: \.self) { d in
                quizOption(
                    label: String(format: String(localized: "quiz.days.option", bundle: .module), d),
                    icon: d <= 3 ? "calendar" : "calendar.badge.clock",
                    isSelected: preferredDays == d
                ) {
                    preferredDays = d
                }
            }
        }
    }

    // MARK: - Step 4: Environment

    private var environmentStep: some View {
        quizQuestion(
            title: String(localized: "quiz.environment.title", bundle: .module),
            subtitle: String(localized: "quiz.environment.subtitle", bundle: .module)
        ) {
            ForEach(EnvironmentType.allCases, id: \.self) { env in
                quizOption(
                    label: envLabel(env),
                    icon: envIcon(env),
                    isSelected: environment == env
                ) {
                    environment = env
                }
            }
        }
    }

    // DEL-120: Quiz-spezifische Env-Labels (laenger + descriptive als die
    // generischen environment.*-Keys, weil im Quiz-Kontext der Subtext
    // wichtig ist — "Home-Gym (Kurzhanteln)" statt nur "Home-Gym").
    private func envLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return String(localized: "quiz.environment.gym",         bundle: .module)
        case .homeGym:     return String(localized: "quiz.environment.homeGym",     bundle: .module)
        case .noEquipment: return String(localized: "quiz.environment.noEquipment", bundle: .module)
        }
    }

    private func envIcon(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "building.2.fill"
        case .homeGym:     return "house.fill"
        case .noEquipment: return "figure.run"
        }
    }

    // MARK: - Step 5: Equipment

    /// README 2.19: dieselbe Frage, die `QuizAnswers.equipmentPreferences`
    /// seit DEL-170 erwartet und die dieser Quiz nie gestellt hat - der
    /// Equipment-Filter in `PlanMatchmaker` lief dadurch immer leer.
    private var equipmentStep: some View {
        quizQuestion(
            title: String(localized: "quiz.equipment.title", bundle: .module),
            subtitle: String(localized: "quiz.equipment.subtitle", bundle: .module)
        ) {
            ForEach(Equipment.allCases, id: \.self) { equip in
                FilterToggleRow(
                    label: String(localized: equip.localizedName),
                    isOn: Binding(
                        get: { equipmentPreferences.contains(equip) },
                        set: { newValue in
                            if newValue { equipmentPreferences.insert(equip) }
                            else        { equipmentPreferences.remove(equip) }
                        }
                    )
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Step 6: Result

    private var rankedPlans: [ProgramTemplate] {
        let answers = QuizAnswers(
            goal: goal,
            experience: experience,
            preferredDays: preferredDays,
            environment: environment,
            equipmentPreferences: equipmentPreferences
        )
        return PlanMatchmaker.rankPlans(for: answers, templates: ProgramTemplates.all)
    }

    private var resultStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let plans = rankedPlans
                if let top = plans.first {
                    topMatchCard(top)
                }
                if plans.count > 1 {
                    Text("quiz.result.alternatives", bundle: .module)
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(Array(plans.dropFirst())) { plan in
                        alternativeRow(plan)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func topMatchCard(_ plan: ProgramTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.deltiqOrange)
                Text("quiz.result.topMatch", bundle: .module).deltiqLabel()
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plan.iconSystemName)
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.deltiqOrange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    // DEL-122: lokalisiert via ProgramTemplate+DisplayName
                    // Extensions statt rohem deutschen Raw-Field.
                    Text(plan.displayName)
                        .font(.title3.weight(.bold))
                    Text(plan.displayTagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plan.displayFocus)
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.deltiqOrange.opacity(0.18))
                        .foregroundStyle(Color.deltiqOrange)
                        .clipShape(Capsule())
                }
            }
            Text(plan.displayDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                onPlanSelected(plan)
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                    Text("quiz.result.choose", bundle: .module)
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.deltiqOrange.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .innerLightStroke(cornerRadius: 16, opacity: 0.08)
    }

    private func alternativeRow(_ plan: ProgramTemplate) -> some View {
        Button {
            onPlanSelected(plan)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: plan.iconSystemName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(plan.displayTagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step != .goal {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("common.back", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if step != .result {
                Button {
                    goToNextStep()
                } label: {
                    Label {
                        Text(step == .equipment ? "quiz.title" : "quiz.nav.next",
                             bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func goToNextStep() {
        guard let next = QuizStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func goToPreviousStep() {
        guard let prev = QuizStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    // MARK: - Reusable Question UI

    @ViewBuilder
    private func quizQuestion<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder options: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    options()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func quizOption(
        label: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : Color.deltiqOrange)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.deltiqOrange : Color.deltiqOrange.opacity(0.12))
                    )
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
