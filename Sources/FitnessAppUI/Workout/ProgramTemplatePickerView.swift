#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Shown as a sheet from PlansListView when the user wants to start from a
/// program template instead of building a plan from scratch. Displays all
/// `ProgramTemplates.all` with name, tagline, focus, and day-count tiles.
/// Tapping a row instantiates the plan, dismisses the sheet, and pushes the
/// new plan onto the workout-tab navigation stack.
@available(iOS 17.0, macOS 14.0, *)
public struct ProgramTemplatePickerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    /// Lesen das User-Profil, um die Templates nach passendem
    /// Trainingsort vorzufiltern (DEL-012).
    @Query private var profiles: [UserBodyProfile]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // DEL-055: gruppiert per `focus` — z.B. "Hybrid & Athletik"
                // landet als eigene Section. Ordnung ueber die in
                // `ProgramTemplates.all` etablierte Display-Reihenfolge.
                ForEach(groupedTemplates, id: \.focus) { group in
                    Section {
                        ForEach(group.templates) { template in
                            // DEL-037: Tap oeffnet die Preview, kein direktes
                            // instantiate mehr. Erst nach "Plan uebernehmen"
                            // in der Preview wird die Tiefkopie erstellt.
                            NavigationLink {
                                TemplatePreviewView(template: template) {
                                    instantiate(template)
                                }
                            } label: {
                                ProgramRow(template: template)
                            }
                        }
                    } header: {
                        Text(group.focus)
                    }
                }

                Section {
                    EmptyView()
                } footer: {
                    Text("Gefiltert nach deinem Trainingsort (\(userEnvironmentLabel)). Im Profil anpassen, wenn du auch andere Plaene sehen willst.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Programm wählen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    /// DEL-055: Templates nach `focus` (Hybrid & Athletik / Kraft / Anfänger ...)
    /// gruppiert. Reihenfolge der Sections entspricht der ersten Position des
    /// jeweiligen Focus-Strings in `ProgramTemplates.all` — so bleibt die
    /// kuratierte Display-Reihenfolge aus dem Core erhalten.
    private var groupedTemplates: [(focus: String, templates: [ProgramTemplate])] {
        var ordered: [String] = []
        var bucket: [String: [ProgramTemplate]] = [:]
        for template in filteredTemplates {
            if bucket[template.focus] == nil { ordered.append(template.focus) }
            bucket[template.focus, default: []].append(template)
        }
        return ordered.map { ($0, bucket[$0] ?? []) }
    }

    /// Filtert nach `profile.environment`. Same Logik wie OnboardingView:
    ///   - gym: alle Templates
    ///   - homeGym: homeGym + noEquipment
    ///   - noEquipment: nur noEquipment
    /// Falls noch kein Profil existiert (sollte hier eigentlich nicht passieren
    /// — Profil ist Voraussetzung fuer MainTabView), fallen wir auf alle Plaene
    /// zurueck statt eine leere Liste zu zeigen.
    private var filteredTemplates: [ProgramTemplate] {
        guard let env = profiles.first?.environment else { return ProgramTemplates.all }
        return ProgramTemplates.all.filter { template in
            switch env {
            case .gym:         return true
            case .homeGym:     return template.targetEnvironment == .homeGym
                                     || template.targetEnvironment == .noEquipment
            case .noEquipment: return template.targetEnvironment == .noEquipment
            }
        }
    }

    private var userEnvironmentLabel: String {
        guard let env = profiles.first?.environment else { return "alle" }
        // LocalizedStringResource → String via String(localized:) — Text-Inter-
        // polation wuerde es direkt nehmen, aber wir bauen hier einen reinen
        // String fuer die Section-Footer-Interpolation.
        return String(localized: env.localizedName)
    }

    private func instantiate(_ template: ProgramTemplate) {
        let plan = ProgramInstantiator.instantiate(template, in: modelContext)
        dismiss()
        // Defer the navigation to the next runloop — gives the sheet's dismiss
        // animation time to start before the workout-stack mutation lands.
        // Without this small delay, the dismiss + navigationDestination(for:)
        // stack-update can race and the editor sometimes doesn't appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigation.workoutPath.append(plan)
        }
    }
}

// MARK: - Subview

@available(iOS 17.0, macOS 14.0, *)
private struct ProgramRow: View {
    let template: ProgramTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.blue.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.body.weight(.semibold))
                    Text("·")
                    Text(template.focus)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(template.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(template.descriptionText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - DEL-037 Template-Preview-View

/// Read-Only-Vorschau eines `ProgramTemplate` vor dem Uebernehmen in den
/// User-Bestand. Zeigt Tage + Uebungen, damit der User die Struktur
/// inspizieren kann; erst der "Plan uebernehmen"-Button startet die Tiefkopie.
///
/// DEL-056: jetzt `public`, damit `OnboardingView` die Preview wiederverwenden
/// kann. Button-Titel ist parametrisiert (`adoptButtonTitle`) — Onboarding
/// sagt "Diesen Plan waehlen", Picker sagt "Diesen Plan uebernehmen".
@available(iOS 17.0, macOS 14.0, *)
public struct TemplatePreviewView: View {
    public let template: ProgramTemplate
    /// Action, die getriggert wird wenn der User die Tiefkopie tatsaechlich
    /// erstellen will. Wird vom Parent injected, damit dort Insert,
    /// Navigation und Sheet-Dismiss orchestriert wird.
    public let onAdopt: () -> Void
    /// Anpassbarer Button-Titel.
    public let adoptButtonTitle: String

    public init(
        template: ProgramTemplate,
        adoptButtonTitle: String = "Diesen Plan übernehmen",
        onAdopt: @escaping () -> Void
    ) {
        self.template = template
        self.adoptButtonTitle = adoptButtonTitle
        self.onAdopt = onAdopt
    }

    public var body: some View {
        List {
            heroSection
            ForEach(orderedDays, id: \.weekday) { day in
                daySection(day)
            }
            adoptSection
        }
        .navigationTitle(template.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Subsections

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: template.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.focus)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text(template.tagline)
                            .font(.body.weight(.semibold))
                    }
                }
                Text(template.descriptionText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func daySection(_ day: DaySpec) -> some View {
        Section {
            if day.exercises.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.purple)
                    Text("Ruhetag")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { _, exercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.body.weight(.medium))
                        Text("\(exercise.sets) × \(exercise.repsMin)-\(exercise.repsMax) Wdh · \(exercise.restSeconds)s Pause")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack(spacing: 6) {
                Text(weekdayLabel(day.weekday))
                    .textCase(nil)
                Text("·").foregroundStyle(.tertiary)
                Text(day.name)
                    .textCase(nil)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var adoptSection: some View {
        Section {
            Button {
                onAdopt()
            } label: {
                HStack {
                    Spacer()
                    Label(adoptButtonTitle, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 6)
                .foregroundStyle(.white)
            }
            .listRowBackground(Color.deltiqOrange)
        } footer: {
            Text("Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar.")
                .font(.footnote)
        }
    }

    // MARK: Helpers

    /// DaySpec hat einen weekday-Int (1=So, 2=Mo, ..., 7=Sa). Wir sortieren
    /// Mon-first via PlanNavigator's existing Helper-Logik — DaySpec konformt
    /// nicht zum Protocol, also lokale Sortier-Variante.
    private var orderedDays: [DaySpec] {
        template.days.sorted { lhs, rhs in
            // Mo (2) zuerst, So (1) zuletzt — Mo-First-Convention.
            europeanWeekday(lhs.weekday) < europeanWeekday(rhs.weekday)
        }
    }

    private func europeanWeekday(_ apple: Int) -> Int {
        // 2=Mo→0, 3=Di→1, ..., 1=So→6
        apple == 1 ? 6 : apple - 2
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    ProgramTemplatePickerView()
        .modelContainer(PreviewSeed.maleProfileContainer)
        .environment(AppNavigation())
}
#endif
#endif
