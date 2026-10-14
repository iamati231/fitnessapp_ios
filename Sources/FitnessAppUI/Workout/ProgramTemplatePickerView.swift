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
                                TemplatePreviewView(
                                    template: template,
                                    userEquipmentProfile: profiles.first?.equipmentProfile ?? UserEquipmentProfile()
                                ) {
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
        // Smart-Onboarding-Epic Phase 4: dasselbe Profil, das die Vorschau
        // gerade gezeigt hat (Punkt 6) — nie die grobe Legacy-Menge allein.
        let userEquipmentProfile = profiles.first?.equipmentProfile ?? UserEquipmentProfile()
        let plan = ProgramInstantiator.instantiate(
            template,
            in: modelContext,
            userEquipmentProfile: userEquipmentProfile
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
    /// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md
    /// Abschnitt 13): dasselbe `UserEquipmentProfile`, das der jeweilige
    /// Parent gleich darauf an `ProgramInstantiator.instantiate` reicht —
    /// damit `checkedVariant`/`orderedDays` IMMER dieselbe Variante (und
    /// denselben Equipment-Status) zeigen, die beim Adopt tatsaechlich
    /// gespeichert wird (Punkt 6). Default leer/unbekannt = Basis-Variante,
    /// Status `.unknown` fuer jede annotierte Uebung.
    public let userEquipmentProfile: UserEquipmentProfile

    @Environment(\.dismiss) private var dismiss

    public init(
        template: ProgramTemplate,
        adoptButtonTitle: String = "Diesen Plan übernehmen",
        userEquipmentProfile: UserEquipmentProfile = UserEquipmentProfile(),
        onAdopt: @escaping () -> Void
    ) {
        self.template = template
        self.adoptButtonTitle = adoptButtonTitle
        self.userEquipmentProfile = userEquipmentProfile
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
                equipmentStatusBanner
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

    /// Smart-Onboarding-Epic Phase 4: EINZIGE Variantenwahl fuer diese
    /// Vorschau — `ProgramInstantiator.instantiate` ruft bei Adopt dieselbe
    /// Funktion mit demselben Profil auf (Punkt 6).
    private var checkedVariant: CheckedPlanVariant {
        template.bestEquipmentCheckedVariant(against: userEquipmentProfile)
    }

    /// Punkt 5/7/8: zeigt den tatsaechlichen Pruefstatus der oben gewaehlten
    /// Variante transparent an — "Equipment passend" nur bei `.available`,
    /// eine Luecke (fehlend oder unbekannt) wird konkret benannt statt
    /// stillschweigend uebergangen oder durch eine andere Uebung ersetzt.
    @ViewBuilder
    private var equipmentStatusBanner: some View {
        switch checkedVariant.equipmentStatus {
        case .available:
            equipmentStatusRow(
                icon: "checkmark.circle.fill", tint: .green,
                title: String(localized: "picker.plan.equipment.available.title", bundle: .module),
                detail: nil
            )
        case let .unknown(gaps):
            equipmentStatusRow(
                icon: "questionmark.circle.fill", tint: .orange,
                title: String(localized: "picker.plan.equipment.unknown.title", bundle: .module),
                detail: unknownGapDetail(gaps)
            )
        case let .unavailable(gaps):
            equipmentStatusRow(
                icon: "exclamationmark.triangle.fill", tint: .red,
                title: String(localized: "picker.plan.equipment.unavailable.title", bundle: .module),
                detail: missingGapDetail(gaps)
            )
        }
    }

    private func equipmentStatusRow(icon: String, tint: Color, title: String, detail: String?) -> some View {
        DeltiqCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Nennt die konkret fehlenden Geraete (aus allen `.missing`-Luecken,
    /// dedupliziert) — nie nur "Equipment fehlt" ohne Angabe wonach.
    private func missingGapDetail(_ gaps: [PlanEquipmentGap]) -> String? {
        var items: Set<EquipmentItem> = []
        for gap in gaps {
            if case let .missing(reasons) = gap.reason {
                for reason in reasons { items.insert(reason.item) }
            }
        }
        guard !items.isEmpty else { return nil }
        let names = items.map { String(localized: $0.localizedName) }.sorted()
        return String(format: String(localized: "picker.plan.equipment.missingItems", bundle: .module), names.joined(separator: ", "))
    }

    /// Unterscheidet "Geraet selbst noch nicht bestaetigt/Stueckzahl unklar"
    /// (konkrete Item-Namen) von "Uebung noch nicht im Katalog annotiert"
    /// (kein Item nennbar — Audit-Vorgabe: fehlende Annotation ist kein
    /// Vorwand, irgendetwas zu behaupten). Zeigt beide Luecken-Arten, statt
    /// stillschweigend nur eine zu waehlen.
    private func unknownGapDetail(_ gaps: [PlanEquipmentGap]) -> String? {
        var uncertainItems: Set<EquipmentItem> = []
        var notAnnotatedCount = 0
        for gap in gaps {
            switch gap.reason {
            case let .uncertain(reasons):
                for reason in reasons { uncertainItems.insert(reason.item) }
            case .notAnnotated:
                notAnnotatedCount += 1
            case .missing:
                break
            }
        }
        var parts: [String] = []
        if !uncertainItems.isEmpty {
            let names = uncertainItems.map { String(localized: $0.localizedName) }.sorted()
            parts.append(String(format: String(localized: "picker.plan.equipment.uncertainItems", bundle: .module), names.joined(separator: ", ")))
        }
        if notAnnotatedCount > 0 {
            parts.append(String(localized: "picker.plan.equipment.notAnnotatedHint", bundle: .module))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

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
    ///
    /// PLAN_EQUIPMENT_MATCHING_AUDIT.md 5.4/13: loest ueber `checkedVariant`
    /// dieselbe Equipment-Variante auf wie `ProgramInstantiator.instantiate`
    /// (vorher wurde hier IMMER `template.days`, also die Basis-Variante,
    /// gezeigt — unabhaengig davon, welche Variante beim Adopt gespeichert
    /// wurde).
    private var orderedDays: [DaySpec] {
        checkedVariant.days.sorted { $0.sequenceIndex < $1.sequenceIndex }
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
