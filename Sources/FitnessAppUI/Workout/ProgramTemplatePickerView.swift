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
                    Text(String(format: String(localized: "picker.plan.filterFootnote", bundle: .module), userEnvironmentLabel))
                        .font(.footnote)
                }
            }
            .navigationTitle(Text("picker.plan.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.cancel", bundle: .module)
                    }
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
        // DEL-116: Section-Key auf `displayFocus` umgestellt, damit die
        // Gruppierung auch in EN/TR die gleichen logischen Buckets bildet
        // (gleicher rohes `focus` → gleicher displayFocus → eine Section).
        for template in filteredTemplates {
            let focusKey = template.displayFocus
            if bucket[focusKey] == nil { ordered.append(focusKey) }
            bucket[focusKey, default: []].append(template)
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
        // DEL-170: User-Equipment vom Profil ziehen, damit Templates mit
        // `equipmentVariants` die passende Variante bekommen. Leer = Standard.
        let userEquipment = profiles.first?.equipmentPreferences ?? []
        let plan = ProgramInstantiator.instantiate(
            template,
            in: modelContext,
            userEquipment: userEquipment
        )
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
            // DEL-105: Brand-Akzent statt iOS-Standard-Blau.
            Image(systemName: template.iconSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.deltiqOrange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.displayName)
                        .font(.body.weight(.semibold))
                    Text("·")
                    Text(template.displayFocus)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(template.displayTagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(template.displayDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            // Nachtrag 6. August, abends (README 2.10/19b): dieser Screen
            // ist bewusst eine native Sheet-Liste (siehe Aufruf-Stelle oben)
            // - der `NavigationLink` dort bringt schon einen Chevron mit.
            // Dieser handgezeichnete duplizierte ihn.
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

    @Environment(\.dismiss) private var dismiss

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
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: geteilte View - wird sowohl als echter
            // Push aus ProgramTemplatePickerView (Gruppe A) als auch aus
            // OnboardingViews eigenem Sheet gerufen. Kein einzelner
            // "Herkunfts"-Tab moeglich, daher eine neutrale Eyebrow, die in
            // beiden Kontexten Sinn ergibt (User-Entscheidung).
            DeltiqHeader(
                eyebrow: String(localized: "picker.plan.title", bundle: .module).uppercased(),
                title: template.displayName,
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                heroCard
                ForEach(orderedDays, id: \.sequenceIndex) { day in
                    dayCard(day)
                }
                adoptButton
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
    }

    // MARK: Subsections

    private var heroCard: some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: template.iconSystemName)
                        .deltiqAccentIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.displayFocus)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.deltiqOrange)
                        Text(template.displayTagline)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }
                }
                Text(template.displayDescription)
                    .font(.callout)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
    }

    private func dayCard(_ day: DaySpec) -> some View {
        // DEL-088: Titel zeigt "Tag N · <Name>" (sequenceIndex statt
        // Wochentag — Tag wird erst beim Instantiieren auf einen Weekday
        // gemappt, siehe DayPickerSheet).
        //
        // README 2.10/19c-19d: Zeitformat-Tage haengen das Format + den
        // Deckel an denselben Titel an ("TAG 1 · CINDY · AMRAP · 20 MIN")
        // statt eine separate Kapsel zu bauen - `DeltiqSection` hat keinen
        // Slot dafuer, und der Titel ist schon derselbe Eyebrow-Stil.
        let dayLabel = String(format: String(localized: "plan.dayNumberLabel", bundle: .module), day.sequenceIndex)
        var titleParts = ["\(dayLabel) · \(day.displayName)"]
        if let format = day.timeFormat {
            titleParts.append(timedFormatDisplayName(format))
            if let cap = day.timeCapMinutes {
                titleParts.append("\(cap) " + String(localized: "unit.minutes.short", bundle: .module))
            }
        }
        return DeltiqSection(titleParts.joined(separator: " · ").uppercased()) {
            // DEL-088: Templates enthalten nur noch Trainings-Tage — der
            // Rest-Day-Branch ist obsolet, bleibt aber defensiv drin fuer
            // den hypothetischen Fall einer Migration-Luecke.
            if day.exercises.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(Color.deltiqOrange)
                    Text("Ruhetag")
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, exercise in
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            // DEL-118: lokalisierter Name via Library-Lookup
                            // (ExerciseSpec.name ist der deutsche Raw-String aus
                            // dem Template — wir resolven ihn ueber den Catalog-
                            // Key des Library-Eintrags).
                            Text(localizedExerciseName(exercise.name))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.primary)
                            // DEL-118: format-string via xcstrings statt
                            // hardcoded DE-Interpolation. README 2.10/19c-19d:
                            // Zeitformat-Tage zeigen nur noch das Ziel pro
                            // Runde statt Saetze × Wdh × Pause.
                            Text(detailLine(for: exercise, dayFormat: day.timeFormat))
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if index < day.exercises.count - 1 {
                            Rectangle()
                                .fill(Color.Deltiq.divider)
                                .frame(height: 1)
                        }
                    }
                }
                // README 2.10/19c-19d: ersetzt die (bei Zeitformaten
                // erfundene) Pausen-Angabe durch einen ehrlichen Fusshinweis.
                if let format = day.timeFormat {
                    timedWorkoutHintRow(String(localized: String.LocalizationValue(timedFormatHintKey(for: format)), bundle: .module))
                }
            }
        }
    }

    private var adoptButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onAdopt()
            } label: {
                Label(adoptButtonTitle, systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()

            Text("picker.plan.adoptFootnote", bundle: .module)
                .font(.footnote)
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    // MARK: Helpers

    /// DEL-088: Template-Tage sind ueber `sequenceIndex` 1...N geordnet.
    /// Vorher haben wir hier Mo-first nach Apple-Weekday sortiert — das ist
    /// jetzt obsolet, weil Templates keinen Wochentag mehr enthalten.
    private var orderedDays: [DaySpec] {
        template.days.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    /// DEL-118: ExerciseSpec.name ist der deutsche Raw-String aus dem
    /// Template-Source. Wenn er einen Library-Eintrag matched, holen wir
    /// dessen `localizationKey` und resolven via Catalog. Sonst Fallback
    /// auf den Raw-String (Custom-Plan-Strings ohne Library-Match).
    private func localizedExerciseName(_ name: String) -> String {
        if let entry = ExerciseLibraryData.all.first(where: { $0.name == name }),
           let key = entry.localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }

    /// README 2.9 Phase 6: `ExerciseSpec` hat kein eigenes `isTimeBased`-Feld
    /// - der `ProgramInstantiator` leitet das erst beim Materialisieren per
    /// Namens-Lookup gegen `ExerciseLibraryData` her (siehe `timeBasedNames`
    /// dort). Fuer die Vorschau, die noch vor der Instanziierung steht,
    /// machen wir denselben Lookup hier.
    private func isTimeBasedSpec(_ name: String) -> Bool {
        ExerciseLibraryData.all.first(where: { $0.name == name })?.isTimeBased ?? false
    }

    /// DEL-118: format-string fuer die Detail-Zeile (Saetze × Wdh × Pause)
    /// via xcstrings.
    ///
    /// README 2.10/19c-19d: Zeitformat-Tage (`dayFormat != nil`) zeigen
    /// stattdessen nur das Ziel pro Runde (`timedFormatCircuitLabel`,
    /// TimedWorkoutPlayerView.swift - dieselbe Fassung wie im Player und in
    /// WorkoutSummaryView, keine dritte Implementierung). Sätze × Wdh ×
    /// Pause ergeben bei einem AMRAP/EMOM/Auf-Zeit-Tag keinen Sinn: die Uhr
    /// entscheidet ueber Runden, eine feste Pause steht im Plan gar nicht.
    private func detailLine(for exercise: ExerciseSpec, dayFormat: WorkoutTimeFormat?) -> String {
        if let dayFormat {
            return timedFormatCircuitLabel(
                repsMin: exercise.repsMin, isTimeBased: isTimeBasedSpec(exercise.name),
                sets: exercise.sets, format: dayFormat
            )
        }
        if exercise.isCardio {
            return String(format: String(localized: "workout.detail.cardio", bundle: .module), exercise.restSeconds)
        }
        let repsText = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        // Templates haben keinen `isTimeBased`-Flag pro ExerciseSpec —
        // wir nutzen einheitlich die reps-Variante. Time-based Lifts in
        // Templates (z.B. Plank) tragen Sekunden im repsMin/Max-Feld.
        //
        // DEL-118-Nachtrag (README 2.10): manuelle .one/.other-Auswahl statt
        // eines einzelnen Format-Strings - sonst bleibt "Sätze" (DE) fuer
        // exercise.sets == 1 stehen, weil replacingOccurrences keine echte
        // Plural-Aufloesung ist (siehe PlanRow.pluralized fuer dasselbe Muster).
        let key = exercise.sets == 1 ? "workout.detail.reps.one" : "workout.detail.reps.other"
        let template = String(localized: String.LocalizationValue(key), bundle: .module)
        return template
            .replacingOccurrences(of: "%1$lld", with: "\(exercise.sets)")
            .replacingOccurrences(of: "%2$@",   with: repsText)
            .replacingOccurrences(of: "%3$lld", with: "\(exercise.restSeconds)")
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
