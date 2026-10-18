#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// P6.3: Kurzer, überspringbarer Alltags-Rückblick (Dok03 §4) — Häufigkeit/
/// Dauer/Belastung/Beschwerden/Ziel-noch-aktuell, alle fünf unabhängig
/// überspringbar.
///
/// Nachbesserung: "Belastung" ist eine EIGENE, periodenbezogene Frage
/// innerhalb dieses Rückblicks (`ExertionFeedback`), NICHT
/// `WorkoutSession.sessionFeeling` — jenes bewertet eine einzelne absolvierte
/// Einheit, ist nicht optional und hat einen vorbelegten Default (`.okay`),
/// also weder periodenbezogen noch echt überspringbar. Der bestehende
/// Trainingsabschluss (`FinishWorkoutSheet`) bleibt dafür unverändert.
///
/// Bewusst EIGENSTÄNDIG: kein zweiter Start-Check, keine Erweiterung von
/// `BaselineCheckFlowView`, keine Leistungstest-Fragen (siehe
/// `docs/PLANUNG_BEGLEITUNG_AUDIT.md` Abschnitt "Start-Check — unveränder-
/// liche Grenze"). Jede Frage ist unabhängig überspringbar — jede
/// `@State`-Antwort startet bei `.skip` und wird nur bei explizitem Antippen
/// gesetzt; `save()` überträgt `.skip` 1:1 als `nil`, nie als "Nein" oder
/// einen anderen erratenen Wert.
///
/// Immer ein NEUER Eintrag (kein Edit-Modus) — wie `WaterEntry`/
/// `BodyMeasurement` ist jeder Rückblick ein eigener Zeitpunkt-Snapshot,
/// kein einzelner, fortlaufend überschriebener Datensatz.
///
/// Nachbesserung (TestingBot-Diagnose): **bewusst KEIN `@Query`** mehr für
/// das letzte-Rückblick-Datum. Per TestingBot-Bisektion + gezielter
/// `NSLog`-Instrumentierung nachgewiesen, dass das vorherige
/// `@Query(sort:order:)` hier — als Destination-Closure eines
/// `NavigationLink` innerhalb von `SettingsAppExperienceView` — zu einer
/// Endlosschleife führte: `init`/`body` dieser View wurden mit ~140 Hz
/// erneut evaluiert, sobald `SettingsAppExperienceView` nur ERSCHIEN (schon
/// VOR jedem Tap auf "Quick check-in"), was den App-Hauptthread saettigte
/// und reproduzierbar zum XCTest-Fehler "XCTPerformOnMainRunLoop work timed
/// out after 60.0s" führte — ein echter App-Bug, kein Harness-Artefakt.
/// Reproduziert sowohl auf diesem Stand als auch auf dem urspruenglichen
/// P6.3-Commit (`063cb90`, vor allen Nebenfunden dieser Runde). Ein einmaliger
/// Fetch beim Erscheinen (`.task`) statt einer live beobachtenden `@Query`
/// behebt das, weil diese View dadurch nicht mehr bei jeder (moeglicherweise
/// spekulativen) Rekonstruktion eine neue SwiftData-Beobachtung aufbaut.
/// Reicht inhaltlich aus: dieser Screen zeigt nur "wann war der letzte
/// Rückblick", braucht dafuer keine Live-Aktualisierung waehrend er offen
/// ist — `save()` aktualisiert den angezeigten Wert ohnehin direkt.
@available(iOS 17.0, macOS 14.0, *)
public struct PeriodicCheckInView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var lastCheckInDate: Date?

    private enum FrequencyAnswer: Hashable { case skip, less, asPlanned, more }
    private enum DurationAnswer: Hashable { case skip, tooShort, justRight, tooLong }
    private enum ExertionAnswer: Hashable { case skip, tooEasy, appropriate, tooHard }
    private enum TriBool: Hashable { case skip, yes, no }

    @State private var frequencyAnswer: FrequencyAnswer = .skip
    @State private var durationAnswer: DurationAnswer = .skip
    /// Nachbesserung: periodenbezogene, echt überspringbare Belastungsfrage
    /// (siehe `ExertionFeedback`-Dokumentation in `FitnessAppCore`) —
    /// ausdrücklich NICHT `WorkoutSession.sessionFeeling` (das ist pro
    /// Session, nicht optional, und hat einen vorbelegten Default).
    @State private var exertionAnswer: ExertionAnswer = .skip
    @State private var complaintsAnswer: TriBool = .skip
    @State private var complaintsNote: String = ""
    @State private var goalAnswer: TriBool = .skip

    /// Rein transiente Bestätigung ("Danke für dein Feedback!") — anders als
    /// `history` (die live-Query, persistierte Wahrheit) kein Datenfeld,
    /// nur ein UI-Signal fuer diesen einen Speichern-Tap.
    @State private var didJustSave = false

    /// Nachbesserung: dieser Screen hatte ursprünglich GAR keinen Verwerfen-
    /// Schutz — anders als jeder andere Editor dieser Epic (`MeasurementView`,
    /// `BodyDataEditorView`, ...) konnte eine bereits begonnene, aber noch
    /// nicht gespeicherte Antwort durch einen Tap auf den Zurück-Chevron
    /// kommentarlos verloren gehen. Jetzt dieselbe Konvention wie überall
    /// sonst: `isDirty` + `discardChangesConfirmation`.
    @State private var showingDiscardConfirm = false

    public init() {}

    /// True sobald mindestens eine Frage beantwortet oder eine Beschwerden-
    /// Notiz getippt wurde — der reine `.skip`-Ausgangszustand ist NICHT
    /// dirty (sonst würde ein unberührter Screen fälschlich einen Verwerfen-
    /// Dialog zeigen, bevor der User überhaupt etwas eingegeben hat).
    private var isDirty: Bool {
        frequencyAnswer != .skip
            || durationAnswer != .skip
            || exertionAnswer != .skip
            || complaintsAnswer != .skip
            || goalAnswer != .skip
            || !complaintsNote.isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("periodicCheckIn.header.eyebrow"),
                title: loc("periodicCheckIn.title"),
                onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                actions: [
                    DeltiqHeaderAction(
                        systemImage: "checkmark",
                        accessibilityLabel: String(localized: "common.save", bundle: .module)
                    ) {
                        save()
                    }
                ]
            )

            ScrollView {
                VStack(spacing: 18) {
                    if let lastDate = lastCheckInDate {
                        DeltiqContextRow([
                            DeltiqContextItem(
                                loc("periodicCheckIn.lastSaved")
                                    .replacingOccurrences(of: "%@", with: lastDate.formatted(date: .abbreviated, time: .omitted))
                                    .uppercased(),
                                style: .neutral
                            )
                        ])
                    }
                    questionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix (siehe `showingDiscardConfirm`-Dokumentation):
        // `.navigationBarBackButtonHidden(true)` nimmt auf iOS die Swipe-
        // Back-Geste als Nebenwirkung mit runter — bei Aenderungen bewusst
        // AUS, sonst waere die Wisch-Geste ein ungesicherter Verlassen-Weg
        // am Discard-Dialog vorbei (gleiches Muster wie `MeasurementView`).
        .deltiqSwipeBackEnabled(!isDirty)
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            dismiss()
        }
        .task { loadLastCheckInDate() }
    }

    /// Einmaliger Fetch statt `@Query` (siehe Typ-Dokumentation oben) —
    /// bewusst `fetchLimit = 1`, es wird ausschliesslich das neueste Datum
    /// gebraucht.
    private func loadLastCheckInDate() {
        var descriptor = FetchDescriptor<PeriodicCheckIn>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        lastCheckInDate = (try? modelContext.fetch(descriptor))?.first?.date
    }

    private var questionsSection: some View {
        DeltiqSection(loc("periodicCheckIn.section.title")) {
            questionBlock(loc("periodicCheckIn.question.frequency.label")) {
                frequencyPicker
            }
            questionBlock(loc("periodicCheckIn.question.duration.label")) {
                durationPicker
            }
            questionBlock(loc("periodicCheckIn.question.exertion.label")) {
                exertionPicker
            }
            questionBlock(loc("periodicCheckIn.question.complaints.label")) {
                triBoolPicker($complaintsAnswer)
                if complaintsAnswer == .yes {
                    TextField(
                        loc("periodicCheckIn.question.complaints.notePlaceholder"),
                        text: $complaintsNote,
                        prompt: Text(loc("periodicCheckIn.question.complaints.notePlaceholder"))
                    )
                    .font(.system(size: 15))
                }
            }
            questionBlock(loc("periodicCheckIn.question.goal.label"), showsDivider: false) {
                triBoolPicker($goalAnswer)
            }
            hintRow(loc("periodicCheckIn.footer"))
            if didJustSave {
                Text(loc("periodicCheckIn.saved.confirmation"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.success)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    /// Eine Frage als eigener Block: Label + volle Breite für das Control
    /// darunter (anders als `DeltiqControlRow`, dessen HStack-Layout für
    /// einen schmalen, rechtsbündigen Wert gedacht ist — ein
    /// `DeltiqSegmentedPicker` braucht die ganze Zeilenbreite). Divider-
    /// Konvention identisch zu `DeltiqControlRow`.
    @ViewBuilder
    private func questionBlock<Content: View>(
        _ label: String,
        showsDivider: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                content()
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

    private var frequencyPicker: some View {
        DeltiqSegmentedPicker(
            options: [
                DeltiqSegmentedOption(FrequencyAnswer.skip, label: loc("periodicCheckIn.answer.skip")),
                DeltiqSegmentedOption(FrequencyAnswer.less, label: loc("periodicCheckIn.answer.frequency.less")),
                DeltiqSegmentedOption(FrequencyAnswer.asPlanned, label: loc("periodicCheckIn.answer.frequency.asPlanned")),
                DeltiqSegmentedOption(FrequencyAnswer.more, label: loc("periodicCheckIn.answer.frequency.more"))
            ],
            selection: $frequencyAnswer
        )
    }

    private var durationPicker: some View {
        DeltiqSegmentedPicker(
            options: [
                DeltiqSegmentedOption(DurationAnswer.skip, label: loc("periodicCheckIn.answer.skip")),
                DeltiqSegmentedOption(DurationAnswer.tooShort, label: loc("periodicCheckIn.answer.duration.tooShort")),
                DeltiqSegmentedOption(DurationAnswer.justRight, label: loc("periodicCheckIn.answer.duration.justRight")),
                DeltiqSegmentedOption(DurationAnswer.tooLong, label: loc("periodicCheckIn.answer.duration.tooLong"))
            ],
            selection: $durationAnswer
        )
    }

    private var exertionPicker: some View {
        DeltiqSegmentedPicker(
            options: [
                DeltiqSegmentedOption(ExertionAnswer.skip, label: loc("periodicCheckIn.answer.skip")),
                DeltiqSegmentedOption(ExertionAnswer.tooEasy, label: loc("periodicCheckIn.answer.exertion.tooEasy")),
                DeltiqSegmentedOption(ExertionAnswer.appropriate, label: loc("periodicCheckIn.answer.exertion.appropriate")),
                DeltiqSegmentedOption(ExertionAnswer.tooHard, label: loc("periodicCheckIn.answer.exertion.tooHard"))
            ],
            selection: $exertionAnswer
        )
    }

    private func triBoolPicker(_ selection: Binding<TriBool>) -> some View {
        DeltiqSegmentedPicker(
            options: [
                DeltiqSegmentedOption(TriBool.skip, label: loc("periodicCheckIn.answer.skip")),
                DeltiqSegmentedOption(TriBool.yes, label: loc("periodicCheckIn.answer.yes")),
                DeltiqSegmentedOption(TriBool.no, label: loc("periodicCheckIn.answer.no"))
            ],
            selection: selection
        )
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private func save() {
        let checkIn = PeriodicCheckIn(
            frequencyFeedback: {
                switch frequencyAnswer {
                case .skip: return nil
                case .less: return .lessThanPlanned
                case .asPlanned: return .asPlanned
                case .more: return .moreThanPlanned
                }
            }(),
            durationFeedback: {
                switch durationAnswer {
                case .skip: return nil
                case .tooShort: return .tooShort
                case .justRight: return .justRight
                case .tooLong: return .tooLong
                }
            }(),
            hadComplaints: {
                switch complaintsAnswer {
                case .skip: return nil
                case .yes: return true
                case .no: return false
                }
            }(),
            // Eine Notiz ist nur sinnvoll, wenn tatsaechlich "Ja" beantwortet
            // wurde — sonst koennte ein getippter, dann wieder auf "Keine
            // Angabe"/"Nein" zurueckgenommener Text stehen bleiben.
            complaintsNote: complaintsAnswer == .yes && !complaintsNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? complaintsNote
                : nil,
            goalStillCurrent: {
                switch goalAnswer {
                case .skip: return nil
                case .yes: return true
                case .no: return false
                }
            }(),
            exertionFeedback: {
                switch exertionAnswer {
                case .skip: return nil
                case .tooEasy: return .tooEasy
                case .appropriate: return .appropriate
                case .tooHard: return .tooHard
                }
            }()
        )
        modelContext.insert(checkIn)
        // Ersetzt die fruehere `@Query`-Live-Aktualisierung (siehe Typ-
        // Dokumentation): der "zuletzt gespeichert"-Hinweis zeigt den
        // gerade gespeicherten Eintrag sofort, ohne dafuer eine neue
        // Beobachtung aufzubauen.
        lastCheckInDate = checkIn.date

        // Kein dismiss(): anders als ein klassischer Editor bestaetigt dieser
        // Screen den Speichervorgang inline und setzt das Formular zurueck,
        // damit ein versehentlicher zweiter Tap nicht denselben Eintrag
        // doppelt anlegt (jedes Feld startet wieder bei `.skip`). Der User
        // verlaesst den Screen bewusst ueber den Zurueck-Chevron.
        frequencyAnswer = .skip
        durationAnswer = .skip
        exertionAnswer = .skip
        complaintsAnswer = .skip
        complaintsNote = ""
        goalAnswer = .skip
        didJustSave = true
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Rückblick") {
    NavigationStack {
        PeriodicCheckInView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}
#endif
#endif
