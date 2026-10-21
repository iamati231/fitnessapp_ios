#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-142: SwiftUI-Rendering fuer eine `DayAnalysis`. Drei Branches:
///   1. `nil` Analysis (leere Übungs-Liste) → Empty-State-Card
///   2. Rest-Day → "Heute ist Ruhetag"-Card (vom Caller getriggert via
///      `restDay` initializer-Variante)
///   3. Normale Analyse → Card mit Load-Pill, Muscle-Focus, Duration,
///      Recovery, Coach-Note
@available(iOS 17.0, macOS 14.0, *)
public struct DayAnalysisCard: View {

    public enum Mode {
        /// Normale Analyse, gerendert aus dem DayAnalysis-Bundle.
        case analysis(DayAnalysis)
        /// Empty-State: keine Übungen vorhanden.
        case empty
        /// Rest-Day-Special-Case.
        case restDay
    }

    public let mode: Mode

    public init(mode: Mode) {
        self.mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            switch mode {
            case .analysis(let analysis):
                analysisContent(analysis)
            case .empty:
                emptyContent
            case .restDay:
                restDayContent
            }
        }
        .padding(14)
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .innerLightStroke(cornerRadius: 16, opacity: 0.08)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
            Text("day.analysis.title", bundle: .module)
                .font(.headline)
            Spacer()
            // README 2.13: Zeitformat-Tage MIT Deckel zeigen die Format-
            // Kapsel ("AMRAP · 20 Min") statt der Schaetzung-Pille - die
            // Dauer ist dann keine Schaetzung. Auf Zeit ohne Deckel bleibt
            // bei der Schaetzung-Pille (echte Schaetzung aus Runden × Wdh).
            if case .analysis(let a) = mode, let format = a.timeFormat, !a.isEstimated {
                Text(timedFormatCapsuleText(format: format, minutes: a.estimatedDurationMinutes.lowerBound))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.deltiqOrange.opacity(0.15))
                    .foregroundStyle(Color.deltiqOrange)
                    .clipShape(Capsule())
            } else if case .analysis(let a) = mode, a.isEstimated {
                // "Estimated"-Pill — visualisiert grobe Schaetzung wenn die
                // Übungsdaten unvollständig sind (siehe DayAnalyzer.isEstimated).
                Text("day.analysis.estimated", bundle: .module)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.deltiqOrange.opacity(0.15))
                    .foregroundStyle(Color.deltiqOrange)
                    .clipShape(Capsule())
            }
        }
    }

    /// "AMRAP · 20 Min" — dieselbe Fassung wie in Vorlagen-Vorschau und
    /// Tag-Editor (`timedFormatDisplayName`, README 2.10), damit keine
    /// dritte Formulierung fuer dieselbe Information entsteht.
    private func timedFormatCapsuleText(format: WorkoutTimeFormat, minutes: Int) -> String {
        "\(timedFormatDisplayName(format)) · \(minutes) " + String(localized: "unit.minutes.short", bundle: .module)
    }

    // MARK: Empty / Rest-Day branches

    private var emptyContent: some View {
        Text("day.analysis.empty", bundle: .module)
            .font(.callout)
            .foregroundStyle(Color.Deltiq.textSecondary)
    }

    private var restDayContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
            Text("day.analysis.restDay", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
    }

    // MARK: Analysis content

    @ViewBuilder
    private func analysisContent(_ a: DayAnalysis) -> some View {
        // Load-Pill ganz oben — wichtigster Single-Glance-Indikator.
        loadPill(a.loadCategory)

        Divider().opacity(0.5)

        // Muskel-Fokus — nur rendern wenn nicht-leer (z.B. reiner Cardio
        // Tag hat keinen Muscle-Focus).
        if !a.muscleFocus.isEmpty {
            muscleFocusRow(a.muscleFocus)
            Divider().opacity(0.5)
        }

        // Duration + Recovery + Systemic — in einer 2-Spalten-Grid-artigen
        // VStack, damit auf iPhone-SE auch lesbar.
        let durationText = formatDurationRange(a.estimatedDurationMinutes, isEstimated: a.isEstimated)
        VStack(alignment: .leading, spacing: 8) {
            metricRow(
                icon: "clock",
                labelKey: "day.analysis.duration",
                value: durationText
            )
            metricRow(
                icon: "arrow.clockwise.heart",
                labelKey: "day.analysis.recovery",
                value: formatRecoveryRange(a.localRecoveryHours)
            )
            metricRow(
                icon: "bolt.heart",
                labelKey: "day.analysis.systemic",
                value: localizedLoadLabel(a.systemicLoad)
            )
        }

        Divider().opacity(0.5)

        // Coach-Note ganz unten — kurzer Bewertungs-Text. README 2.13:
        // `.metabolicDensity` (Zeitformat-Tage) rendert NICHT ueber den
        // generischen Catalog-Key, sondern ueber eine formatspezifische,
        // mit der schon berechneten Dauer parametrisierte Variante.
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.bubble.fill")
                .font(.callout)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
            Group {
                if a.coachNote == .metabolicDensity, let format = a.timeFormat {
                    Text(metabolicDensityText(format: format, durationText: durationText))
                } else {
                    Text(LocalizedStringKey(a.coachNote.localizationKey), bundle: .module)
                }
            }
            .font(.callout)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// README 2.13: ein Satz je Format, parametrisiert mit der bereits
    /// berechneten Dauer-Anzeige (teilt sich damit die Capped-vs-Schaetzung-
    /// Unterscheidung aus `formatDurationRange` statt sie zu duplizieren).
    private func metabolicDensityText(format: WorkoutTimeFormat, durationText: String) -> String {
        let key: String
        switch format {
        case .amrap:   key = "day.analysis.coachNote.metabolicDensity.amrap"
        case .emom:    key = "day.analysis.coachNote.metabolicDensity.emom"
        case .forTime: key = "day.analysis.coachNote.metabolicDensity.forTime"
        case .circuit: key = "day.analysis.coachNote.metabolicDensity.circuit"
        case .enduranceIntervals: key = "day.analysis.coachNote.metabolicDensity.enduranceIntervals"
        }
        return String(format: String(localized: String.LocalizationValue(key), bundle: .module), durationText)
    }

    // MARK: Building blocks

    /// Visuelle Load-Skala mit Farb-Mapping (grün/gelb/orange/rot) plus
    /// lokalisiertem Label rechts.
    private func loadPill(_ category: LoadCategory) -> some View {
        HStack(spacing: 12) {
            Text("day.analysis.loadLabel", bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
            Spacer()
            // Mini-4-Segment-Bar — leer/gefuellt je nach Stufe.
            HStack(spacing: 3) {
                ForEach(LoadCategory.allCases.indices, id: \.self) { i in
                    let cat = LoadCategory.allCases[i]
                    let filled = LoadCategory.allCases.firstIndex(of: category)! >= i
                    Capsule()
                        .fill(filled ? loadColor(cat) : Color.Deltiq.fill)
                        .frame(width: 14, height: 6)
                }
            }
            Text(LocalizedStringKey(category.localizationKey), bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(loadColor(category))
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// Mapping LoadCategory → Ampel-Skala (gruen/gelb/orange/rot). Bewusst
    /// KEINE reine Akzent-Farbe: die vier Stufen muessen auf einen Blick
    /// unterscheidbar sein (wie die IWF-Scheibenfarben oder das PR-Gruen),
    /// ein einheitliches Orange wuerde genau die Information wegnehmen, die
    /// dieses Mapping transportiert. `.high` liegt bewusst auf dem
    /// Markenakzent, weil "hohe Last" ohnehin die haeufigste/wichtigste
    /// Stufe ist.
    private func loadColor(_ category: LoadCategory) -> Color {
        switch category {
        case .low:      return .green
        case .moderate: return .yellow
        case .high:     return Color.deltiqOrange
        case .veryHigh: return .red
        }
    }

    /// Muscle-Focus-Row: bis zu 3 Tier-Gruppen (primary/secondary/tertiary).
    /// Pro Tier eine Zeile mit Label + comma-separated Muskel-Liste.
    @ViewBuilder
    private func muscleFocusRow(_ focus: [MuscleStimulus]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.callout)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                Text("day.analysis.muscleFocusLabel", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            ForEach(MuscleStimulus.Tier.allTiers, id: \.self) { tier in
                let muscles = focus.filter { $0.tier == tier }
                if !muscles.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        // Bug-Fix 2026-05-22: vorher `LocalizedStringKey(
                        // "day.analysis.muscleFocus.tier.\(tier.rawValue)")` —
                        // SwiftUI band das an den StringInterpolation-Init
                        // statt String-Init und konstruierte einen Format-
                        // Key statt eines konkreten Lookup-Keys. Resultat:
                        // raw "day.analysis.muscleFocus.tier.primary"
                        // wurde gerendert statt "Primär/Primary/Birincil".
                        // Fix: computed Property `tier.localizationKey` →
                        // String wird VOR der LocalizedStringKey-Init
                        // gebaut, dann durch `init(_ value: String)`
                        // verarbeitet — gleicher Pattern wie LoadCategory
                        // und CoachNoteKind.
                        Text(LocalizedStringKey(tier.localizationKey), bundle: .module)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Text(muscles.map { String(localized: $0.muscle.localizedName) }
                                    .joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Eine Metric-Zeile mit Icon + Label + Wert.
    private func metricRow(icon: String, labelKey: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
                .frame(width: 20)
            Text(labelKey, bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func localizedLoadLabel(_ category: LoadCategory) -> String {
        String(localized: String.LocalizationValue(category.localizationKey),
               bundle: .module)
    }

    /// "~50–65 Min" Format. Nutzt no-break-Hyphen damit der Bereich nicht
    /// am Hyphen umbricht.
    /// README 2.13: ein Zeitformat-Tag MIT Deckel zeigt den Deckel als
    /// exakten Wert ohne Tilde - die Dauer ist dann keine Schaetzung,
    /// sondern der Deckel selbst. Alle anderen Faelle (normale Krafttage,
    /// Auf Zeit ohne Deckel) bleiben bei der bisherigen "~"-Schaetzung.
    private func formatDurationRange(_ range: ClosedRange<Int>, isEstimated: Bool) -> String {
        let unit = String(localized: "unit.minutes.short", bundle: .module)
        if range.lowerBound == range.upperBound {
            return isEstimated ? "~\(range.lowerBound) \(unit)" : "\(range.lowerBound) \(unit)"
        }
        return "~\(range.lowerBound)–\(range.upperBound) \(unit)"
    }

    /// "~36–48 h" Format. "h" als internationale Abkuerzung — keine
    /// Locale-Variante noetig.
    private func formatRecoveryRange(_ range: ClosedRange<Int>) -> String {
        if range.lowerBound == range.upperBound {
            return "~\(range.lowerBound) h"
        }
        return "~\(range.lowerBound)–\(range.upperBound) h"
    }
}

extension MuscleStimulus.Tier {
    /// Aufzaehlungs-Reihenfolge fuer die UI (primary zuerst).
    static var allTiers: [MuscleStimulus.Tier] {
        [.primary, .secondary, .tertiary]
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Analysis — Heavy Leg Day") {
    DayAnalysisCard(mode: .analysis(DayAnalysis(
        loadScore: 38.5,
        loadCategory: .high,
        muscleFocus: [
            MuscleStimulus(muscle: .quads, points: 18.0, tier: .primary),
            MuscleStimulus(muscle: .glutes, points: 12.0, tier: .secondary),
            MuscleStimulus(muscle: .hamstrings, points: 6.0, tier: .tertiary),
        ],
        estimatedDurationMinutes: 60...80,
        localRecoveryHours: 48...72,
        systemicLoad: .high,
        coachNote: .compoundHeavy,
        isEstimated: false
    )))
    .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Analysis — AMRAP mit Deckel") {
    // README 2.13: Format-Kapsel statt Schaetzung-Pille, kein Tilde vor
    // der Dauer - der Deckel IST die Dauer.
    DayAnalysisCard(mode: .analysis(DayAnalysis(
        loadScore: 20,
        loadCategory: .high,
        muscleFocus: [
            MuscleStimulus(muscle: .quads, points: 10.0, tier: .primary),
            MuscleStimulus(muscle: .core, points: 4.0, tier: .secondary),
        ],
        estimatedDurationMinutes: 20...20,
        localRecoveryHours: 36...60,
        systemicLoad: .high,
        coachNote: .metabolicDensity,
        isEstimated: false,
        timeFormat: .amrap
    )))
    .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Analysis — Auf Zeit ohne Deckel") {
    // README 2.13, "Auf Zeit ohne Deckel": echte Schaetzung aus Runden ×
    // Wiederholungen, Schaetzung-Pille bleibt statt Format-Kapsel.
    DayAnalysisCard(mode: .analysis(DayAnalysis(
        loadScore: 14,
        loadCategory: .moderate,
        muscleFocus: [
            MuscleStimulus(muscle: .shoulders, points: 8.0, tier: .primary),
        ],
        estimatedDurationMinutes: 12...18,
        localRecoveryHours: 24...48,
        systemicLoad: .moderate,
        coachNote: .metabolicDensity,
        isEstimated: true,
        timeFormat: .forTime
    )))
    .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Empty") {
    DayAnalysisCard(mode: .empty).padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Rest Day") {
    DayAnalysisCard(mode: .restDay).padding()
}
#endif
#endif
