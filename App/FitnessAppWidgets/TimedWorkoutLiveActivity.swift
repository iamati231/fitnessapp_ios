import ActivityKit
import WidgetKit
import SwiftUI
import FitnessAppActivities
import FitnessAppCore

/// Live Activity fuer einen laufenden Zeitformat-Lauf (AMRAP, EMOM, Auf Zeit,
/// Zirkel), solange die App im Hintergrund arbeitet oder der Bildschirm gesperrt
/// ist. Rendert die Attribute aus `FitnessAppActivities`.
///
///   1. Sperrbildschirm: Format, Zustand ("LAEUFT", "PAUSE", "Geschafft!"), grosse
///      Uhr, Fortschrittsbalken, Zaehler (Runden / Minute / Kaesten) und beim EMOM
///      die Uebung der laufenden und der naechsten Minute.
///   2. Dynamic Island kompakt: Format-Symbol und Uhr. Expandiert: Format, Zaehler,
///      Uhr und beim EMOM die Uebung.
///
/// Die Uhren zaehlt das System (`Text(timerInterval:)`, `Text(_, style: .timer)`,
/// `ProgressView(timerInterval:)`), es braucht kein Update pro Sekunde. Alle Texte
/// kommen fertig uebersetzt aus der App (`TimedWorkoutLiveTexts`): Dieses Target
/// hat keinen String-Katalog.
///
/// **Veraltet:** Bleibt das Update aus (App beendet, Hintergrund-Audio aus),
/// markiert iOS den Inhalt zum `staleDate` als veraltet (`context.isStale`). Dann
/// zeigt das Widget nur noch, was das System allein richtig weiterzaehlt: die
/// Gesamtzeit des Laufs. Eine eingefrorene Minute oder Runde waere gelogen.
struct TimedWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimedWorkoutAttributes.self) { context in
            TimedLockScreenView(context: context)
                .widgetURL(FitnessAppDeepLink.activeWorkout)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TimedFormatLabel(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !TimedLook.isOutdated(context) {
                        Text(context.state.texts.status)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimedIslandBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: TimedLook.icon(context.attributes.format))
                    .foregroundStyle(TimedLook.accent(context))
            } compactTrailing: {
                TimedCompactClock(context: context)
            } minimal: {
                Image(systemName: TimedLook.icon(context.attributes.format))
                    .foregroundStyle(TimedLook.accent(context))
            }
            // Tap -> fitnessapp://workout/active (URL-Schema steht in der Info.plist der App).
            .widgetURL(FitnessAppDeepLink.activeWorkout)
            .keylineTint(TimedLook.accent(context))
        }
    }
}

// MARK: - Aussehen

private enum TimedLook {

    static func icon(_ format: WorkoutTimeFormat) -> String {
        switch format {
        case .amrap:   return "flame.fill"
        case .emom:    return "timer"
        case .forTime: return "stopwatch.fill"
        case .circuit: return "arrow.triangle.2.circlepath"
        }
    }

    /// Veraltet = iOS hat den Inhalt als veraltet markiert UND er ist nicht schon der
    /// Endstand (der bleibt gueltig, die Uhr steht ohnehin).
    static func isOutdated(_ context: ActivityViewContext<TimedWorkoutAttributes>) -> Bool {
        context.isStale && context.state.content.phase != .finished
    }

    static func accent(_ context: ActivityViewContext<TimedWorkoutAttributes>) -> Color {
        if isOutdated(context) { return .orange }
        switch context.state.content.phase {
        case .running:  return .orange
        case .rest:     return .cyan
        case .finished: return .green
        }
    }
}

// MARK: - Uhr

/// Die grosse Uhr: je nach Format ein Countdown, eine hochzaehlende Uhr oder (am
/// Ende) eine stehende Zeit. Veraltet: die Gesamtzeit des Laufs.
private struct TimedClockText: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        let content = context.state.content
        if TimedLook.isOutdated(context) {
            overallClock(content)
        } else {
            primaryClock(content)
        }
    }

    @ViewBuilder
    private func primaryClock(_ content: TimedLiveContent) -> some View {
        switch content.clock {
        case .countdown:
            if let range = content.clock.countdownRange {
                Text(timerInterval: range, countsDown: true)
            }
        case .countUp(let since):
            Text(since, style: .timer)
        case .frozen(let seconds):
            Text(TimedLiveContent.clockText(seconds: seconds))
        }
    }

    @ViewBuilder
    private func overallClock(_ content: TimedLiveContent) -> some View {
        if let range = content.overallRange {
            Text(timerInterval: range, countsDown: true)
        } else {
            Text(content.runStart, style: .timer)
        }
    }
}

/// Fortschrittsbalken der laufenden Zeitspanne (Gesamtzeit, Minute oder Pause) -
/// nur dort, wo das System ihn selbst fuehren kann.
private struct TimedProgressBar: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        if !TimedLook.isOutdated(context),
           context.state.content.phase != .finished,
           let range = context.state.content.clock.countdownRange {
            ProgressView(timerInterval: range, countsDown: true)
                .tint(TimedLook.accent(context))
        }
    }
}

// MARK: - Sperrbildschirm

private struct TimedLockScreenView: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        let texts = context.state.texts
        let accent = TimedLook.accent(context)
        let outdated = TimedLook.isOutdated(context)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TimedFormatLabel(context: context)
                Spacer()
                if !outdated {
                    Text(texts.phase)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
            }

            Text(context.attributes.dayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            TimedClockText(context: context)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            TimedProgressBar(context: context)

            if !outdated {
                Text(texts.status)
                    .font(.headline)
                    .lineLimit(1)
                TimedExerciseLines(context: context)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }
}

/// Symbol + Name des Formats ("AMRAP", "Auf Zeit", ...).
private struct TimedFormatLabel: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        Label(context.attributes.formatName, systemImage: TimedLook.icon(context.attributes.format))
            .font(.headline)
            .foregroundStyle(TimedLook.accent(context))
            .lineLimit(1)
    }
}

/// EMOM: Uebung der laufenden Minute, darunter die naechste. Bei allen anderen
/// Formaten (und im Endstand) leer.
private struct TimedExerciseLines: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        let content = context.state.content
        if content.phase == .running, let current = content.currentExercise {
            VStack(alignment: .leading, spacing: 2) {
                Text(current)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                if let next = content.nextExercise {
                    Text(verbatim: "\(context.state.texts.nextLabel): \(next)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Dynamic Island

private struct TimedIslandBottom: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        VStack(spacing: 4) {
            TimedClockText(context: context)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(TimedLook.accent(context))
                .monospacedDigit()
                .multilineTextAlignment(.center)
            if !TimedLook.isOutdated(context) {
                TimedExerciseLines(context: context)
            }
        }
    }
}

/// Kompakt rechts: die Uhr - im Endstand statt dessen ein Haken (eine stehende Uhr
/// auf null in der Insel liest sich wie ein Fehler).
private struct TimedCompactClock: View {
    let context: ActivityViewContext<TimedWorkoutAttributes>

    var body: some View {
        if context.state.content.phase == .finished {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            TimedClockText(context: context)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 52)    // verhindert Wackeln beim Sekundenwechsel
        }
    }
}
