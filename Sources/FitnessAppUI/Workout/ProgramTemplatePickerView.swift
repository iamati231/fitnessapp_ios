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

    /// Audit-Fix (Save-Fehler): siehe `showTimedWorkoutSaveErrorToast`
    /// (TimedWorkoutPlayerView.swift) - geteilter Helper, gleiches Toast-Muster.
    @State private var saveErrorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UI-Refactor (DeltiqHeader-Muster fuer Sheets, Task 7
                // docs/superpowers/sdd/2026-10-22-ui-consistency): ersetzt das
                // vormals native Cancel-Toolbar. Reine Auswahl-Liste ohne
                // Entwurfszustand — der Chevron schliesst deshalb immer sofort,
                // kein Discard-Dialog noetig (unveraenderte Abbrechen-Semantik).
                DeltiqHeader(
                    eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                    title: String(localized: "picker.plan.title", bundle: .module),
                    onBack: { dismiss() }
                )
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
                                        adoptButtonTitle: String(localized: "picker.plan.adoptButton", bundle: .module),
                                        userEquipmentProfile: equipmentPlanningContext.effectiveProfile,
                                        goal: profiles.first?.trainingGoal ?? .hybrid,
                                        experienceTrack: profiles.first?.experienceTrack,
                                        isEquipmentAssumption: equipmentPlanningContext.isAssumption
                                    ) { selection in
                                        instantiate(template, selection: selection)
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
                // Fix-Runde 1 (Befund 4): ohne das hier schimmerte der
                // native gruppierte List-Hintergrund unter dem neuen
                // DeltiqHeader durch -- sichtbare Nahtstelle. Gleiches Muster
                // wie die anderen auf DeltiqHeader umgestellten Sheets dieser
                // Epic (siehe z.B. `ExerciseLibraryEditorSheet`s `Form`).
                .scrollContentBackground(.hidden)
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
        }
        .overlay(alignment: .bottom) {
            timedWorkoutSaveErrorOverlay(saveErrorMessage)
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

    /// Filtert nach `profile.environment`. Smart-Onboarding-Epic Phase 6
    /// (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md §3): dieselbe Lockerung
    /// wie `PlanMatchmaker.envMatches` — `.noEquipment` sieht jetzt auch
    /// Home-Gym-getaggte Templates (die konkrete Ausfuehrbarkeit entscheidet
    /// weiterhin die Equipment-Pruefung in der Vorschau, nicht dieser reine
    /// Orts-Filter):
    ///   - gym: alle Templates
    ///   - homeGym/noEquipment: homeGym + noEquipment
    /// Falls noch kein Profil existiert (sollte hier eigentlich nicht passieren
    /// — Profil ist Voraussetzung fuer MainTabView), fallen wir auf alle Plaene
    /// zurueck statt eine leere Liste zu zeigen.
    private var filteredTemplates: [ProgramTemplate] {
        guard let env = profiles.first?.environment else { return ProgramTemplates.all }
        return ProgramTemplates.all.filter { template in
            switch env {
            case .gym:
                return true
            case .homeGym, .noEquipment:
                return template.targetEnvironment == .homeGym || template.targetEnvironment == .noEquipment
            }
        }
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1/§4): derselbe effektive Planungskontext, den `TemplatePreviewView`
    /// fuer die Anzeige UND `instantiate` fuer die Veraltungspruefung nutzt —
    /// EINE Berechnung, nicht pro Call-Site neu zusammengesetzt. Fehlt noch
    /// ein Profil (siehe `filteredTemplates`-Kommentar), verhaelt sich das
    /// wie `.gym` mit leerem individuellem Profil (reine Gym-Annahme) statt
    /// gar nichts anzuzeigen.
    private var equipmentPlanningContext: EquipmentPlanningContext {
        EquipmentPlanningResolver.resolve(
            environment: profiles.first?.environment ?? .gym,
            individualProfile: profiles.first?.equipmentProfile ?? UserEquipmentProfile(),
            confirmedComplete: profiles.first?.equipmentProfileConfirmedComplete ?? false
        )
    }

    private var userEnvironmentLabel: String {
        guard let env = profiles.first?.environment else { return "alle" }
        // LocalizedStringResource → String via String(localized:) — Text-Inter-
        // polation wuerde es direkt nehmen, aber wir bauen hier einen reinen
        // String fuer die Section-Footer-Interpolation.
        return String(localized: env.localizedName)
    }

    private func instantiate(_ template: ProgramTemplate, selection: ResolvedPlanSelection) {
        // Smart-Onboarding-Epic Phase 5.4 (PLAN_SUBSTITUTION_ENGINE.md
        // Abschnitt 4): "Before saving, recheck against the current
        // equipment snapshot and reject stale/incompatible selection." In
        // diesem Flow liegt kein editierbarer Equipment-Schritt zwischen
        // Vorschau und Adopt — die Pruefung ist defensiv (deckt z.B. eine
        // Profil-Aenderung in einer anderen Szene ab), nie beobachtet als
        // erreichbarer Fall. Bei Veraltung wird still frisch aufgeloest,
        // statt eine moeglicherweise falsche Auswahl zu uebernehmen.
        //
        // Phase 6 (PLAN_LOCATION_EQUIPMENT_ONBOARDING.md §1/§4): der Vergleich
        // UND eine eventuelle Neuaufloesung laufen gegen denselben effektiven
        // Planungskontext wie die gerade gezeigte Vorschau (`equipmentPlanningContext`),
        // nicht gegen das rohe, individuelle Profil — sonst wuerde eine reine
        // Gym-Annahme bei jedem Adopt faelschlich als "veraltet" gelten.
        let currentEffectiveProfile = equipmentPlanningContext.effectiveProfile
        let freshSelection = selection.isStale(comparedTo: currentEffectiveProfile)
            ? PlanSelectionResolver.resolve(
                template: template, profile: currentEffectiveProfile,
                context: SubstitutionContext(goal: profiles.first?.trainingGoal ?? .hybrid, experienceTrack: profiles.first?.experienceTrack)
            )
            : selection

        let plan = ProgramInstantiator.instantiate(
            template,
            in: modelContext,
            resolvedSelection: freshSelection
        )
        // Audit-Fix (Save-Fehler): instantiate() inserted Plan+Tage+Uebungen,
        // hing bisher aber komplett am impliziten SwiftData-Autosave - ein
        // Kaltstart direkt nach der Auswahl konnte den ganzen Plan verlieren.
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(plan) // cascade: Tage + Uebungen gehen mit
            showTimedWorkoutSaveErrorToast($saveErrorMessage)
            return
        }
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
    /// erstellen will. Liefert EXAKT die hier angezeigte `ResolvedPlanSelection`
    /// zurueck — der Parent reicht sie unveraendert an
    /// `ProgramInstantiator.instantiate(resolvedSelection:)` weiter, damit
    /// Vorschau (inkl. ggf. angewandter Substitutionen) und Instanziierung
    /// nie auseinanderlaufen koennen (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 4).
    public let onAdopt: (ResolvedPlanSelection) -> Void
    /// Anpassbarer Button-Titel.
    public let adoptButtonTitle: String
    /// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md
    /// Abschnitt 13): dasselbe `UserEquipmentProfile`, das der jeweilige
    /// Parent gleich darauf an `ProgramInstantiator.instantiate` reicht —
    /// damit `resolvedSelection`/`orderedDays` IMMER dieselbe Variante (und
    /// denselben Equipment-Status) zeigen, die beim Adopt tatsaechlich
    /// gespeichert wird (Punkt 6). Default leer/unbekannt = Basis-Variante,
    /// Status `.unknown` fuer jede annotierte Uebung.
    public let userEquipmentProfile: UserEquipmentProfile
    /// Smart-Onboarding-Epic Phase 5.1 (PLAN_SUBSTITUTION_ENGINE.md): Kontext
    /// fuer das Regel-Gating der Substitutions-Engine (Kraft-Ziel-Anker,
    /// Starter-Schutz). Default `.hybrid`/`nil` fuer Call-Sites ohne eigene
    /// Zielangabe — dort bleiben die goal-/track-gegateten Regeln inaktiv,
    /// nie faelschlich aktiv.
    public let goal: TrainingGoal
    public let experienceTrack: ExperienceTrack?
    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1/§5): `true` ausschließlich, wenn `userEquipmentProfile` die reine
    /// Gym-Planungsannahme ist (`EquipmentPlanningContext.isAssumption`),
    /// NIE ein individuell bestätigtes Profil. Überschreibt die normale
    /// Equipment-Status-Anzeige durch einen Annahme-Hinweis — "Equipment
    /// passend"/"angepasst"/"fehlt" wären für eine Annahme eine zu starke,
    /// nicht belegte Aussage (Vorgabe: nie "Equipment bestätigt" für eine
    /// Annahme zeigen).
    public let isEquipmentAssumption: Bool

    @Environment(\.dismiss) private var dismiss

    public init(
        template: ProgramTemplate,
        // Audit-Fix (i18n): war ein hartkodierter deutscher Literal,
        // unlokalisiert. Kein Default mehr (CI-Fix): ein `public init`s
        // Default-Argument-Ausdruck wird am Call-Site neu ausgewertet und
        // darf daher keine `internal`-Symbole referenzieren - `Bundle.module`
        // ist `internal`. Der einzige Aufrufer, der sich bisher auf den
        // Default verlassen hat (ProgramTemplatePickerView.swift), uebergibt
        // den lokalisierten Titel jetzt explizit.
        adoptButtonTitle: String,
        userEquipmentProfile: UserEquipmentProfile = UserEquipmentProfile(),
        goal: TrainingGoal = .hybrid,
        experienceTrack: ExperienceTrack? = nil,
        isEquipmentAssumption: Bool = false,
        onAdopt: @escaping (ResolvedPlanSelection) -> Void
    ) {
        self.template = template
        self.adoptButtonTitle = adoptButtonTitle
        self.userEquipmentProfile = userEquipmentProfile
        self.goal = goal
        self.experienceTrack = experienceTrack
        self.isEquipmentAssumption = isEquipmentAssumption
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

    /// Smart-Onboarding-Epic Phase 5.3: EINZIGE Varianten-/Substitutions-
    /// Wahl fuer diese Vorschau — `onAdopt` liefert GENAU dieses Ergebnis an
    /// den Parent zurueck, der es unveraendert an
    /// `ProgramInstantiator.instantiate(resolvedSelection:)` reicht (Punkt 6:
    /// Vorschau und Instanziierung duerfen nie auseinanderlaufen).
    private var resolvedSelection: ResolvedPlanSelection {
        PlanSelectionResolver.resolve(
            template: template, profile: userEquipmentProfile,
            context: SubstitutionContext(goal: goal, experienceTrack: experienceTrack)
        )
    }

    /// Punkt 5/7/8: zeigt den tatsaechlichen Pruefstatus der oben gewaehlten
    /// Variante transparent an — "Equipment passend" nur bei `.available`
    /// OHNE Substitution, "angepasst" nur bei vollstaendig geloester
    /// Substitution (niemals bei einem nur TEILWEISE geloesten Versuch —
    /// `resolvedSelection.isAdapted` ist laut `PlanSelectionResolver` per
    /// Konstruktion nur bei vollstaendiger Loesung `true`). Eine verbleibende
    /// Luecke (fehlend oder unbekannt) wird konkret benannt statt
    /// stillschweigend uebergangen oder durch eine andere Uebung ersetzt.
    @ViewBuilder
    private var equipmentStatusBanner: some View {
        if isEquipmentAssumption {
            gymAssumptionBanner
        } else {
            let selection = resolvedSelection
            if let adaptation = selection.appliedAdaptation {
                adaptedEquipmentBanner(adaptation)
            } else {
                switch selection.equipmentStatus {
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
                        detail: missingGapDetail(gaps, attemptedButUnresolved: !selection.consideredButUnresolvedAdaptations.isEmpty)
                    )
                }
            }
        }
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §5): einzige Anzeige, wenn `isEquipmentAssumption == true` — niemals
    /// "Equipment passend"/"angepasst"/"fehlt", auch wenn die Pruefung gegen
    /// die Gym-Annahme technisch einen dieser Status ergeben wuerde. Eine
    /// Annahme bleibt eine Annahme, unabhaengig vom Rechenergebnis.
    private var gymAssumptionBanner: some View {
        equipmentStatusRow(
            icon: "building.2.fill", tint: .blue,
            title: String(localized: "picker.plan.equipment.gymAssumption.title", bundle: .module),
            detail: String(localized: "picker.plan.equipment.gymAssumption.detail", bundle: .module)
        )
    }

    /// Smart-Onboarding-Epic Phase 5.5: "Adapted to your equipment" NUR nach
    /// vollstaendig geloester Substitution — plus eine aufklappbare Vorher-
    /// Nachher-Liste mit lokalisierter Begruendung je Ersetzung (Vorgabe
    /// Abschnitt 6).
    private func adaptedEquipmentBanner(_ adaptation: PlanAdaptationDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            equipmentStatusRow(
                icon: "wand.and.stars", tint: .blue,
                title: String(localized: "picker.plan.equipment.adapted.title", bundle: .module),
                detail: nil
            )
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(adaptation.replacements.enumerated()), id: \.offset) { _, replacement in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(localizedExerciseName(replacement.originalName))
                                    .strikethrough()
                                    .foregroundStyle(Color.Deltiq.textSecondary)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(Color.Deltiq.textSecondary)
                                Text(localizedExerciseName(replacement.replacementName))
                                    .foregroundStyle(Color.primary)
                                    .font(.body.weight(.medium))
                            }
                            .font(.footnote)
                            Text(String(localized: String.LocalizationValue(replacement.reasonKey), bundle: .module))
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("picker.plan.equipment.adapted.showChanges", bundle: .module)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Deltiq.surface)
        )
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
    /// dedupliziert) — nie nur "Equipment fehlt" ohne Angabe wonach. Haengt
    /// optional den Hinweis an, dass eine automatische Anpassung versucht,
    /// aber nicht vollstaendig moeglich war (Vorgabe Abschnitt 3, Punkt 7:
    /// "explain missing equipment/unsupported tasks").
    private func missingGapDetail(_ gaps: [PlanEquipmentGap], attemptedButUnresolved: Bool = false) -> String? {
        var items: Set<EquipmentItem> = []
        for gap in gaps {
            if case let .missing(reasons) = gap.reason {
                for reason in reasons { items.insert(reason.item) }
            }
        }
        guard !items.isEmpty else { return nil }
        let names = items.map { String(localized: $0.localizedName) }.sorted()
        var text = String(format: String(localized: "picker.plan.equipment.missingItems", bundle: .module), names.joined(separator: ", "))
        if attemptedButUnresolved {
            text += " " + String(localized: "picker.plan.equipment.adaptationAttemptedHint", bundle: .module)
        }
        return text
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
                onAdopt(resolvedSelection)
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
    /// PLAN_EQUIPMENT_MATCHING_AUDIT.md 5.4/13 + PLAN_SUBSTITUTION_ENGINE.md
    /// Abschnitt 7: loest ueber `resolvedSelection` dieselbe (ggf.
    /// substituierte) Auswahl auf wie `ProgramInstantiator.instantiate`
    /// (vorher wurde hier IMMER `template.days`, also die Basis-Variante,
    /// gezeigt — unabhaengig davon, welche Variante beim Adopt gespeichert
    /// wurde).
    private var orderedDays: [DaySpec] {
        resolvedSelection.days.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    // `localizedExerciseName(_:)`/`detailLine(for:dayFormat:)` moved to
    // `Extensions/ExerciseSpec+DisplayName.swift` — `PlanBuilderView`'s
    // Schritt-3-Vorschau needs the identical logic, so it's a shared
    // top-level function now instead of a second, private copy here.
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
