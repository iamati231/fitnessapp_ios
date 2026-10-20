#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// README 2.20 "Plan bauen": 3-Schritte-Assistent, der aus mehreren
/// Trainingsarten (z.B. "3 Tage Kettlebell + 2 Tage Laufen") eine berechnete
/// Wochen-Struktur erzeugt. Shown als Sheet aus `PlansListView`s Plus-Menue,
/// gleiches Muster wie `ProgramTemplatePickerView`: kein Callback-Parameter,
/// `@Environment(\.dismiss)` + `@Environment(AppNavigation.self)` erledigen
/// Sheet-Schluss + Navigation zum neuen Plan selbst.
///
/// Struktur folgt bewusst `OnboardingView` (anderer Multi-Step-Assistent in
/// dieser Codebase): `NavigationStack`, oberer Fortschrittsbalken,
/// `Group { switch step { ... } }`, untere Zurueck/Weiter-Leiste.
///
/// DEL-243: `onGenerated` ist der EINZIGE Weg,
/// dieses Verhalten zu ueberschreiben - `OnboardingView` kann den fertig
/// gerechneten Plan nicht sofort selbst instanziieren (adoptieren wuerde
/// sonst eine verwaiste `TrainingPlan`-Zeile anlegen, BEVOR das
/// `UserBodyProfile` existiert, und `RootView`s Query-basierter Onboarding-
/// Abschluss haengt exakt an diesem Insert, nicht an der Plan-Erzeugung).
/// Ist `onGenerated` gesetzt, liefert `adoptPlan()` `PlanGeneratorInput` +
/// `PlanGenerator.Result` stattdessen nur nach oben durch - der Aufrufer
/// entscheidet selbst, wann/ob `PlanGeneratorInstantiator.build(...)`
/// laeuft (bei `OnboardingView` erst zusammen mit dem Profil in
/// `finishOnboarding()`). `nil` (Default) erhaelt das bisherige, sich
/// selbst adoptierende Verhalten fuer `PlansListView` unveraendert.
///
/// Nachbesserung (Task #197, zweite Korrekturrunde, Punkt C): `onGenerated`
/// meldet Erfolg/Fehler jetzt zurueck, statt bedingungslos zu dismissen -
/// ein Fehler im Cardio-"Plan anpassen"-Pfad (`PlansListView`/
/// `ProfileEditorView` rufen darin `CardioFeasibilityCardModel.acceptCustom`
/// auf, die wie `createPlan` werfen kann) darf den bearbeiteten Entwurf
/// nicht kommentarlos verwerfen.
///
/// Nachbesserung (Task #197, dritte Korrekturrunde, Punkt 4): der
/// Rueckgabewert ist jetzt `PlanBuilderHandoffOutcome` statt `String?` -
/// Erfolg, "vor Commit fehlgeschlagen" (sicher wiederholbar) und "bereits
/// committed, nur Aufloesung fehlgeschlagen" (NIE wiederholt create
/// aufrufen) muessen fuer den Aufrufer UNTERSCHEIDBAR bleiben, nicht nur als
/// derselbe Fehlertext. Diese View leitet ihre eigene, lokalisierte
/// Nachricht ERST aus diesem Zustand ab (siehe `adoptSaveErrorMessage`-Doku)
/// - der Aufrufer liefert keinen fertigen Text mehr. Die
/// Onboarding-Entwurfsuebergabe (reines `@State`-Zwischenspeichern, keine
/// Persistenz) liefert dafuer immer `.success` - sie kann strukturell nicht
/// fehlschlagen.
///
/// P2.4: Schritt 3 haelt die bearbeitete Wochenvorschau in einem `PlanDraft`
/// (Core, P2.0) statt in einem zweiten `PlanGenerator.Result`-State. Der
/// Generator-Output wird einmal pro Generierung (`generatePreviewIfNeeded`)
/// in den Draft uebernommen; ab da ist `draft` die massgebliche Quelle fuer
/// Anzeige UND Uebergabe - `currentResult` rekonstruiert bei Bedarf ein
/// `PlanGenerator.Result` daraus, damit sich am `onGenerated`-Vertrag oben
/// nichts aendert. Reorder/Fixierung liefen schon vor P2.4 ueber keine
/// eigene UI hier (siehe `PlanDraft.reorder(to:)`/`setContentFixed`/
/// `setPositionFixed` fuer den spaeteren visuellen Editor, P3.2) - diese
/// Anbindung fuehrt bewusst KEINE zweite Fixierungs-/Identitaets-/Reorder-
/// Logik ein, siehe docs/PLANUNG_BEGLEITUNG_AUDIT.md (P2.4-Abschnitt).
///
/// Nachbesserung: `currentResult` delegiert die eigentliche Rekonstruktion
/// an `PlanDraftResultAdapter` (Core) - derselbe Adapter, den
/// `PlanDraftResultAdapterTests` direkt und fuer sich (ohne SwiftUI) prueft.
/// `loadLevel`/`explanationKey` sind ABGELEITETE, generatorspezifische
/// Angaben (siehe Adapter-Doku) - P3 MUSS sie nach einer echten
/// Inhaltsaenderung (`replaceContent`) neu berechnen oder ausdruecklich als
/// nicht bewertet kennzeichnen, niemals unveraendert stehen lassen. Diese
/// Runde erzwingt das bereits dort, wo es ohne neue P3-UI moeglich ist: kein
/// stilles `.medium`, falls eine `loadLevel`-Zuordnung fehlt (siehe
/// `loadLevel(for:)`/`resultDayRow`s "nicht bewertet"-Badge-Zweig).
/// Nachbesserung (Task #197, dritte Korrekturrunde): Rueckgabewert fuer `PlanBuilderView`s
/// `onGenerated`-Callback. Bewusst KEIN `TrainingPlan`-Payload (anders als
/// `PlanCreationOperation.Outcome` in FitnessAppData) - im reinen Entwurfsuebergabe-Fall
/// (`OnboardingView`) existiert zu diesem Zeitpunkt gar kein Plan, nur ein Draft. Bewusst auch
/// KEIN fertiger Text - `PlanBuilderView` leitet ihre eigene, bereits vorhandene lokalisierte
/// Nachricht selbst aus diesem Fall ab (siehe `adoptSaveErrorMessage`-Doku).
public enum PlanBuilderHandoffOutcome {
    case success
    /// Nichts wurde committed - ein erneuter Tap auf "Plan uebernehmen" darf die volle
    /// Operation sicher wiederholen.
    case failedBeforeCommit
    /// Ein Plan WURDE bereits committed, nur die Aufloesung ist (auch nach dem internen Retry
    /// in `createPlan`) gescheitert - ein erneuter Tap darf NIEMALS `build`/`createPlan` erneut
    /// aufrufen. Der Aufrufer (z.B. `CardioFeasibilityCardModel` ueber eine eigene
    /// `PlanCreationOperation`) ist dafuer verantwortlich, einen weiteren Versuch nur noch ueber
    /// `resolveCreatedPlan` aufzuloesen.
    case committedButUnresolved
}

@available(iOS 17.0, macOS 14.0, *)
public struct PlanBuilderView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    /// Audit-Korrektur P2.1: der explizite Trainingsort + das effektive
    /// Equipment-Profil fuer `PlanGeneratorInstantiator.build` — vorher
    /// setzte `makeTemplate` `.gym` hartcodiert. `PlanBuilderView` fragt kein
    /// eigenes Profil ab (anders als `OnboardingView`/
    /// `CardioFeasibilityCardModel`, die es bereits als Parameter/State
    /// haben), deshalb hier dieselbe `@Query`, wie sie
    /// `ProgramTemplatePickerView.profiles` bereits verwendet.
    @Query private var profiles: [UserBodyProfile]

    // @MainActor explizit statt inferiert: `adoptPlan()` ruft diese Closure
    // synchron auf (kein await) und darf innerhalb selbst @MainActor-
    // isolierte Aufrufe machen (z.B. CardioFeasibilityCardModel.acceptCustom).
    // Ohne die explizite Annotation muesste der Compiler das aus dem
    // lexikalischen Kontext der jeweiligen Closure-Literale ableiten - nach
    // dem @MainActor-CI-Fund an CardioFeasibilityCardModel lieber explizit.
    private let onGenerated: (@MainActor (PlanGeneratorInput, PlanGenerator.Result) -> PlanBuilderHandoffOutcome)?

    /// P3.1 (Doc01 §3 Ziel-Schritt, nur im zielorientierten Pfad erreichbar -
    /// siehe `isPreSeededFlow`): meldet eine im Ziel-Schritt getroffene
    /// Ausdauerform-/Laufcoach-Entscheidung an den Aufrufer zurueck, der
    /// (anders als diese View im `onGenerated`-Handoff-Fall) tatsaechlich
    /// Zugriff auf das relevante `UserBodyProfile` hat (`OnboardingView`:
    /// erst in `finishOnboarding()` existent). Im eigenstaendigen Modus
    /// (`onGenerated == nil`, z.B. `PlansListView`s "+") schreibt diese View
    /// die Entscheidung stattdessen direkt selbst, siehe `adoptPlan()`.
    private let onEnduranceModalityChosen: (@MainActor (EnduranceModality?, Bool) -> Void)?

    /// Handoff "Lauf-Coaching - Machbarkeits-Check", Nachtrag "Plan
    /// anpassen": seedet Schritt 1/2 aus einem vorhandenen Input statt der
    /// leeren Defaults - der Nutzer landet weiterhin bei Schritt 1, sieht
    /// dort aber den Kraft-/Lauf-Mix aus dem Machbarkeits-Vorschlag bereits
    /// eingetragen und kann ihn frei weiter anpassen ("Neu rechnen" bleibt
    /// unveraendert nutzbar). `Dictionary(_:uniquingKeysWith:)` statt
    /// `uniqueKeysWithValues:` - defensiv gegen einen (hier nie auftretenden)
    /// Input mit zwei Selections derselben Kind, damit ein fremd erzeugter
    /// Input diesen Init nicht crasht.
    ///
    /// P3.1: ein Input MIT konkreten `selections` (dieser Handoff-Fall) ist
    /// gleichzeitig das Signal fuer `isPreSeededFlow` - Schritt 1/2 zeigen
    /// dann weiterhin die bestehende, trainingsmittel-direkte Auswahl
    /// (unveraendertes Verhalten), NICHT den neuen Ziel-Schritt. Ein Input
    /// mit LEEREN `selections` (Onboarding, `nil` fuer `PlansListView`s "+")
    /// zeigt stattdessen den neuen zielorientierten Einstieg.
    /// P4.1: `preseededEnduranceModality`/`preseededRunCoachWanted` fuellen
    /// die Ausdauerform-/Laufcoach-Unterfrage des neuen Ziel-Schritts
    /// (`enduranceModalitySubflow`) VOR, wenn der Aufrufer die Antwort
    /// bereits kennt - konkret: `OnboardingView`s neuer, fruehere
    /// `.enduranceModality`-Schritt (P4.1) hat die Frage schon gestellt,
    /// BEVOR der User ueberhaupt in den eingebetteten Builder wechselt. Ohne
    /// Vorbefuellung muesste der User dieselbe Frage ein zweites Mal von
    /// Null beantworten - KEIN zweiter, konkurrierender Schalter (es bleibt
    /// derselbe `onEnduranceModalityChosen`-Rueckkanal), nur eine bequemere
    /// Startauswahl, die der User fuer DIESEN Plan weiterhin aendern kann.
    /// Ohne Wirkung im `isPreSeededFlow`-Pfad (dort gibt es den Ziel-Schritt
    /// gar nicht) und im eigenstaendigen `PlansListView`-"+"-Pfad (dort gibt
    /// es keine vorherige Antwort).
    public init(
        initialInput: PlanGeneratorInput? = nil,
        preseededEnduranceModality: EnduranceModality? = nil,
        preseededRunCoachWanted: Bool = false,
        preseededGoal: TrainingGoal? = nil,
        preseededDaysPerWeek: Int? = nil,
        onGenerated: (@MainActor (PlanGeneratorInput, PlanGenerator.Result) -> PlanBuilderHandoffOutcome)? = nil,
        onEnduranceModalityChosen: (@MainActor (EnduranceModality?, Bool) -> Void)? = nil
    ) {
        self.onGenerated = onGenerated
        self.onEnduranceModalityChosen = onEnduranceModalityChosen
        if let initialInput {
            _selectedKinds = State(initialValue: initialInput.selections.map(\.kind))
            _configByKind = State(initialValue: Dictionary(
                initialInput.selections.map { ($0.kind, $0) },
                uniquingKeysWith: { _, latest in latest }
            ))
            _equipmentPreferences = State(initialValue: initialInput.equipmentPreferences)
            _usesFixedWeekdays = State(initialValue: initialInput.usesFixedWeekdays)
            _fixedWeekdays = State(initialValue: Set(initialInput.fixedWeekdays))
        }
        _selectedEnduranceModality = State(initialValue: preseededEnduranceModality)
        _runCoachWanted = State(initialValue: preseededRunCoachWanted)
        // Geraete-Abnahme (A01): `trainingGoal`/`weeklyGoal` wurden im
        // umschliessenden `OnboardingView` bereits beantwortet, BEVOR der
        // User ueberhaupt in diesen eingebetteten Builder wechselt - ohne
        // diese Vorbefuellung muesste er beides hier identisch nochmal
        // beantworten (siehe `GoalCard.seeded(from:)`-Doku). Bleibt frei
        // weiter aenderbar, genau wie die bereits bestehende
        // Ausdauerform-/Equipment-Vorbefuellung oben.
        if let preseededGoal, let card = GoalCard.seeded(from: preseededGoal) {
            _selectedGoalCard = State(initialValue: card)
            if card == .strengthFocus {
                _strengthFocus = State(initialValue: preseededGoal)
            }
        }
        if let preseededDaysPerWeek {
            _totalDaysPerWeek = State(initialValue: preseededDaysPerWeek)
        }
    }

    enum BuilderStep: Int, CaseIterable {
        case types, equipment, result
    }

    /// P3.1 (Doc01 §3): die vier Zielkarten des neuen Einstiegs. Bewusst eine
    /// eigene, kleinere UI-Vokabel statt `TrainingGoal` direkt zu verwenden -
    /// "Kraft & Muskelaufbau" deckt ZWEI bestehende Core-Werte ab
    /// (`.hypertrophy`/`.strength`, siehe `strengthFocus`), und die Karte
    /// "Allgemeine Fitness" bildet bewusst nicht-woertlich auf `.functional`
    /// ab (Core-Blurb "Alltagstaugliche Bewegungsmuster ... kein reiner
    /// Kraft- oder Muskelfokus" trifft die Karte am besten). `.weightLoss`
    /// bleibt bewusst AUSSEN VOR (keine der vier Dok01-Karten benennt
    /// Abnehmen/Fettabbau als eigene Zielkarte) - weiterhin ausschliesslich
    /// ueber `ProfileEditorView.coachingCard`s volle Zielauswahl erreichbar.
    enum GoalCard: CaseIterable {
        case strengthFocus, endurance, hybrid, generalFitness

        var titleKey: String {
            switch self {
            case .strengthFocus:  return "planBuilder.goal.strengthHypertrophy.title"
            case .endurance:      return "planBuilder.goal.endurance.title"
            case .hybrid:         return "planBuilder.goal.hybrid.title"
            case .generalFitness: return "planBuilder.goal.generalFitness.title"
            }
        }

        var blurbKey: String {
            switch self {
            case .strengthFocus:  return "planBuilder.goal.strengthHypertrophy.blurb"
            case .endurance:      return "planBuilder.goal.endurance.blurb"
            case .hybrid:         return "planBuilder.goal.hybrid.blurb"
            case .generalFitness: return "planBuilder.goal.generalFitness.blurb"
            }
        }

        var symbol: String {
            switch self {
            case .strengthFocus:  return "figure.strengthtraining.traditional"
            case .endurance:      return "figure.run"
            case .hybrid:         return "figure.mixed.cardio"
            case .generalFitness: return "figure.cooldown"
            }
        }

        /// Doc02 §2 "Nach Auswahl von Hybrid: 1. Ausdauerform klaeren" - gilt
        /// identisch fuer die reine Ausdauerkarte.
        var needsEnduranceModality: Bool { self == .endurance || self == .hybrid }

        /// Geraete-Abnahme (A01, docs/DELTIQ_DEVICE_ACCEPTANCE.md): die
        /// `init(initialInput:)`-Vorbefuellung deckte bisher nur Equipment
        /// und Ausdauerform ab (siehe dortige Doku) - `OnboardingView`s
        /// eigener, frueherer `trainingGoal`-Schritt (Coaching-Step) blieb
        /// dabei unberuecksichtigt: der eingebettete Builder fragte dieselbe
        /// Zielinformation hier nochmal komplett von Null ab. `.weightLoss`
        /// hat bewusst KEINE eigene Zielkarte (siehe Typ-Doku oben) - bleibt
        /// dafuer unausgewaehlt, der User trifft bewusst eine neue Wahl aus
        /// den vier Builder-Karten statt einer stillen Zuordnung.
        static func seeded(from trainingGoal: TrainingGoal) -> GoalCard? {
            switch trainingGoal {
            case .hypertrophy, .strength: return .strengthFocus
            case .hybrid: return .hybrid
            case .endurance: return .endurance
            case .functional: return .generalFitness
            case .weightLoss: return nil
            }
        }
    }

    @State private var step: BuilderStep = .types

    // Schritt 1 (trainingsmittel-direkter Pfad - siehe `isPreSeededFlow`)
    @State private var selectedKinds: [TrainingTypeKind] = []
    @State private var configByKind: [TrainingTypeKind: PlanGeneratorTypeSelection] = [:]
    @State private var expandedKind: TrainingTypeKind?

    /// P3.1: `true`, sobald `init(initialInput:)` mit NICHT-leeren `selections`
    /// aufgerufen wurde (Cardio-Machbarkeits-"Plan anpassen"-Handoff) - dieser
    /// Pfad behaelt die bestehende, trainingsmittel-direkte Schritt-1/2-UI
    /// unveraendert (Doc01 §1: "Bestehende ... funktionierende Eingaenge
    /// erhalten"). `false` zeigt stattdessen den neuen zielorientierten
    /// Einstieg (Doc01 §3) - der Fall fuer `PlansListView`s "+" (kein Input)
    /// und `OnboardingView`s eingebetteten Builder (Input mit LEEREN
    /// `selections`, siehe dortige Doku).
    private var isPreSeededFlow: Bool { !selectedKinds.isEmpty }

    // Schritt 1 (zielorientierter Pfad, Doc01 §3)
    @State private var selectedGoalCard: GoalCard?
    /// Nur relevant, wenn `selectedGoalCard == .strengthFocus`.
    @State private var strengthFocus: TrainingGoal = .hypertrophy
    /// Nur relevant fuer `.endurance`/`.hybrid` - bewusst OHNE kosmetischen
    /// Default (anders als `ProfileEditorView.displayedEnduranceModality`):
    /// Doc02 verlangt eine EXPLIZITE Antwort ("keine unbekannte Auswahl still
    /// in Laufen umwandeln"), ein bereits laufend selektiert wirkendes
    /// Segment waere genau das.
    @State private var selectedEnduranceModality: EnduranceModality?
    /// Doc02 §3, Zustandstabelle: nur wirksam, wenn die Modalitaet Laufen
    /// unterstuetzt (`EnduranceModality.supportsRunCoach`) - siehe
    /// `applyEnduranceModalityChoiceIfNeeded`.
    @State private var runCoachWanted = false

    private var selectedTrainingGoal: TrainingGoal? {
        guard let selectedGoalCard else { return nil }
        switch selectedGoalCard {
        case .strengthFocus:  return strengthFocus
        case .endurance:      return .endurance
        case .hybrid:         return .hybrid
        case .generalFitness: return .functional
        }
    }

    @State private var totalDaysPerWeek = 3
    @State private var sessionDurationMinutes = 45
    @State private var experience: DifficultyLevel = .intermediate
    @State private var showEquipmentOverrideOptions = false

    // Schritt 2
    @State private var equipmentPreferences: Set<Equipment> = []
    @State private var usesFixedWeekdays = false
    @State private var fixedWeekdays: Set<Int> = []

    // Schritt 3
    /// P2.4: der generierte Wochenvorschlag wird EINMAL in einen `PlanDraft`
    /// uebernommen (siehe Typ-Doku) und ist ab da die massgebliche Quelle
    /// fuer die Vorschau UND die Uebergabe (`currentResult` unten) - kein
    /// separates `PlanGenerator.Result`-State mehr. Wiederverwendet die
    /// komplette Fixierungs-/Identitaets-/Reorder-Logik aus P2.0
    /// (`PlanDraft`), ohne sie hier zu duplizieren.
    @State private var draft: PlanDraft?
    /// `loadLevel` ist bewusst NICHT Teil von `DraftDay`/Core: ein
    /// generatorspezifisches, GESAMT-Wochen-relatives Anzeigekonzept
    /// (`loadLevels(for:)` vergleicht alle Tage EINES Generierungslaufs
    /// gegeneinander), keine Eigenschaft eines einzelnen Tages und keine
    /// Fixierungs-/Identitaetsfrage - gehoert deshalb nicht in die
    /// wiederverwendbare `PlanDraft`-Schicht. Lebt stattdessen hier, ueber
    /// die stabile `DraftDayID` an den jeweiligen Tag gebunden.
    @State private var loadLevelByDayID: [DraftDayID: PlanLoadLevel] = [:]
    @State private var explanationKey: String?
    /// Verhindert, dass ein blosses erneutes Betreten von Schritt 3 (ohne
    /// Aenderung an Schritt 1/2) den Entwurf mit neuen `DraftDayID`s ersetzt
    /// - siehe `generatePreviewIfNeeded`.
    @State private var lastGeneratedInput: PlanGeneratorInput?

    /// P3.2/P3.3: sichtbares Feedback fuer zwei Faelle, die sonst ein
    /// stilles No-Op waeren - eine wegen Positionsfixierung abgelehnte
    /// Verschiebung (Abnahme B01) UND ein Tag, fuer den `targetedAlternatives`
    /// keine echte Alternative liefern kann (Abnahme B05 "sichtbarer
    /// Konflikt statt abgeschnittener Einheiten"). Gleiches Anzeige-Muster
    /// wie `PlanEditorView.swapResultToast`, nur mit austauschbarem Icon,
    /// damit die beiden Faelle optisch unterscheidbar bleiben.
    @State private var footerToastMessage: String?
    @State private var footerToastSystemImage = "pin.slash.fill"

    // P3.3: ausgewaehlter Tag + seine gerade angebotenen Alternativen fuer
    // den Alternativen-Dialog (siehe `presentAlternatives`/`.confirmationDialog`
    // in `resultStepView`). Getrennt von `draft`, weil Alternativen reine
    // Vorschlaege sind, bevor der Nutzer eine davon uebernimmt.
    @State private var alternativesDialogDayID: DraftDayID?
    @State private var currentAlternativeOptions: [DaySpec] = []

    /// Audit-Korrektur (Review nach P2.1): treibt den expliziten Fehler-
    /// Zustand, wenn `adoptPlan()` im eigenstaendigen Modus kein Profil
    /// findet — siehe dortigen Kommentar. `nil` = kein Fehler/Alert nicht
    /// sichtbar, identisches Muster wie `SettingsView.resetErrorMessage`.
    @State private var missingProfileErrorMessage: String?

    /// Nachbesserung (Task #197): `createPlan` wirft jetzt, wenn der
    /// abschliessende Speichervorgang fehlschlaegt - eigener Alert statt
    /// Wiederverwendung von `missingProfileErrorMessage` (andere Ursache,
    /// anderer Titel, siehe `body`). `isAdopting` wird in diesem Fall
    /// zurueckgesetzt, ein erneuter Tap auf "Plan uebernehmen" ist sicher:
    /// `PlanGeneratorInstantiator.build` hat den fehlgeschlagenen Plan
    /// bereits selbst zurueckgebaut (siehe dortige Doku).
    ///
    /// Nachbesserung (zweite Korrekturrunde, Punkt C): dient jetzt ZWEI
    /// Zwecken - dem eigenen `createPlan`-Fehlerpfad dieser View UND jeder
    /// ueber `onGenerated` zurueckgemeldeten Fehlermeldung (Cardio-"Plan
    /// anpassen"-Pfad, siehe `onGenerated`-Typ-Doku). In beiden Faellen
    /// bleibt das Sheet offen, der Entwurf unveraendert.
    @State private var adoptSaveErrorMessage: String?

    /// Nachbesserung (dritte Korrekturrunde): `creationOperation.attempt(...)` kann nach einem
    /// ERFOLGREICHEN Speichervorgang trotzdem `.committedButUnresolved` liefern, wenn NUR die
    /// Rueckbindung scheitert - "Es wurde nichts geaendert" waere dann falsch. Steuert, welcher
    /// Alert-Titel zu `adoptSaveErrorMessage` gezeigt wird UND (siehe `navigationBar`) ob der
    /// Haupt-Button noch "Plan uebernehmen" oder nur noch "Erneut versuchen" anbietet - in
    /// diesem Zustand darf NIE wieder `create()` aufgerufen werden (siehe `creationOperation`).
    /// Gilt sowohl fuer den direkten `createPlan`-Pfad dieser View als auch fuer jeden ueber
    /// `onGenerated` zurueckgemeldeten `.committedButUnresolved`-Fall.
    @State private var adoptSaveErrorIsCreatedButUnresolved = false

    /// Nachbesserung (Task #197, dritte Korrekturrunde): der tatsaechliche Operationszustand
    /// fuer den EIGENEN, direkten `createPlan`-Pfad dieser View (NICHT fuer den
    /// `onGenerated`-Pfad - der Cardio-Aufrufer haelt dafuer seine EIGENE Instanz, siehe
    /// `PlanCreationOperation`-Typ-Doku). Einmal committed, ruft `attempt(...)` fuer diese
    /// Instanz nie wieder `create()` auf - genau das verhindert den Duplikat-Fall, den ein
    /// erneuter Tap auf denselben Button sonst ausloesen wuerde.
    @State private var creationOperation = PlanCreationOperation()

    /// Nachbesserung (vierte Korrekturrunde, "zusaetzlicher kleiner UI-Fix"): im
    /// `onGenerated`-Pfad (externer Handoff, z.B. Cardio-"Plan anpassen") liegt die
    /// tatsaechliche `PlanCreationOperation` beim AUFRUFER (siehe `creationOperation`-Doku oben) -
    /// diese View bekommt nur den `PlanBuilderHandoffOutcome` zurueck, nie die fremde Instanz
    /// selbst. Liefert dieser Pfad `.committedButUnresolved`, bleibt `creationOperation` (diese
    /// Views EIGENE, im `onGenerated`-Fall ungenutzte Instanz) unveraendert `nil` - ohne dieses
    /// Flag wuerde der Haupt-Button in `navigationBar` faelschlich weiter "Plan uebernehmen"
    /// statt "Erneut versuchen" zeigen, obwohl der Plan extern bereits persistiert wurde. Reine
    /// Label-Korrektur: die eigentliche Duplikat-Sicherheit fuer diesen Pfad liegt bereits
    /// vollstaendig beim Aufrufer (dessen eigene `resumeIfCommitted`-first-Logik in
    /// `CardioFeasibilityCardModel.acceptCustom` verhindert ein zweites `create()` unabhaengig
    /// von dieser View). Einweg wie `creationOperation.committedPlanID` - kein Reset.
    @State private var externalHandoffIsCommittedButUnresolved = false

    /// Nachbesserung (P2.3, Abnahme "keine Duplikate bei mehrfacher
    /// Bestaetigung"): `adoptPlan()` ist synchron, ohne `await` — ein
    /// zweiter Tap auf "Plan uebernehmen", bevor `dismiss()` den Sheet
    /// tatsaechlich schliesst, wuerde sonst ein zweites Mal instanziieren
    /// (bzw. im `onGenerated`-Pfad die Closure zweimal feuern). Deckt BEIDE
    /// Zweige von `adoptPlan()` ab (Onboarding-Callback UND eigenstaendiges
    /// Erstellen), da der Button in `navigationBar` fuer beide derselbe ist.
    @State private var isAdopting = false

    /// P3.4-Nachbesserung (Header-Konvention): die Vorgabe "Haken oben
    /// rechts, 'Trainingsplan uebernehmen', Verwerfen-Dialog" bleibt
    /// VERBINDLICH, auch fuer einen mehrschrittigen Assistenten — eine
    /// fruehere Audit-Runde hatte das faelschlich als "veraltete
    /// Checklisten-Punkt" eingestuft und auf `OnboardingView`s abweichendes
    /// Muster verwiesen; das bestehende Onboarding-Layout ist aber kein
    /// Grund, eine eigenstaendige Produktvorgabe fuer DIESEN Screen fallen
    /// zu lassen. Zeigt den Verwerfen-Dialog beim Zurueck-Chevron, sobald
    /// der Nutzer bereits eine echte Auswahl getroffen hat — auf Schritt 1
    /// zaehlt dafuer die erste Ziel-/Trainingsart-Auswahl, jeder weitere
    /// Schritt gilt automatisch als "etwas zu verlieren" (man kommt ohne
    /// Auswahl nicht dorthin). Im Cardio-Handoff-Fall (`isPreSeededFlow`)
    /// ist `selectedKinds` von Anfang an vorbefuellt — das ist beabsichtigt:
    /// der Nutzer hat diesen Anpassen-Flow bereits bewusst gestartet, ein
    /// Abbruch soll ihn deshalb auch ohne zusaetzliche eigene Aenderung
    /// bestaetigen muessen.
    private var isDirty: Bool {
        if step != .types { return true }
        return isPreSeededFlow ? !selectedKinds.isEmpty : selectedGoalCard != nil
    }

    @State private var showingDiscardConfirm = false

    /// P3.3-Restaufgabe #206 ("Vorschlag neu erstellen"): nur gezeigt, wenn
    /// `draft.hasAnyFixation` - siehe `requestFreshProposal()`. Eine
    /// ausdrueckliche Entscheidung statt eines stillen Resets (Vorgabe
    /// dieser Runde), weil diese Aktion anders als #205
    /// ("Woche anders verteilen") auch fixierte/manuell geaenderte Tage
    /// ersetzt.
    @State private var showingFreshProposalConfirm = false

    /// Nur auf dem Ergebnis-Schritt vorhanden — frueheren Schritten fehlt
    /// schlicht ein Zustand, der sich "uebernehmen" liesse (identisches
    /// Prinzip wie der deaktivierte Checkmark in `BodyDataEditorView` bei
    /// ungueltigem Formular, hier: noch kein Schritt mit Ergebnis erreicht).
    private var headerActions: [DeltiqHeaderAction] {
        guard step == .result else { return [] }
        let isRetry = creationOperation.committedPlanID != nil || externalHandoffIsCommittedButUnresolved
        var actions: [DeltiqHeaderAction] = []
        // P3.3-Restaufgaben #205/#206: eigenstaendige Gesamt-Wochen-Aktionen,
        // getrennt vom bestehenden Pro-Tag-"Alternativen"-Menu
        // (`resultDayRow`) UND von `PlanEditorView.planMenuAction`s "Neu
        // rechnen" (anderer Codepfad: dort ein bereits ADOPTIERTER,
        // persistierter Plan via `PlanGeneratorInstantiator.recalculate` -
        // hier ausschliesslich der noch ungespeicherte `PlanDraft`). Bewusst
        // andere Icons/Label als dort, um beide Aktionen nicht zu verwechseln.
        if !(draft?.days.isEmpty ?? true) {
            actions.append(DeltiqHeaderAction(systemImage: "ellipsis", menu: {
                Button {
                    redistributeWeek()
                } label: {
                    Label {
                        Text("planBuilder.result.redistribute.action", bundle: .module)
                    } icon: {
                        Image(systemName: "shuffle")
                    }
                }
                Button {
                    requestFreshProposal()
                } label: {
                    Label {
                        Text("planBuilder.result.freshProposal.action", bundle: .module)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            }))
        }
        actions.append(DeltiqHeaderAction(
            systemImage: "checkmark",
            // A12 (Paket 1): ein ungeloester distributionConflict (z. B.
            // Hybrid+Both bei zu wenigen Tagen) darf nicht durch einen
            // allgemeinen Uebernehmen-Tap stillschweigend als "Kompromiss
            // akzeptiert" gelten - Uebernahme bleibt blockiert, bis der
            // Nutzer ueber die Tage- oder Ziel-/Ausdauerform-Auswahl aktiv
            // etwas aendert (beide bereits bestehende Schritte).
            isDisabled: (draft?.days.isEmpty ?? true) || isAdopting || distributionConflict != nil,
            accessibilityLabel: String(localized: isRetry ? "planBuilder.result.retryResolve" : "planBuilder.result.adopt", bundle: .module)
        ) {
            adoptPlan()
        })
        return actions
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DeltiqHeader(
                    eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                    title: String(localized: "planBuilder.title", bundle: .module),
                    onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                    actions: headerActions
                )
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider()
                Group {
                    currentStepView
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)
                Divider()
                navigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            // Sheet (nicht Push-Navigation, siehe Datei-Kommentar oben) -
            // das Pendant zu PlanEditorViews `deltiqSwipeBackEnabled` ist
            // hier das Sheet-eigene Pull-to-dismiss, identisches Prinzip wie
            // TrainingLocationEquipmentEditorView: ohne Aenderungen bleibt es
            // normal moeglich, mit Aenderungen nur ueber den Verwerfen-Dialog.
            .interactiveDismissDisabled(isDirty)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            // P3.3-Restaufgabe #206: ausdrueckliche Bestaetigung statt
            // stillem Reset, siehe `showingFreshProposalConfirm`-Doku und
            // `requestFreshProposal()`.
            .confirmationDialog(
                Text("planBuilder.result.freshProposal.confirm.title", bundle: .module),
                isPresented: $showingFreshProposalConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    performFreshProposal()
                } label: {
                    Text("planBuilder.result.freshProposal.confirm.action", bundle: .module)
                }
                Button(role: .cancel) {} label: {
                    Text("common.cancel", bundle: .module)
                }
            } message: {
                Text("planBuilder.result.freshProposal.confirm.message", bundle: .module)
            }
            // Audit-Korrektur (Review nach P2.1): expliziter Fehlerzustand
            // statt stillem `.gym`-Fallback, siehe `adoptPlan()`. Gleiches
            // Muster wie `SettingsView.resetErrorMessage`.
            .alert(
                Text("planBuilder.error.noProfile.title", bundle: .module),
                isPresented: Binding(
                    get: { missingProfileErrorMessage != nil },
                    set: { if !$0 { missingProfileErrorMessage = nil } }
                )
            ) {
                Button("OK") { missingProfileErrorMessage = nil }
            } message: {
                Text(missingProfileErrorMessage ?? "")
            }
            // Nachbesserung (Task #197): eigener Alert fuer einen fehlgeschlagenen
            // Speichervorgang - siehe `adoptSaveErrorMessage`-Doku.
            // Nachbesserung (zweite Korrekturrunde, Punkt B): Titel haengt vom genauen
            // Fehlerfall ab - "konnte nicht gespeichert werden" waere falsch, wenn der
            // Plan tatsaechlich bereits gespeichert wurde und nur die Rueckbindung scheiterte.
            .alert(
                Text(adoptSaveErrorIsCreatedButUnresolved
                     ? "planBuilder.error.createdButUnresolved.title"
                     : "planBuilder.error.saveFailed.title", bundle: .module),
                isPresented: Binding(
                    get: { adoptSaveErrorMessage != nil },
                    set: { if !$0 { adoptSaveErrorMessage = nil } }
                )
            ) {
                Button("OK") { adoptSaveErrorMessage = nil }
            } message: {
                Text(adoptSaveErrorMessage ?? "")
            }
        }
    }

    /// P3.1: Schritt 1/2 zeigen je nach Pfad unterschiedlichen Inhalt (siehe
    /// `isPreSeededFlow`) - der Handoff-Pfad behaelt die bestehende,
    /// trainingsmittel-direkte UI unveraendert, der Standard-Pfad zeigt den
    /// neuen zielorientierten Einstieg.
    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .types:
            if isPreSeededFlow { typesStep } else { goalStep }
        case .equipment:
            if isPreSeededFlow { equipmentStep } else { alltagsrahmenStep }
        case .result:
            resultStepView
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(BuilderStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.deltiqOrange : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Schritt 1: Trainingsarten und Tage

    private var unselectedKinds: [TrainingTypeKind] {
        TrainingTypeKind.allCases.filter { !selectedKinds.contains($0) }
    }

    /// P3.1: im zielorientierten Pfad (siehe `isPreSeededFlow`) gibt es keine
    /// Pro-Kind-Tage mehr, sondern eine einzige Gesamtzahl aus dem
    /// Alltagsrahmen-Schritt (`totalDaysPerWeek`) - `weekdayGrid`/
    /// `weekdayRow`/`toggleWeekday` bleiben dadurch fuer BEIDE Pfade
    /// unveraendert wiederverwendbar.
    private var totalSelectedDays: Int {
        isPreSeededFlow ? configByKind.values.reduce(0) { $0 + $1.daysPerWeek } : totalDaysPerWeek
    }

    private var typesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("planBuilder.types.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("planBuilder.types.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if totalSelectedDays > 0 {
                    DeltiqContextRow([
                        DeltiqContextItem(pluralizedCount("planBuilder.wizard.unitsCount", count: totalSelectedDays).uppercased(), style: .accent)
                    ])
                }

                ForEach(selectedKinds, id: \.self) { kind in
                    typeCard(kind)
                }

                if !unselectedKinds.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 8) {
                            ForEach(unselectedKinds, id: \.self) { kind in
                                FilterToggleRow(
                                    label: String(localized: kind.localizedName),
                                    isOn: Binding(
                                        get: { false },
                                        set: { newValue in if newValue { selectKind(kind) } }
                                    )
                                )
                                .disabled(!canAddMoreDays)
                                .opacity(canAddMoreDays ? 1.0 : 0.4)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("planBuilder.types.more", bundle: .module)
                            .font(.body.weight(.medium))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func typeCard(_ kind: TrainingTypeKind) -> some View {
        let isExpanded = expandedKind == kind
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                expandedKind = isExpanded ? nil : kind
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: trainingTypeIcon(kind))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.deltiqOrange.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.localizedName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isExpanded, let config = configByKind[kind] {
                            Text(collapsedSummary(for: config))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        removeKind(kind)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let config = configByKind[kind] {
                configControls(kind: kind, config: config)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                        lineWidth: isExpanded ? 1.5 : 1)
        )
    }

    private func configControls(kind: TrainingTypeKind, config: PlanGeneratorTypeSelection) -> some View {
        // README 2.20: Dauern aus Schritt 1 werden nicht verhandelt - aber
        // die SUMME aller Tage/Woche darf 7 nie ueberschreiten, sonst
        // verwirft `ProgramInstantiator.instantiate` ueberzaehlige Tage
        // stillschweigend (Wochentage sind endlich). Deckel gilt pro Karte:
        // 7 minus das, was die ANDEREN Arten bereits belegen.
        let otherDays = totalSelectedDays - config.daysPerWeek
        let maxDaysForThisKind = max(1, 7 - otherDays)

        return VStack(alignment: .leading, spacing: 14) {
            Divider()

            Stepper(
                pluralizedCount("planBuilder.wizard.daysPerWeek", count: config.daysPerWeek),
                value: Binding(
                    get: { config.daysPerWeek },
                    set: { updateConfig(kind, daysPerWeek: $0) }
                ),
                in: 1...maxDaysForThisKind
            )

            Stepper(
                String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), config.sessionDurationMinutes),
                value: Binding(
                    get: { config.sessionDurationMinutes },
                    set: { updateConfig(kind, sessionDurationMinutes: $0) }
                ),
                in: 15...120,
                step: 5
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("planBuilder.wizard.experience", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "",
                    selection: Binding(
                        get: { config.experience },
                        set: { updateConfig(kind, experience: $0) }
                    )
                ) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            // README 2.35: Zeitformat-Wahl gilt EXPLIZIT nur fuer Laufen/
            // Radfahren, nicht die vier Kraft-Arten (Gegenteil der zuerst
            // naheliegenden Annahme - siehe README-Text). `kind.isCardio`
            // ist exakt derselbe Schalter, den `PlanGenerator.cardioCandidates`
            // schon zur Filterung benutzt. Wiederverwendet dieselben Keys
            // wie `DayEditorView.metaSection`s "Struktur"-Zeile (43a) -
            // gleiches Konzept, keine zweiten Strings noetig.
            if kind.isCardio {
                VStack(alignment: .leading, spacing: 6) {
                    Text("day.editor.field.structure", bundle: .module)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker(
                        "",
                        selection: Binding(
                            get: { config.timeFormat },
                            set: { updateTimeFormat(kind, timeFormat: $0) }
                        )
                    ) {
                        Text("day.editor.field.structure.sets", bundle: .module).tag(nil as WorkoutTimeFormat?)
                        // Zirkel (feste Rundenzahl + Pause dazwischen)
                        // bewusst ausgeschlossen: fuer Laufen/Radfahren deckt
                        // sich das schon mit dem bestehenden
                        // `RunZone.interval`-Muster in `PlanGenerator`
                        // (Intervall-Wiederholungen mit fester Pause, ueber
                        // das normale Saetze/Pause-Schema, kein eigenes
                        // Zeitformat noetig).
                        ForEach(WorkoutTimeFormat.allCases.filter { $0 != .circuit }, id: \.self) { format in
                            Text(timedFormatDisplayName(format)).tag(format as WorkoutTimeFormat?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func collapsedSummary(for config: PlanGeneratorTypeSelection) -> String {
        let days = pluralizedCount("planBuilder.wizard.daysPerWeek", count: config.daysPerWeek)
        let minutes = String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), config.sessionDurationMinutes)
        let experience = String(localized: config.experience.localizedName)
        var parts = [days, minutes, experience]
        // README 2.35: sonst sieht ein eingeklapptes Laufen/Radfahren-Karte
        // mit z.B. AMRAP identisch zu "Saetze & Wdh." aus - die Zeile
        // existiert ja gerade, damit der User seine Wahl auf einen Blick
        // wiederfindet, ohne jede Karte erneut aufzuklappen.
        if let format = config.timeFormat {
            parts.append(timedFormatDisplayName(format))
        }
        return parts.joined(separator: " · ")
    }

    /// `configControls`s Deckel greift nur, wenn eine BEREITS ausgewaehlte
    /// Karte aufgeklappt und ihr eigener Stepper bewegt wird. Ohne diesen
    /// zweiten Check koennte `selectKind` selbst die Summe ueber 7 treiben
    /// (jede neu hinzugefuegte Art bekommt via `max(1, ...)` mindestens
    /// einen Tag, auch wenn schon alle 7 Wochentage vergeben sind) - mit
    /// genau der stillen Truncation, vor der `configControls` warnt.
    private var canAddMoreDays: Bool { totalSelectedDays < 7 }

    private func selectKind(_ kind: TrainingTypeKind) {
        guard !selectedKinds.contains(kind), canAddMoreDays else { return }
        selectedKinds.append(kind)
        // README 2.20 Beispiel: "3 Tage Kettlebell, 45 Min." - gleiche Zahlen
        // als sinnvoller Startwert fuer jede neu hinzugefuegte Art. `guard`
        // oben garantiert bereits totalSelectedDays < 7, also ist
        // 7 - totalSelectedDays hier immer >= 1.
        configByKind[kind] = PlanGeneratorTypeSelection(
            kind: kind,
            daysPerWeek: min(3, 7 - totalSelectedDays),
            sessionDurationMinutes: 45,
            experience: .intermediate
        )
        expandedKind = kind
    }

    private func removeKind(_ kind: TrainingTypeKind) {
        selectedKinds.removeAll { $0 == kind }
        configByKind[kind] = nil
        if expandedKind == kind { expandedKind = nil }
    }

    private func updateConfig(
        _ kind: TrainingTypeKind,
        daysPerWeek: Int? = nil,
        sessionDurationMinutes: Int? = nil,
        experience: DifficultyLevel? = nil
    ) {
        guard let current = configByKind[kind] else { return }
        configByKind[kind] = PlanGeneratorTypeSelection(
            kind: kind,
            daysPerWeek: daysPerWeek ?? current.daysPerWeek,
            sessionDurationMinutes: sessionDurationMinutes ?? current.sessionDurationMinutes,
            experience: experience ?? current.experience,
            // Bugfix (README 2.35): ohne dieses Feld wuerde JEDE Aenderung
            // an Tagen/Dauer/Erfahrung ueber diese Funktion die zuvor
            // gewaehlte Zeitformat-Struktur stillschweigend auf "Saetze &
            // Wdh." zuruecksetzen, weil der Memberwise-Reconstruct sonst
            // keinen Wert dafuer mitgibt.
            timeFormat: current.timeFormat
        )
    }

    /// README 2.35: eigene, kleine Aktualisierungs-Funktion statt eines
    /// weiteren `updateConfig`-Parameters - `timeFormat` ist selbst optional
    /// (nil = "Saetze & Wdh."), ein `WorkoutTimeFormat? = nil`-Default-Param
    /// koennte "nicht angegeben" und "explizit auf nil setzen" nicht
    /// unterscheiden, ohne den gesamten Aufrufer auf einen doppelten
    /// Optional-Typ umzustellen.
    private func updateTimeFormat(_ kind: TrainingTypeKind, timeFormat: WorkoutTimeFormat?) {
        guard let current = configByKind[kind] else { return }
        configByKind[kind] = PlanGeneratorTypeSelection(
            kind: kind,
            daysPerWeek: current.daysPerWeek,
            sessionDurationMinutes: current.sessionDurationMinutes,
            experience: current.experience,
            timeFormat: timeFormat
        )
    }

    private func trainingTypeIcon(_ kind: TrainingTypeKind) -> String {
        switch kind {
        case .barbell:    return "figure.strengthtraining.traditional"
        case .dumbbell:   return "dumbbell"
        case .kettlebell: return "figure.strengthtraining.functional"
        case .bodyweight: return "figure.core.training"
        case .running:    return "figure.run"
        case .cycling:    return "bicycle"
        }
    }

    // MARK: - Schritt 1 (zielorientierter Pfad): Ziel waehlen (P3.1, Doc01 §3)

    private var goalStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("planBuilder.goal.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("planBuilder.goal.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(GoalCard.allCases, id: \.self) { card in
                    goalCardView(card)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func goalCardView(_ card: GoalCard) -> some View {
        let isSelected = selectedGoalCard == card
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedGoalCard = isSelected ? nil : card
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: card.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.deltiqOrange.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: String.LocalizationValue(card.titleKey), bundle: .module))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isSelected {
                            Text(String(localized: String.LocalizationValue(card.blurbKey), bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.down")
                        .font(isSelected ? .body : .caption.weight(.bold))
                        .foregroundStyle(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                if card == .strengthFocus {
                    strengthFocusPicker
                }
                if card.needsEnduranceModality {
                    enduranceModalitySubflow
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 1.5 : 1)
        )
    }

    /// Doc01 §3: "Kraft & Muskelaufbau" deckt beide bestehenden Core-Werte ab
    /// (`.hypertrophy`/`.strength`) - diese Karte entscheidet NUR zwischen den
    /// beiden, ersetzt keine der zwei bestehenden Zielkarten in
    /// `ProfileEditorView.coachingCard`.
    private var strengthFocusPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Picker("", selection: $strengthFocus) {
                Text("planBuilder.goal.strengthFocus.hypertrophy", bundle: .module).tag(TrainingGoal.hypertrophy)
                Text("planBuilder.goal.strengthFocus.strength", bundle: .module).tag(TrainingGoal.strength)
            }
            .pickerStyle(.segmented)
        }
    }

    /// Doc02 §2/§3: Ausdauerform klaeren, danach NUR bei einer Laufen-
    /// unterstuetzenden Modalitaet die Laufcoach-Frage zeigen (reines
    /// Radfahren braucht sie laut Zustandstabelle gar nicht). Bewusst
    /// auswahlbare Zeilen statt eines Segmented-Pickers mit kosmetischem
    /// Default - Doc02: "Keine unbekannte Auswahl still in Laufen umwandeln."
    private var enduranceModalitySubflow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("planBuilder.goal.enduranceModality", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(EnduranceModality.allCases, id: \.self) { modality in
                    selectableOptionRow(title: String(localized: modality.localizedName), isSelected: selectedEnduranceModality == modality) {
                        selectedEnduranceModality = modality
                        if !modality.supportsRunCoach { runCoachWanted = false }
                    }
                }
            }
            if let selectedEnduranceModality, selectedEnduranceModality.supportsRunCoach {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("planBuilder.goal.runCoach.question", bundle: .module)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    runCoachOptionRow(
                        titleKey: "planBuilder.goal.runCoach.withoutCoach.title",
                        blurbKey: "planBuilder.goal.runCoach.withoutCoach.blurb",
                        isSelected: !runCoachWanted
                    ) { runCoachWanted = false }
                    runCoachOptionRow(
                        titleKey: "planBuilder.goal.runCoach.withCoach.title",
                        blurbKey: "planBuilder.goal.runCoach.withCoach.blurb",
                        isSelected: runCoachWanted
                    ) { runCoachWanted = true }
                }
            }
        }
    }

    private func selectableOptionRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.deltiqOrange : Color.Deltiq.divider, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func runCoachOptionRow(titleKey: String, blurbKey: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: String.LocalizationValue(titleKey), bundle: .module))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(String(localized: String.LocalizationValue(blurbKey), bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.deltiqOrange : Color.Deltiq.divider, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// "Weiter"-Gate fuer den Ziel-Schritt: ein Ziel MUSS gewaehlt sein, und
    /// `.endurance`/`.hybrid` brauchen zusaetzlich eine explizite
    /// Ausdauerform-Antwort (siehe `enduranceModalitySubflow`-Doku).
    private var canAdvanceFromGoalStep: Bool {
        guard let card = selectedGoalCard else { return false }
        if card.needsEnduranceModality { return selectedEnduranceModality != nil }
        return true
    }

    // MARK: - Schritt 2 (zielorientierter Pfad): Alltagsrahmen (P3.1, Doc01 §3)

    private var alltagsrahmenStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("planBuilder.context.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("planBuilder.context.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Stepper(
                        pluralizedCount("planBuilder.wizard.daysPerWeek", count: totalDaysPerWeek),
                        value: $totalDaysPerWeek, in: 1...7
                    )
                    Stepper(
                        String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), sessionDurationMinutes),
                        value: $sessionDurationMinutes, in: 15...120, step: 5
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.wizard.experience", bundle: .module)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $experience) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                Text(level.localizedName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Divider()

                // Doc01 §3: "Trainingsort und Ausstattung als vorbefuellte
                // Zusammenfassung ... nicht erneut vollstaendig abfragen" -
                // Zeile statt der frueheren vollen Checkbox-Liste;
                // "Weitere Optionen nur bei Bedarf oeffnen" via
                // DisclosureGroup (dieselben Toggles wie zuvor, nur
                // eingeklappt, Aenderung gilt gemaess Doc01 §3 nur fuer
                // DIESEN Entwurf - kein globales Profilupdate).
                VStack(alignment: .leading, spacing: 8) {
                    Text("planBuilder.context.equipmentSummary.title", bundle: .module)
                        .font(.callout.weight(.semibold))
                    Text(equipmentSummaryLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    DisclosureGroup(isExpanded: $showEquipmentOverrideOptions) {
                        VStack(spacing: 8) {
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
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("planBuilder.context.equipmentSummary.adjustForThisPlan", bundle: .module)
                            .font(.caption.weight(.medium))
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.rhythm.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("planBuilder.rhythm.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Picker("", selection: $usesFixedWeekdays) {
                        Text("planBuilder.rhythm.orderOnly", bundle: .module).tag(false)
                        Text("planBuilder.rhythm.fixedWeekdays", bundle: .module).tag(true)
                    }
                    .pickerStyle(.segmented)
                    if usesFixedWeekdays {
                        weekdayGrid
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Liest den bereits erfassten Trainingsort direkt aus dem Profil (kein
    /// eigener State hier) - `profiles` ist bereits vorhanden fuer
    /// `adoptPlan()`s eigenstaendigen Pfad.
    private var equipmentSummaryLine: String {
        let envText = profiles.first.map { String(localized: $0.environment.localizedName) }
        let equipmentNames = Equipment.allCases
            .filter { $0 != .bodyweight && equipmentPreferences.contains($0) }
            .map { String(localized: $0.localizedName) }
        let equipmentText = equipmentNames.isEmpty
            ? String(localized: "planBuilder.context.equipmentSummary.bodyweightOnly", bundle: .module)
            : equipmentNames.joined(separator: ", ")
        return [envText, equipmentText].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Schritt 2: Ausruestung und Rhythmus

    private var equipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.equipment.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("planBuilder.equipment.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
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

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.rhythm.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("planBuilder.rhythm.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Picker("", selection: $usesFixedWeekdays) {
                        Text("planBuilder.rhythm.orderOnly", bundle: .module).tag(false)
                        Text("planBuilder.rhythm.fixedWeekdays", bundle: .module).tag(true)
                    }
                    .pickerStyle(.segmented)

                    // README 2.20 (29b): die Tagesauswahl steht sichtbar
                    // daneben statt hinter einer Einstellung versteckt zu
                    // sein - deshalb kein zusaetzliches Sheet, sondern
                    // inline sichtbar sobald "Feste Wochentage" gewaehlt ist.
                    if usesFixedWeekdays {
                        weekdayGrid
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Gleiches Muster wie `DayPickerSheet.dayGrid`/`dayRow` - Apple-Calendar-
    /// Wochentage (1=So...7=Sa), Mo-first angezeigt, Cap bei
    /// `totalSelectedDays`.
    private var weekdayGrid: some View {
        let calendar = Calendar.current
        let fullSymbols = calendar.standaloneWeekdaySymbols
        let shortSymbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdayLabels: [(weekday: Int, label: String, short: String)] = [2, 3, 4, 5, 6, 7, 1].map { wd in
            (weekday: wd, label: fullSymbols[wd - 1], short: shortSymbols[wd - 1])
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "dayPicker.prompt", bundle: .module), totalSelectedDays))
                .font(.caption)
                .foregroundStyle(fixedWeekdays.count == totalSelectedDays ? Color.deltiqOrange : Color.Deltiq.textSecondary)
            ForEach(weekdayLabels, id: \.weekday) { entry in
                weekdayRow(weekday: entry.weekday, label: entry.label, short: entry.short)
            }
        }
    }

    private func weekdayRow(weekday: Int, label: String, short: String) -> some View {
        let isSelected = fixedWeekdays.contains(weekday)
        let atCap = !isSelected && fixedWeekdays.count >= totalSelectedDays
        return Button {
            toggleWeekday(weekday)
        } label: {
            HStack(spacing: 12) {
                Text(short)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? Color.deltiqOrange : Color.Deltiq.fill))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.deltiqOrange : Color.Deltiq.divider, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(atCap)
        .opacity(atCap ? 0.4 : 1.0)
    }

    private func toggleWeekday(_ weekday: Int) {
        if fixedWeekdays.contains(weekday) {
            fixedWeekdays.remove(weekday)
        } else {
            guard fixedWeekdays.count < totalSelectedDays else { return }
            fixedWeekdays.insert(weekday)
        }
    }

    // MARK: - Schritt 3: die gerechnete Woche

    private var currentInput: PlanGeneratorInput {
        let selections: [PlanGeneratorTypeSelection]
        if isPreSeededFlow {
            selections = selectedKinds.compactMap { configByKind[$0] }
        } else {
            // P3.1 (Doc01 §3 "Ziel zuerst, nicht Langhantel-/Kurzhanteltage"):
            // `GoalDrivenPlanSelectionBuilder` uebersetzt Ziel + Alltagsrahmen
            // in dieselben `PlanGeneratorTypeSelection`-Eingaben, die der
            // UNVERAENDERTE `PlanGenerator` schon immer erwartet hat - siehe
            // dortige Typ-Doku.
            selections = GoalDrivenPlanSelectionBuilder.makeSelections(
                goal: selectedTrainingGoal ?? .hybrid,
                enduranceModality: selectedEnduranceModality,
                totalDaysPerWeek: totalDaysPerWeek,
                sessionDurationMinutes: sessionDurationMinutes,
                experience: experience,
                equipmentPreferences: equipmentPreferences
            )
        }
        return PlanGeneratorInput(
            selections: selections,
            equipmentPreferences: equipmentPreferences,
            usesFixedWeekdays: usesFixedWeekdays,
            fixedWeekdays: Array(fixedWeekdays)
        )
    }

    /// P2.4 Punkt 5: ein blosses erneutes Betreten von Schritt 3 (zurueck zu
    /// Schritt 1/2 und wieder vor, OHNE dort etwas zu aendern) darf den
    /// bestehenden Entwurf NICHT mit neuen `DraftDayID`s rekonstruieren -
    /// deshalb der fruehe `guard`. Ein echter Input-Wechsel (Schritt 1/2
    /// tatsaechlich geaendert) ist dagegen bewusst eine NEUE Generierung
    /// (Typ-Doku Punkt 6) und baut den Draft komplett neu auf.
    ///
    /// P3.3: der fruehere `shuffle`-Parameter (fuer den globalen "Neu
    /// rechnen"-Button) ist mit dessen Entfernung entfallen - Alternativen
    /// laufen jetzt ausschliesslich gezielt pro Tag ueber
    /// `PlanGenerator.targetedAlternatives`/`presentAlternatives`.
    private func generatePreviewIfNeeded() {
        guard draft == nil || lastGeneratedInput != currentInput else { return }

        let input = currentInput
        let generated = PlanGenerator.generate(from: input)
        let newDraft = PlanDraft(generated: generated.days.map(\.spec))
        // `PlanDraft.init(generated:)` sortiert nach `sequenceIndex` - hier
        // identisch sortieren statt sich auf eine unausgesprochene
        // Reihenfolge-Annahme von `generated.days` selbst zu verlassen, damit
        // das `zip` unten garantiert Tag-zu-Tag korrekt paart.
        let sortedBySequence = generated.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }
        draft = newDraft
        loadLevelByDayID = Dictionary(
            uniqueKeysWithValues: zip(newDraft.days, sortedBySequence).map { ($0.id, $1.loadLevel) }
        )
        explanationKey = generated.explanationKey
        lastGeneratedInput = input
    }

    /// Reines Anzeige-Lookup fuer `resultDayRow`s Badge - bewusst OHNE
    /// `.medium`-Default (Nachbesserung, "kein stilles .medium fuer
    /// fehlende Zuordnung"). `nil` heisst "fuer diesen Tag nicht bewertet"
    /// und wird in `resultDayRow` als eigener, neutraler Badge-Zustand
    /// angezeigt statt eine Einordnung vorzutaeuschen, die es nicht gibt.
    /// Heute IMMER non-nil (siehe `generatePreviewIfNeeded`: jeder Tag im
    /// Draft bekommt dort exakt einen Eintrag) - wird erst relevant, sobald
    /// P3 Tage ohne vollstaendige Neugenerierung aendert/einfuegt.
    private func loadLevel(for dayID: DraftDayID) -> PlanLoadLevel? {
        loadLevelByDayID[dayID]
    }

    /// P5.2 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): nur im zielorientierten
    /// Einstieg (`selectedTrainingGoal != nil`) relevant — das ist genau der
    /// Pfad, der beim Uebernehmen jetzt tatsaechlich `PlanSelectionResolver.
    /// resolve` durchlaeuft (siehe `adoptPlan()`). Zeigt den Status VOR jeder
    /// Anpassung (reine `PlanEquipmentChecker`-Pruefung, keine Substitutions-
    /// Simulation hier in der UI) — ehrlich als "so sieht es roh aus",
    /// nicht als Vorwegnahme des Anpassungsergebnisses beim Adopt.
    private var builderEquipmentStatus: PlanEquipmentStatus? {
        guard selectedTrainingGoal != nil, let profile = profiles.first,
              let days = currentResult?.days.map(\.spec), !days.isEmpty
        else { return nil }
        let effectiveProfile = EquipmentPlanningResolver.resolve(
            environment: profile.environment,
            individualProfile: profile.equipmentProfile,
            confirmedComplete: profile.equipmentProfileConfirmedComplete
        ).effectiveProfile
        return PlanEquipmentChecker.check(days: days, against: effectiveProfile)
    }

    @ViewBuilder
    private func builderEquipmentStatusRow(_ status: PlanEquipmentStatus) -> some View {
        let (icon, tint, titleKey): (String, Color, String) = switch status {
        case .available:    ("checkmark.circle.fill", .green, "picker.plan.equipment.available.title")
        case .unknown:      ("questionmark.circle.fill", .orange, "picker.plan.equipment.unknown.title")
        case .unavailable:  ("exclamationmark.triangle.fill", .red, "picker.plan.equipment.unavailable.title")
        }
        Label {
            // `titleKey` ist ein zur Laufzeit gewaehlter Schluesselname, kein
            // Compile-Zeit-Literal - `Text(_:bundle:)` erwartet aber ein
            // `LocalizedStringKey`, das sich NICHT implizit aus einer
            // Laufzeit-`String`-Variable ergibt (Apple-only Fehler, Linux
            // SwiftUI-Stub akzeptiert das faelschlich - gleiche Art Divergenz
            // wie der P3.2-Fund). `String.LocalizationValue` ist der
            // etablierte Weg dafuer in dieser Datei/Codebase.
            Text(String(localized: String.LocalizationValue(titleKey), bundle: .module))
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .font(.subheadline.weight(.medium))
    }

    /// P2.4 Punkt 8: die Vorschau UND die Uebergabe an `onGenerated`/
    /// `PlanGeneratorInstantiator.createPlan` muessen den tatsaechlich
    /// bearbeiteten `draft` darstellen - ein bearbeiteter Draft darf beim
    /// Uebernehmen nicht durch das alte, unveraenderte Generatorresultat
    /// ersetzt werden. Rekonstruiert deshalb bei jedem Zugriff frisch aus
    /// `draft` statt ein zweites, potenziell veraltetes `Result` separat
    /// vorzuhalten. `onGenerated`s Signatur bleibt dadurch unveraendert -
    /// siehe Typ-Doku.
    ///
    /// Nachbesserung: nutzt jetzt denselben `PlanDraftResultAdapter` (Core),
    /// den auch `PlanDraftResultAdapterTests` direkt prueft - vorher war
    /// dieselbe Rekonstruktion hier inline und fuer sich nicht testbar.
    /// `try?`: heute sicher, weil `loadLevelByDayID` jeden Tag im Draft
    /// abdeckt (siehe `generatePreviewIfNeeded`), der Adapter also nie
    /// `missingLoadLevel` wirft - der Fehler ist absichtlich NICHT in einen
    /// `.medium`-Fallback uebersetzt. Sobald P3 einen Weg einfuehrt, der
    /// diese Abdeckung brechen kann, muss dieser Fehler sichtbar behandelt
    /// werden statt in `nil` zu verschwinden (siehe Adapter-Doku).
    private var currentResult: PlanGenerator.Result? {
        guard let draft else { return nil }
        return try? PlanDraftResultAdapter.makeResult(
            from: draft, loadLevels: loadLevelByDayID, explanationKey: explanationKey
        )
    }

    /// A12 (Paket 1, docs/DELTIQ_DEVICE_ACCEPTANCE.md): sichtbarer Hinweis
    /// statt des stillen Weglassens einer gewaehlten Sportart - UND blockiert
    /// die Uebernahme (siehe `headerActions`s Checkmark-`isDisabled`), bis
    /// der Nutzer aktiv etwas aendert (Tage ueber `alltagsrahmenStep`, oder
    /// Ziel/Ausdauerform ueber `goalStep` - beide ueber die bestehende
    /// Zurueck-Navigation erreichbar, kein eigener Konflikt-Assistent
    /// noetig). Keine Sportart gilt allein durch einen allgemeinen
    /// Uebernehmen-Tap als abgewaehlt. Nur im Ziel-gefuehrten Pfad relevant
    /// (`isPreSeededFlow` waehlt Tage/Art direkt, kein Disziplinen-Konflikt
    /// moeglich). `nil`, solange kein Ziel/keine Ausdauerform gewaehlt ist -
    /// derselbe Default-Fallback wie
    /// `GoalDrivenPlanSelectionBuilder.makeSelections` selbst.
    private var distributionConflict: GoalDrivenPlanSelectionBuilder.DistributionConflict? {
        guard !isPreSeededFlow, let goal = selectedTrainingGoal else { return nil }
        return GoalDrivenPlanSelectionBuilder.distributionConflict(
            goal: goal, enduranceModality: selectedEnduranceModality, totalDaysPerWeek: totalDaysPerWeek
        )
    }

    /// P3.2 (Audit "Wochenuebersicht-UI + Drag&Drop + 'Verschieben nach...'"):
    /// `List`+`.onMove` statt der bisherigen reinen `ScrollView`-Liste - der
    /// EINE native Mechanismus, der Drag&Drop UND eine darauf aufbauende
    /// Barrierefreiheits-Alternative (VoiceOver bekommt automatisch
    /// "nach oben/unten verschieben"-Stellvertreteraktionen fuer `.onMove`)
    /// ohne Custom-Gesture-Code liefert - identisches Muster wie
    /// `PlanEditorView.daysSection`/`moveDays`. Zusaetzlich zur impliziten
    /// VoiceOver-Aktion bekommt jede Zeile ein explizites, sichtbares
    /// "Verschieben nach..."-Menu (Abnahme verlangt eine ZUGAENGLICHE
    /// Alternative, nicht nur eine implizite) + die Fixierungs-UI (P3.2,
    /// Inhalt/Position getrennt, siehe `PlanDraft.setContentFixed`/
    /// `setPositionFixed`).
    private var resultStepView: some View {
        Group {
            if let draft, !draft.days.isEmpty {
                List {
                    if let conflict = distributionConflict {
                        Section {
                            Text(String(
                                format: String(localized: "planBuilder.result.distributionConflict", bundle: .module),
                                conflict.requiredDays, conflict.availableDays
                            ))
                            .font(.callout)
                            .foregroundStyle(.primary)
                        }
                        .listRowBackground(Color.red.opacity(0.1))
                    }

                    if let explanationKey {
                        Section {
                            Text(String(localized: String.LocalizationValue(explanationKey), bundle: .module))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.deltiqOrange.opacity(0.08))
                    }

                    if let builderEquipmentStatus {
                        Section {
                            builderEquipmentStatusRow(builderEquipmentStatus)
                        }
                    }

                    Section {
                        // `DraftDay` ist `Identifiable` (stabile `DraftDayID`)
                        // - kein `.offset`-Hilfsindex noetig.
                        ForEach(draft.days) { day in
                            resultDayRow(day, loadLevel: loadLevel(for: day.id))
                        }
                        .onMove(perform: moveDraftDays)
                    } footer: {
                        Text(String(format: String(localized: "planBuilder.result.weeklyTotal", bundle: .module), weeklyTotalTimeLabel))
                    }

                }
                .scrollContentBackground(.hidden)
                // P3.3 (Audit "Gezielte Alternativen statt globalem
                // Shuffle"): ersetzt den frueheren globalen "Neu rechnen"-
                // Button, der die GESAMTE Woche neu mischte und damit jede
                // manuelle Fixierung/Aenderung an ANDEREN Tagen unsichtbar
                // mit wegspuelte (Abnahme B04). Pro Tag jetzt ueber das
                // "Alternativen"-Menu in `resultDayRow` erreichbar.
                .confirmationDialog(
                    Text("planBuilder.result.alternatives.title", bundle: .module),
                    isPresented: Binding(
                        get: { alternativesDialogDayID != nil },
                        set: { if !$0 { alternativesDialogDayID = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    ForEach(Array(currentAlternativeOptions.enumerated()), id: \.offset) { _, alternative in
                        Button(alternative.displayName) {
                            if let dayID = alternativesDialogDayID {
                                applyAlternative(alternative, to: dayID)
                            }
                            alternativesDialogDayID = nil
                        }
                    }
                    Button(role: .cancel) {
                        alternativesDialogDayID = nil
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let footerToastMessage {
                        Label(footerToastMessage, systemImage: footerToastSystemImage)
                            .font(.caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                ContentUnavailableViewCompat(
                    title: String(localized: "planBuilder.result.empty.title", bundle: .module),
                    message: String(localized: "planBuilder.result.empty.message", bundle: .module)
                )
                .padding(.top, 40)
            }
        }
        .onAppear {
            // `generatePreviewIfNeeded` traegt die "nur wenn noetig"-Pruefung
            // selbst (siehe dortige Doku) - ein erneutes `.onAppear` nach
            // Zurueck/Vor ohne Aenderung baut den Draft deshalb nicht neu auf.
            generatePreviewIfNeeded()
        }
    }

    /// `.onMove`-Handler fuer die Tages-`List` - `destination` ist (wie bei
    /// `Array.move(fromOffsets:toOffset:)`, siehe `PlanEditorView.moveDays`
    /// fuer das identische Muster) bereits der Ziel-Index NACH der Entnahme,
    /// exakt die Semantik, die `PlanDraft.moveDay(_:toIndex:)` erwartet.
    private func moveDraftDays(from source: IndexSet, to destination: Int) {
        guard var currentDraft = draft, let sourceIndex = source.first else { return }
        let movedDay = currentDraft.days[sourceIndex]
        if currentDraft.moveDay(movedDay.id, toIndex: destination) {
            draft = currentDraft
        } else {
            // Entwurf bleibt unveraendert (siehe `PlanDraft.reorder(to:)`) -
            // die Zeile "springt" dadurch sichtbar an ihren alten Platz
            // zurueck statt sich lautlos nicht zu bewegen (Abnahme B01).
            showReorderRejectedToast()
        }
    }

    /// Das explizite "Verschieben nach..."-Menu - die von der Abnahme
    /// verlangte ZUGAENGLICHE Alternative zum Drag-Gesture, erreichbar per
    /// Tap statt Long-Press/Drag (hilft z.B. bei Switch Control/Voice
    /// Control, nicht nur VoiceOver).
    private func moveDraftDay(_ id: DraftDayID, toIndex newIndex: Int) {
        guard var currentDraft = draft else { return }
        if currentDraft.moveDay(id, toIndex: newIndex) {
            draft = currentDraft
        } else {
            showReorderRejectedToast()
        }
    }

    private func showReorderRejectedToast() {
        showFooterToast(
            String(localized: "planBuilder.result.reorderRejected.toast", bundle: .module),
            systemImage: "pin.slash.fill"
        )
    }

    private func showFooterToast(_ message: String, systemImage: String) {
        withAnimation {
            footerToastMessage = message
            footerToastSystemImage = systemImage
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { footerToastMessage = nil }
        }
    }

    /// P3.3: zeigt bis zu 3 gezielte Alternativen fuer GENAU DIESEN Tag
    /// (`PlanGenerator.targetedAlternatives`) ueber den `.confirmationDialog`
    /// in `resultStepView`. `.noAlternativesAvailable` (Cardio-Tag oder zu
    /// keiner Auswahl zuordenbar) bekommt den SICHTBAREN Konflikt-Toast
    /// statt eines stillen No-Ops (Abnahme B05).
    private func presentAlternatives(for day: DraftDay) {
        let spec = day.spec(sequenceIndex: 1)
        switch PlanGenerator.targetedAlternatives(for: spec, input: currentInput, count: 3) {
        case .alternatives(let alternatives):
            currentAlternativeOptions = alternatives
            alternativesDialogDayID = day.id
        case .noAlternativesAvailable:
            showFooterToast(
                String(localized: "planBuilder.result.noAlternatives.toast", bundle: .module),
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    /// Ersetzt NUR den Inhalt von `dayID` (`PlanDraft.replaceContent`,
    /// verweigert bereits selbst bei `isContentFixed`) - alle anderen Tage
    /// bleiben unangetastet (Abnahme B04). `loadLevelByDayID`s bisheriger
    /// Eintrag fuer diesen Tag bezog sich auf die ALTEN Uebungen und wird
    /// deshalb entfernt statt stehen gelassen - ein veralteter Belastungs-
    /// Badge waere schlimmer als der bereits unterstuetzte "nicht bewertet"-
    /// Zustand (siehe `loadLevel(for:)`-Doku).
    private func applyAlternative(_ alternative: DaySpec, to dayID: DraftDayID) {
        guard var currentDraft = draft else { return }
        guard currentDraft.replaceContent(of: dayID, with: alternative) else { return }
        loadLevelByDayID.removeValue(forKey: dayID)
        draft = currentDraft
    }

    /// P3.3-Restaufgabe #205 ("Woche anders verteilen"): ruft denselben
    /// Generator mit DEMSELBEN Input erneut auf (`shuffle: true` - identisch
    /// zum etablierten Bugfix-Parameter, der schon fuer Einzeltag-
    /// Alternativen den Uebungs-Pool neu mischt, siehe
    /// `PlanGenerator.generate`-Doku) und delegiert die eigentliche,
    /// fixierungs-sichere Anwendung an `PlanDraft.redistributeUnfixedDays` -
    /// KEINE zweite Planungsengine, nur ein zweiter Aufruf derselben. Jeder
    /// content-fixierte Tag bleibt dabei unangetastet; `isPositionFixed`
    /// ist fuer diese reine Inhaltsersetzung irrelevant (kein Tag wechselt
    /// seinen Index). Ein Fehlschlag (z.B. alle Tage content-fixiert) zeigt
    /// denselben sichtbaren Konflikt-Toast wie eine abgelehnte Verschiebung
    /// oder eine nicht verfuegbare Einzel-Alternative, statt eines stillen
    /// No-Ops.
    private func redistributeWeek() {
        guard var currentDraft = draft else { return }
        // Reihenfolge VOR der Mutation einfrieren - `redistributeUnfixedDays`
        // konsumiert den `newDaySpecs`-Pool in genau dieser Array-Reihenfolge
        // (siehe dortige Doku), damit `loadLevelByDayID` unten korrekt paart.
        let affectedIDsInOrder = currentDraft.days.filter { !$0.isContentFixed }.map(\.id)
        let generated = PlanGenerator.generate(from: currentInput, shuffle: true)
        guard !generated.days.isEmpty else {
            showWeekGenerationUnavailableToast()
            return
        }
        let sortedBySequence = generated.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }
        guard currentDraft.redistributeUnfixedDays(using: sortedBySequence.map(\.spec)) else {
            showWeekGenerationUnavailableToast()
            return
        }
        for (id, generatedDay) in zip(affectedIDsInOrder, sortedBySequence) {
            loadLevelByDayID[id] = generatedDay.loadLevel
        }
        draft = currentDraft
    }

    /// Gemeinsamer Konflikt-Toast fuer #205 ("Woche anders verteilen", z.B.
    /// alle Tage content-fixiert) UND #206 ("Vorschlag neu erstellen", z.B.
    /// der Generator liefert fuer `currentInput` ueberraschend keine Tage
    /// mehr) - beide sind der gleiche fachliche Fall ("kein neuer Vorschlag
    /// moeglich"), verdienen deshalb keine zwei fast identischen Strings.
    private func showWeekGenerationUnavailableToast() {
        showFooterToast(
            String(localized: "planBuilder.result.redistribute.unavailable.toast", bundle: .module),
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    /// P3.3-Restaufgabe #206 ("Vorschlag neu erstellen"): anders als #205
    /// ersetzt dies die GESAMTE Woche inkl. fixierter/manuell geaenderter
    /// Tage - deshalb erst `draft.hasAnyFixation` pruefen und bei `true`
    /// eine AUSDRUECKLICHE Bestaetigung einholen (`showingFreshProposalConfirm`,
    /// Vorgabe dieser Runde: "keine stillen Resets"). Ohne jede Fixierung
    /// gibt es nichts zu verlieren - dann direkt `performFreshProposal()`.
    private func requestFreshProposal() {
        guard let draft else { return }
        if draft.hasAnyFixation {
            showingFreshProposalConfirm = true
        } else {
            performFreshProposal()
        }
    }

    /// Fuehrt den in `requestFreshProposal()` (ggf. nach Bestaetigung)
    /// entschiedenen kompletten Neu-Vorschlag aus - identischer Aufbau wie
    /// `generatePreviewIfNeeded()` (frisches `PlanDraft(generated:)`, neue
    /// `loadLevelByDayID`-Zuordnung, neuer `explanationKey`), nur mit
    /// `shuffle: true` statt des deterministischen Erst-Aufrufs, damit ein
    /// wiederholter Tap tatsaechlich einen ANDEREN Vorschlag liefert statt
    /// immer wieder denselben. `lastGeneratedInput` bleibt unveraendert -
    /// die Trainingsart-/Equipment-Auswahl selbst hat sich nicht geaendert,
    /// nur der daraus gezogene Vorschlag.
    private func performFreshProposal() {
        let input = currentInput
        let generated = PlanGenerator.generate(from: input, shuffle: true)
        guard !generated.days.isEmpty else {
            showWeekGenerationUnavailableToast()
            return
        }
        let sortedBySequence = generated.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }
        let newDraft = PlanDraft(generated: sortedBySequence.map(\.spec))
        draft = newDraft
        loadLevelByDayID = Dictionary(
            uniqueKeysWithValues: zip(newDraft.days, sortedBySequence).map { ($0.id, $1.loadLevel) }
        )
        explanationKey = generated.explanationKey
    }

    private func toggleContentFixed(for id: DraftDayID) {
        guard var currentDraft = draft, let idx = currentDraft.index(of: id) else { return }
        currentDraft.setContentFixed(!currentDraft.days[idx].isContentFixed, for: id)
        draft = currentDraft
    }

    private func togglePositionFixed(for id: DraftDayID) {
        guard var currentDraft = draft, let idx = currentDraft.index(of: id) else { return }
        currentDraft.setPositionFixed(!currentDraft.days[idx].isPositionFixed, for: id)
        draft = currentDraft
    }

    private func resultDayRow(_ day: DraftDay, loadLevel: PlanLoadLevel?) -> some View {
        // `sequenceIndex` ist fuer die reine Anzeige irrelevant (weder
        // `displayName` noch `scopeLine` lesen ihn) - die tatsaechliche
        // Position liefert `draft.resolvedDaySpecs` erst bei der Uebergabe
        // (`currentResult`).
        let spec = day.spec(sequenceIndex: 1)
        let currentIndex = draft?.index(of: day.id) ?? 0
        let totalDays = draft?.days.count ?? 0
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // DEL-247: `displayName` statt `.name` - loest den seit
                    // DEL-247 gesetzten `localizationKey` auf, damit die
                    // Wizard-Vorschau selbst schon in EN/TR korrekt anzeigt
                    // statt erst nach dem Adopt (wo `TrainingDay.displayName`
                    // das ohnehin schon tat).
                    Text(spec.displayName)
                        .font(.body.weight(.semibold))
                    // P3.2 Fixierungs-UI: sichtbare Badges fuer sehende
                    // Nutzer, zusaetzlich zur Ansage in `accessibilityLabel`
                    // unten - ein fixierter Tag soll nicht erst ueber das
                    // Menu entdeckt werden muessen.
                    if day.isPositionFixed {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.deltiqOrange)
                    }
                    if day.isContentFixed {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(scopeLine(for: spec))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Nachbesserung: `loadLevel == nil` ("nicht bewertet") bekommt
            // einen eigenen, neutralen Badge statt eine Haerte-Einordnung
            // vorzutaeuschen - siehe `loadLevel(for:)`-Doku. Heute nie
            // sichtbar (jeder Draft-Tag hat eine Zuordnung), erst relevant
            // ab P3.
            if let loadLevel {
                Text(loadLevel.localizedName)
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(loadLevelColor(loadLevel).opacity(0.16))
                    .foregroundStyle(loadLevelColor(loadLevel))
                    .clipShape(Capsule())
            } else {
                Text("planBuilder.result.loadLevel.unrated", bundle: .module)
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.16))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
            // P3.2: explizites, per Tap erreichbares Menu - die von der
            // Abnahme (B01) verlangte ZUGAENGLICHE Alternative zum Drag-
            // Gesture (nicht nur die implizite VoiceOver-Reorder-Aktion, die
            // `.onMove` bereits automatisch liefert), plus die Fixierungs-UI.
            Menu {
                if totalDays > 1 {
                    Menu {
                        ForEach(0..<totalDays, id: \.self) { targetIndex in
                            if targetIndex != currentIndex {
                                Button {
                                    moveDraftDay(day.id, toIndex: targetIndex)
                                } label: {
                                    Text(String(format: String(localized: "planBuilder.result.moveTo.position", bundle: .module), targetIndex + 1))
                                }
                            }
                        }
                    } label: {
                        Label {
                            Text("planBuilder.result.moveTo", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                Button {
                    togglePositionFixed(for: day.id)
                } label: {
                    Label {
                        Text(day.isPositionFixed ? "planBuilder.result.fixPosition.unlock" : "planBuilder.result.fixPosition.lock", bundle: .module)
                    } icon: {
                        Image(systemName: day.isPositionFixed ? "pin.slash" : "pin")
                    }
                }
                Button {
                    toggleContentFixed(for: day.id)
                } label: {
                    Label {
                        Text(day.isContentFixed ? "planBuilder.result.fixContent.unlock" : "planBuilder.result.fixContent.lock", bundle: .module)
                    } icon: {
                        Image(systemName: day.isContentFixed ? "lock.open" : "lock")
                    }
                }
                // P3.3: ersetzt den frueheren globalen "Neu rechnen"-Button -
                // gezielt NUR fuer diesen einen Tag, respektiert
                // `isContentFixed` (PlanDraft.replaceContent verweigert dort
                // ohnehin, aber ein deaktivierter Menueeintrag zeigt das
                // schon VOR dem Tap statt erst danach).
                Button {
                    presentAlternatives(for: day)
                } label: {
                    Label {
                        Text("planBuilder.result.alternatives", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.2.squarepath")
                    }
                }
                .disabled(day.isContentFixed)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
                    .padding(.leading, 4)
            }
            .accessibilityLabel(Text("planBuilder.result.dayActions", bundle: .module))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(resultDayRowAccessibilityLabel(spec: spec, day: day, loadLevel: loadLevel))
    }

    /// Fasst Name/Umfang/Belastung/Fixierungsstatus in EINER Ansage zusammen
    /// (statt vier Einzel-Elementen, die VoiceOver-Nutzer per Swipe
    /// nacheinander abhoeren muessten) - die Fixierungs-Icons oben sind rein
    /// visuell (`Image(systemName:)` ohne eigenes Label), ihr Zustand muss
    /// deshalb hier explizit in Worten stehen.
    private func resultDayRowAccessibilityLabel(spec: DaySpec, day: DraftDay, loadLevel: PlanLoadLevel?) -> String {
        var parts = [spec.displayName, scopeLine(for: spec)]
        if let loadLevel {
            // Apple-CI-Fund: `PlanLoadLevel.localizedName` liefert
            // `LocalizedStringResource`, nicht `String` - auf Linux (dieser
            // Datei-Toolchain) klaffte das klaffenlos zu `[String]`
            // zusammen, Xcode (Apple-CI) lehnte es zu Recht ab. Gleiches
            // Muster wie ueberall sonst im Code (`String(localized: env.
            // localizedName)`, z.B. `PlanEditorView.swift:439`).
            parts.append(String(localized: loadLevel.localizedName))
        }
        if day.isPositionFixed {
            parts.append(String(localized: "planBuilder.result.fixed.position.badge", bundle: .module))
        }
        if day.isContentFixed {
            parts.append(String(localized: "planBuilder.result.fixed.content.badge", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    private func loadLevelColor(_ level: PlanLoadLevel) -> Color {
        switch level {
        case .easy:   return .green
        case .medium: return Color.deltiqOrange
        // README 2.21: System-`.orange` (#FF9500) lag fast auf `deltiqOrange`
        // (#FF9F0A) - vier Stufen, aber nur drei unterscheidbare Farben.
        // Eigener, deutlich dunklerer Brand-Ton statt System-Orange.
        case .hard:   return Color(red: 0.80, green: 0.35, blue: 0.05)
        case .tough:  return .red
        }
    }

    private func scopeLine(for spec: DaySpec) -> String {
        if let timeFormat = spec.timeFormat {
            let capText = spec.timeCapMinutes.map { String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), $0) } ?? ""
            return [timedFormatDisplayName(timeFormat), capText].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        if spec.exercises.count == 1, let exercise = spec.exercises.first, exercise.isCardio {
            if let duration = exercise.targetDurationMinutes {
                return String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), duration)
            }
            if let distance = exercise.targetDistanceKm {
                // README 2.21: "%.1f km" ohne Locale ("0.4 km" statt "0,4 km"
                // auf Deutsch) - gleiche Bug-Familie wie der RIR-Punkt aus
                // 2.18, fuenfte Fundstelle. `formattedOneDecimal` (locale-
                // aware) plus reiner Einheiten-String statt `String(format:)`.
                return "\(distance.formattedOneDecimal) km"
            }
        }
        return pluralizedCount("planBuilder.wizard.exerciseCount", count: spec.exercises.count)
    }

    private var weeklyTotalTimeLabel: String {
        let totalMinutes = selectedKinds.reduce(0) { sum, kind in
            guard let config = configByKind[kind] else { return sum }
            return sum + config.daysPerWeek * config.sessionDurationMinutes
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%lld:%02lld", hours, minutes)
    }

    // MARK: - Navigation

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step != .types {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("common.back", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            // P3.4-Nachbesserung: "Trainingsplan uebernehmen"/"retryResolve"
            // sitzt jetzt als Haken im Header (`headerActions`) statt hier
            // unten — identisches Prinzip wie der Checkmark-Save in
            // `PlanEditorView`/`BodyDataEditorView`, kein zweiter,
            // redundanter Commit-Button auf demselben Screen. Auf dem
            // Ergebnis-Schritt bleibt rechts deshalb bewusst leer, nur
            // "Zurueck" links bleibt erreichbar.
            if step != .result {
                Button {
                    goToNextStep()
                } label: {
                    Label {
                        Text("planBuilder.nav.next", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .types && (isPreSeededFlow ? selectedKinds.isEmpty : !canAdvanceFromGoalStep))
            }
        }
    }

    private func goToNextStep() {
        guard let next = BuilderStep(rawValue: step.rawValue + 1) else { return }
        if next == .result { generatePreviewIfNeeded() }
        step = next
    }

    private func goToPreviousStep() {
        guard let prev = BuilderStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    /// Siehe `onEnduranceModalityChosen`-Doku und `adoptPlan()`s Aufrufstelle
    /// im eigenstaendigen Modus.
    private func applyEnduranceModalityChoiceIfNeeded(to profile: UserBodyProfile) {
        guard !isPreSeededFlow, let goal = selectedTrainingGoal, goal == .endurance || goal == .hybrid else { return }
        profile.setEnduranceModality(selectedEnduranceModality, runCoachEnabled: runCoachWanted)
    }

    private func adoptPlan() {
        // Bugfix (Nutzer-Feedback, "Neu rechnen"-Shuffle): der bereits in
        // Schritt 3 angezeigte Entwurf wird durchgereicht statt neu zu
        // rechnen (und damit wieder deterministisch, ohne Shuffle) - sonst
        // wuerde ein zuvor per "Neu rechnen" gefundener, dem User
        // zusagender Plan beim Uebernehmen durch die urspruengliche
        // Variante ersetzt. `currentResult` rekonstruiert dafuer IMMER aus
        // `draft` (P2.4 Punkt 8) - der Knopf ist disabled, solange `draft`
        // leer/nil ist (siehe `navigationBar`), das `guard` hier ist die
        // gemeinsame Absicherung fuer BEIDE Pfade unten.
        guard let result = currentResult else { return }

        // Nachbesserung (P2.3): Doppel-Tap-Schutz, siehe `isAdopting`-Doku.
        guard !isAdopting else { return }
        isAdopting = true

        // P3.1 (Doc01 §6: "Profilentscheidung und Plananpassung sind
        // getrennt"): eine im Ziel-Schritt getroffene Ausdauerform-/
        // Laufcoach-Entscheidung gilt unabhaengig vom Erfolg der
        // Plan-Erstellung als vom Nutzer bestaetigt - im `onGenerated`-Pfad
        // (kein lokaler `profile`-Zugriff, siehe Typ-Doku) meldet diese View
        // die Entscheidung stattdessen an den Aufrufer zurueck.
        if !isPreSeededFlow, let goal = selectedTrainingGoal, goal == .endurance || goal == .hybrid {
            onEnduranceModalityChosen?(selectedEnduranceModality, runCoachWanted)
        }

        // DEL-243: siehe Typ-Doku - `onGenerated`
        // uebernimmt hier NICHT das Instanziieren, sondern reicht Input +
        // Ergebnis nur nach oben durch.
        //
        // Nachbesserung (zweite Korrekturrunde, Punkt C) + dritte Korrekturrunde (Punkt 4):
        // `dismiss()` laeuft nur noch bei `.success`. `onGenerated` meldet jetzt einen
        // TYPISIERTEN `PlanBuilderHandoffOutcome` zurueck, nicht nur einen fertigen Text - diese
        // View leitet ihre eigene, bereits lokalisierte Nachricht selbst daraus ab. Bei
        // `.committedButUnresolved` bleibt das Sheet (mit dem bearbeiteten Entwurf) offen UND
        // der Haupt-Button zeigt ab jetzt "Erneut versuchen" statt "Plan uebernehmen" (siehe
        // `navigationBar`) - die eigentliche Duplikat-Sicherheit liegt beim Aufrufer (der dafuer
        // eine eigene `PlanCreationOperation` haelt, siehe `CardioFeasibilityCardModel`-Aufrufer).
        if let onGenerated {
            switch onGenerated(currentInput, result) {
            case .success:
                isAdopting = false
                dismiss()
            case .failedBeforeCommit:
                isAdopting = false
                adoptSaveErrorIsCreatedButUnresolved = false
                adoptSaveErrorMessage = String(localized: "planBuilder.error.saveFailed.message", bundle: .module)
            case .committedButUnresolved:
                isAdopting = false
                adoptSaveErrorIsCreatedButUnresolved = true
                externalHandoffIsCommittedButUnresolved = true
                adoptSaveErrorMessage = String(localized: "planBuilder.error.createdButUnresolved.message", bundle: .module)
            }
            return
        }

        // Audit-Korrektur (Review nach P2.1): kein Profil → expliziter
        // Fehlerzustand statt einer erfundenen `.gym`-Annahme. Dieser Zweig
        // ist nur im eigenstaendigen Modus (`onGenerated == nil`) erreichbar —
        // der Onboarding-Callback-Pfad oben ist bereits vorher zurueckgekehrt
        // und braucht kein Profil.
        guard let profile = profiles.first else {
            missingProfileErrorMessage = String(localized: "planBuilder.error.noProfile.message", bundle: .module)
            isAdopting = false
            return
        }

        // P3.1: im eigenstaendigen Modus (kein `onGenerated`, z.B.
        // `PlansListView`s "+") gibt es keinen externen Aufrufer, der
        // `onEnduranceModalityChosen` auswerten koennte - diese View schreibt
        // die Entscheidung deshalb direkt selbst (siehe Doku oben).
        applyEnduranceModalityChoiceIfNeeded(to: profile)

        // Nachbesserung (P2.3): `createPlan(for:)` buendelt Equipment-
        // Aufloesung + `build(...)` an einer Stelle statt hier erneut
        // `equipmentPlanningContext` separat abzufragen — siehe dortige Doku.
        //
        // Nachbesserung (Task #197, dritte Korrekturrunde): `creationOperation.attempt(...)`
        // ersetzt das vorherige direkte `do/catch` um `createPlan` - sobald einmal
        // `.committedButUnresolved` aufgetreten ist, ruft diese Instanz `create()` NIE WIEDER
        // auf (siehe `PlanCreationOperation`-Typ-Doku). Ein erneuter Tap auf denselben Button
        // (jetzt als "Erneut versuchen" beschriftet, siehe `navigationBar`) loest dann
        // ausschliesslich ueber `resolveCreatedPlan` auf - niemals ein zweiter Plan.
        switch creationOperation.attempt(in: modelContext, create: {
            // P5.2: `selectedTrainingGoal` ist nur im zielorientierten
            // Einstieg (P3.1) non-nil — im `isPreSeededFlow`-Handoff-Pfad
            // (z.B. CardioFeasibilityCard "Plan anpassen") bleibt es `nil`
            // und `createPlan` verhaelt sich exakt wie vorher (kein
            // erfundenes Ziel, siehe dortige Doku).
            try PlanGeneratorInstantiator.createPlan(
                from: currentInput, result: result,
                for: profile, generationSource: .planBuilder, in: modelContext,
                generatorGoal: selectedTrainingGoal
            )
        }) {
        case .success(let plan):
            dismiss()
            // Gleiches 0.3s-Defer-Muster wie `ProgramTemplatePickerView.instantiate`
            // - gibt der Sheet-Dismiss-Animation Zeit, bevor der Navigations-Stack
            // mutiert (sonst race zwischen dismiss + navigationDestination).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigation.workoutPath.append(plan)
            }
        case .nothingToCreate:
            isAdopting = false
        case .committedButUnresolved:
            // Nachbesserung (dritte Korrekturrunde, Punkt B/5): der Plan WURDE bereits
            // gespeichert - "Es wurde nichts geaendert" (der generische Text) waere hier
            // falsch - eigener Titel + eigene Nachricht, Button-Beschriftung aendert sich.
            adoptSaveErrorIsCreatedButUnresolved = true
            adoptSaveErrorMessage = String(localized: "planBuilder.error.createdButUnresolved.message", bundle: .module)
            isAdopting = false
        case .failedBeforeCommit:
            adoptSaveErrorIsCreatedButUnresolved = false
            adoptSaveErrorMessage = String(localized: "planBuilder.error.saveFailed.message", bundle: .module)
            isAdopting = false
        }
    }

    /// Gleiches manuelles .one/.other-Muster wie `PlansListView.pluralizedCount`.
    private func pluralizedCount(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }
}

/// Minimaler Ersatz fuer `ContentUnavailableView` (iOS 17+, aber ohne
/// SF-Symbol-Icon-Parameter-Komplexitaet) - README 2.20 Randfall, wenn der
/// Generator fuer eine Auswahl NICHTS in der Bibliothek findet (z.B.
/// Ausruestung/Schwierigkeit-Kombination ohne jeden Treffer).
@available(iOS 17.0, macOS 14.0, *)
private struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
#endif
