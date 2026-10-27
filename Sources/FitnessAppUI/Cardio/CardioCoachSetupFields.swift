#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Gemeinsamer Laufcoaching-Setup-Feldsatz (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt):
/// extrahiert aus `CardioGoalEditorView.cardioFields` - Ziel-Picker, 5k-Referenzzeit (+
/// Fehleranzeige/Pace-Zonen-Hinweis), Renndatum-Toggle+Picker, Wochenumfang, maximale
/// Herzfrequenz. Bewusst NICHT enthalten: der Coach-An/Aus-Schalter, die Ausdauerform-Frage
/// und der Retro-Sync-Button - die bleiben `CardioGoalEditorView` vorbehalten (Retro-Sync
/// braucht Trainingshistorie, die es im Onboarding/PlanBuilder noch gar nicht gibt; der
/// An/Aus-Schalter und die Ausdauerform-Frage sind je Aufrufstelle verschieden eingebettet).
///
/// Das Ziel (`draft.goal`) hat nie einen `nil`-Zustand (`CardioGoal` kennt keinen) - die
/// "Pflichtfeld"-Eigenschaft der Spezifikation kommt NICHT aus einer Feld-Validierung hier,
/// sondern daraus, dass der Aufrufer diese View ueberhaupt zeigt (der Nutzer sieht/bestaetigt
/// das Ziel zwangslaeufig, sobald der Setup-Schritt erscheint) - identisches Prinzip wie
/// `CardioGoalEditorView.canSave`, das ebenfalls nur das freie 5k-Textfeld validiert, kein
/// weiteres Feld.
@available(iOS 17.0, macOS 14.0, *)
public struct CardioCoachSetupFields: View {
    @Binding public var draft: CardioCoachSetupDraft

    public init(draft: Binding<CardioCoachSetupDraft>) {
        self._draft = draft
    }

    public var body: some View {
        Group {
            DeltiqControlRow(label: String(localized: "profile.cardio.goal", bundle: .module)) {
                Picker(selection: goalBinding) {
                    ForEach(CardioGoal.allCases, id: \.self) { goal in
                        Label {
                            Text(goal.localizedName)
                        } icon: {
                            Image(systemName: goal.symbol)
                        }
                        .tag(goal)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
            }
            DeltiqControlRow(label: String(localized: "profile.cardio.fiveKReference", bundle: .module)) {
                TextField("MM:SS", text: fiveKReferenceTextBinding, prompt: Text("MM:SS"))
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    #endif
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15))
                    .fitnessNumberStyle()
                    .frame(maxWidth: 90)
            }
            if let fiveKReferenceErrorMessage {
                errorRow(fiveKReferenceErrorMessage)
            } else if let zonesSummary {
                hintRow(zonesSummary)
            }
            DeltiqControlRow(
                label: String(localized: "profile.cardio.raceDateToggle", bundle: .module),
                showsDivider: draft.raceDate != nil
            ) {
                Toggle("", isOn: raceDateToggleBinding)
                    .labelsHidden()
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("profile.cardio.raceDateToggle", bundle: .module))
            }
            if draft.raceDate != nil {
                DeltiqControlRow(label: String(localized: "profile.cardio.raceDateValue", bundle: .module)) {
                    DatePicker(
                        selection: Binding(
                            get: { draft.raceDate ?? Self.defaultRaceDate },
                            set: { newValue in draft = with(draft) { $0.raceDate = newValue } }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()
                }
            }
            DeltiqControlRow(label: String(localized: "profile.cardio.weeklyVolume", bundle: .module)) {
                decimalField(
                    String(localized: "profile.cardio.weeklyVolume", bundle: .module),
                    value: weeklyBaseVolumeKmBinding,
                    placeholder: String(localized: "profile.cardio.weeklyVolumePlaceholder", bundle: .module)
                )
            }
            DeltiqControlRow(label: String(localized: "profile.cardio.maxHeartRate", bundle: .module), showsDivider: false) {
                intField(
                    String(localized: "profile.cardio.maxHeartRate", bundle: .module),
                    value: maxHeartRateBpmBinding,
                    placeholder: String(localized: "profile.cardio.maxHeartRatePlaceholder", bundle: .module)
                )
            }
        }
    }

    // MARK: - Bindings (jede Mutation baut `draft` als Ganzes neu - die Struct ist bewusst
    // komplett `let`, identisches Prinzip wie `DaySpec`/`CardioRunProfile`: ein Wert, nie
    // Teil-mutiert.)

    private var goalBinding: Binding<CardioGoal> {
        Binding(get: { draft.goal }, set: { newValue in draft = with(draft) { $0.goal = newValue } })
    }

    private var fiveKReferenceTextBinding: Binding<String> {
        Binding(get: { draft.fiveKReferenceText }, set: { newValue in draft = with(draft) { $0.fiveKReferenceText = newValue } })
    }

    private var weeklyBaseVolumeKmBinding: Binding<Double?> {
        Binding(get: { draft.weeklyBaseVolumeKm }, set: { newValue in draft = with(draft) { $0.weeklyBaseVolumeKm = newValue } })
    }

    private var maxHeartRateBpmBinding: Binding<Int?> {
        Binding(get: { draft.maxHeartRateBpm }, set: { newValue in draft = with(draft) { $0.maxHeartRateBpm = newValue } })
    }

    private var raceDateToggleBinding: Binding<Bool> {
        Binding(
            get: { draft.raceDate != nil },
            set: { isOn in draft = with(draft) { $0.raceDate = isOn ? (draft.raceDate ?? Self.defaultRaceDate) : nil } }
        )
    }

    private static var defaultRaceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    }

    /// Mutable-Kopie-Helfer, da `CardioCoachSetupDraft` komplett `let`-Properties hat (Codable/
    /// Hashable-Wertsemantik, identisch zu `CardioRunProfile`) - jede Binding-`set`-Closure baut
    /// darueber einen neuen Wert statt eines Teil-Writes.
    private func with(_ draft: CardioCoachSetupDraft, _ mutate: (inout MutableDraft) -> Void) -> CardioCoachSetupDraft {
        var mutable = MutableDraft(draft)
        mutate(&mutable)
        return mutable.asDraft
    }

    private struct MutableDraft {
        var goal: CardioGoal
        var raceDate: Date?
        var weeklyBaseVolumeKm: Double?
        var maxHeartRateBpm: Int?
        var fiveKReferenceText: String

        init(_ draft: CardioCoachSetupDraft) {
            goal = draft.goal
            raceDate = draft.raceDate
            weeklyBaseVolumeKm = draft.weeklyBaseVolumeKm
            maxHeartRateBpm = draft.maxHeartRateBpm
            fiveKReferenceText = draft.fiveKReferenceText
        }

        var asDraft: CardioCoachSetupDraft {
            CardioCoachSetupDraft(
                goal: goal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyBaseVolumeKm,
                maxHeartRateBpm: maxHeartRateBpm, fiveKReferenceText: fiveKReferenceText
            )
        }
    }

    // MARK: - Validierung/Hinweise (1:1 aus `CardioGoalEditorView` uebernommen)

    public var fiveKReferenceErrorMessage: String? {
        guard !draft.fiveKReferenceText.isEmpty, draft.current5kReferenceSeconds == nil else { return nil }
        return String(localized: "profile.cardio.fiveKReference.invalid", bundle: .module)
    }

    private var zonesSummary: String? {
        guard let seconds = draft.current5kReferenceSeconds,
              let easy = PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: seconds),
              let tempo = PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: seconds)
        else { return nil }
        let template = String(localized: "profile.cardio.paceZones", bundle: .module)
        return String(format: template, PaceCalculator.formatPace(easy), PaceCalculator.formatPace(tempo))
    }

    // MARK: - Fields (identisch zu `CardioGoalEditorView`)

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    @ViewBuilder
    private func intField(_ label: String, value: Binding<Int?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.Deltiq.error)
    }
}
#endif
