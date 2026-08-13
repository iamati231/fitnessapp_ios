// Nutzer-Feedback: der Ad-Hoc-Zeitformat-Start (README 2.35, 43b) fuehlte
// sich "sofort" an - nach der Uebungswahl wurden Tag/Uebung/Session direkt
// angelegt und in den laufenden Player navigiert, ohne einen bewussten
// "Los geht's"-Moment. Anders als beim Uebernehmen einer Vorlage (dort
// zeigt DayEditorView erst die volle Uebungsliste, bevor "Training starten"
// getippt wird) gab es hier nichts zum Bestaetigen. Dieses kleine Sheet
// schliesst genau diese Luecke, bevor irgendetwas angelegt wird - der
// bestehende Vorlauf-Countdown im Player selbst bleibt zusaetzlich
// unveraendert bestehen.

#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
struct TimedAdHocConfirmSheet: View {

    let format: WorkoutTimeFormat
    let exerciseName: String
    let onStart: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// `.forTime` hat wie die kuratierten ForTime-Vorlagen ueblicherweise
    /// keinen Deckel (siehe `PlanGenerator.timedCardioCandidates`) - hier
    /// dieselbe Konvention fuer die Anzeige.
    private var capText: String? {
        guard format != .forTime else { return nil }
        let minutes = defaultTimedFormatDurationMinutes(for: format)
        return String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), minutes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(timedFormatDisplayName(format))
                            .font(.title2.weight(.bold))
                        Text(exerciseName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                        if let capText {
                            Text(capText)
                                .font(.subheadline)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.Deltiq.surface)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)

                Section {
                    Button {
                        onStart()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("dashboard.action.adHoc.confirm.start", bundle: .module)
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.Deltiq.surface)

                    Button(role: .cancel) {
                        onCancel()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("common.cancel", bundle: .module)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("dashboard.action.adHoc.confirm.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
#endif
