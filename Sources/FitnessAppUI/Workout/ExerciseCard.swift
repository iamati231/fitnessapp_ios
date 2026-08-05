#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// One card per exercise inside `ActiveWorkoutView` — header (name + target) plus N
/// `SetRow`s, where N = `exercise.sets`. Owns the actual `ExerciseLog` insertion;
/// notifies the parent (via `onSetLogged`) so the rest timer can start.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseCard: View {
    let exercise: Exercise
    let session: WorkoutSession
    /// DEL-097 + DEL-108: Session-weiter Time-Set-Lock (Exercise × setIndex).
    /// Reicht durch zur SetRow, die den Lock claimt bzw. den eigenen
    /// Start-Button blockiert, wenn ein anderer Satz (gleicher oder fremder
    /// Uebung) den Slot bereits haelt.
    @Binding var activeTimedSet: ActiveTimedSetID?
    /// Fired when ANY set is logged. Carries the 0-based set index so the parent
    /// can label the Live Activity ("Satz 2 von 4") accurately.
    let onSetLogged: (_ setIndex: Int) -> Void

    /// DEL-154: Optionale Edit-/Delete-Hooks. Werden NUR im Ad-Hoc-Workout
    /// gesetzt (`session.isAdHoc`) — dort hat der User die Uebungen selbst
    /// hinzugefuegt und darf sie strukturell aendern bzw. wieder entfernen.
    /// Bei Plan-Workouts bleiben beide `nil` → kein Menu, Plan bleibt
    /// unangetastet.
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    /// DEL-157: Wird bei einem Satz-DELETE neu gewuerfelt. Fliesst in die
    /// `.id()` jeder SetRow ein, sodass nach dem Reindexen alle Rows frisch
    /// aus ihren (neu zugeordneten) Logs seeden — verhindert stale `@State`
    /// nach einem Mittel-Delete. Beim ADD bleibt das Token gleich (Append ist
    /// index-stabil), sodass laufende Eingaben nicht zuruckgesetzt werden.
    @State private var structureToken = UUID()

    // DEL-195: Warmup-Ramp. Gleicher Toggle wie der Warmup-Übungs-Filter
    // (DEL-092) — wer Warmups global abschaltet, will auch keine Ramp-Hints.
    @AppStorage("pref_show_warmups") private var showWarmups: Bool = true
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"
    @State private var rampExpanded = false

    var body: some View {
        // UX-203: berechne EINMAL pro Render den aktiven Satz — der erste
        // mit `existingLog == nil`. Wenn alle completed sind, bleibt es nil
        // und keine Row bekommt den active-Highlight. Wird pro SetRow
        // weitergereicht, damit die Row nicht selber nach activeIndex
        // suchen muss (vermeidet O(n²) in der For-Each).
        let active = activeSetIndex
        // Signature-Geruest 2.2: Grau-8%/Radius-16-Karte -> Surface/Radius-20.
        // accentEdge ist bewusst immer an (nicht an isActiveSet-artige Logik
        // gekoppelt): auf iOS zeigt die TabView.page-Pagination immer nur
        // EINE ExerciseCard gleichzeitig, es gibt also keine "kommenden"
        // Karten zum Abdunkeln (siehe Ruecksprache) - die eine sichtbare
        // Karte ist immer die aktive.
        DeltiqCard(accentEdge: true) {
        VStack(alignment: .leading, spacing: 10) {
            header
            Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            // DEL-195: Aufwärm-Rampe (collapsed by default) — nur für
            // Barbell-Working-Sets mit bekanntem Zielgewicht.
            if let ramp = warmupRamp, !ramp.isEmpty {
                warmupRampSection(ramp)
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            }
            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                SetRow(
                    setIndex: setIndex,
                    exercise: exercise,
                    session: session,
                    existingLog: existingLog(forSetIndex: setIndex),
                    previousLog: previousLog(forSetIndex: setIndex),
                    seedLog: seedLog(forSetIndex: setIndex),
                    onRequestDelete: exercise.sets > 1 ? { removeSet(at: setIndex) } : nil,
                    activeTimedSet: $activeTimedSet,
                    isActiveSet: setIndex == active,
                    onLogged: { values in
                        logSet(setIndex: setIndex, values: values)
                    },
                    onUnlog: {
                        unlogSet(setIndex: setIndex)
                    }
                )
                // DEL-157: id mit structureToken → frisches Re-Seed nach Delete.
                .id("set-\(setIndex)-\(structureToken)")
                if setIndex < exercise.sets - 1 {
                    // Signature-Geruest 1.6: Trennlinie einheitlich 6% statt
                    // der bisherigen 20% - die Active-Set-Background-Tint
                    // uebernimmt weiterhin die primaere visuelle Trennung.
                    Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                }
            }

            if completedSetCount >= exercise.sets {
                Label {
                    Text("workout.allSetsDone", bundle: .module)
                } icon: {
                    Image(systemName: "flag.checkered")
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }

            // DEL-157: "+ Satz hinzufügen" — haengt einen weiteren Satz-Slot
            // an. Der neue Satz erbt seine Defaults via seedLog vom
            // darueberliegenden Satz (siehe SetRow.initializeOnce).
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    addSet()
                }
            } label: {
                Label {
                    Text("active.set.add", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.deltiqOrange)
                }
                .font(.callout.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // DEL-124: Active-Workout Card-Header via displayName.
                    Text(exercise.displayName)
                        .font(.headline)
                    // DEL-087: Pill markiert Warmup/Cooldown-Uebungen optisch.
                    if exercise.role != .workingSet {
                        Text(rolePillText)
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
                // UX-203: Set-Metadata ruhiger — .caption → .caption2,
                // .secondary → .tertiary, plus monospacedDigit damit Zahlen
                // beim Editieren (z.B. Pause-Stepper) nicht in der Breite
                // springen. Bleibt lesbar, drueckt aber sich weiter in
                // den Hintergrund gegenueber dem Exercise-Name.
                Text(targetText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            progressPill
            // DEL-154: Edit/Delete-Menu — nur wenn der Parent Hooks liefert
            // (Ad-Hoc-Workout). In der paginierten TabView gibt es keine
            // List-Swipe-Actions, daher ein Ellipsis-Menu im Header.
            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label {
                                Text("active.exercise.edit", bundle: .module)
                            } icon: {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label {
                                Text("active.exercise.remove", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("active.exercise.menuAccessibility", bundle: .module))
            }
        }
    }

    /// DEL-087: Label-Text fuer die Role-Pill im Header.
    private var rolePillText: String {
        switch exercise.role {
        case .warmup:     return "WARM-UP"
        case .cooldown:   return "COOL-DOWN"
        case .workingSet: return ""
        }
    }

    /// DEL-128: vollstaendige i18n der Card-Subtitle-Zeile.
    /// Vorher inline DE-Strings ("Cardio", "Wdh"/"Sek", "Pause") — im EN/TR-
    /// Mode wurden die durchgereicht und produzierten halb-deutsche Sub-
    /// titel. Jetzt:
    ///   * Cardio-Branch:   "Cardio • 150s Pause" / "Cardio • 150s rest"
    ///                      / "Kardiyo • 150s mola"
    ///   * Strength-Branch: "3 × 6-8 Wdh • 150s Pause" / "3 × 6-8 reps •
    ///                      150s rest" / "3 × 6-8 tkr • 150s mola"
    /// Format-Strings sind im Catalog als `exercise.target.cardioFormat` /
    /// `.strengthFormat` mit positionellen %1$/%2$/...-Placeholders
    /// definiert; Swift macht die Substitution via `String(format:)`.
    private var targetText: String {
        let pauseLabel = String(localized: "exercise.rest.label", bundle: .module)
        if exercise.isCardio {
            let cardioLabel = String(localized: "exercise.kind.cardio", bundle: .module)
            let fmt = String(localized: "exercise.target.cardioFormat", bundle: .module)
            return String(format: fmt, cardioLabel, exercise.restSeconds, pauseLabel)
        }
        let unit = exercise.isTimeBased
            ? String(localized: "unit.seconds.short", bundle: .module)
            : String(localized: "unit.reps.short", bundle: .module)
        let range = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        let fmt = String(localized: "exercise.target.strengthFormat", bundle: .module)
        return String(format: fmt, exercise.sets, range, unit, exercise.restSeconds, pauseLabel)
    }

    private var progressPill: some View {
        Text("\(completedSetCount) / \(exercise.sets)")
            .font(.caption.weight(.bold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(progressFillColor)
            .foregroundStyle(completedSetCount >= exercise.sets ? .green : .primary)
            .clipShape(Capsule())
            // DEL-059: feine Lichtkante auf der Pill
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
    }

    private var progressFillColor: Color {
        completedSetCount >= exercise.sets
            ? Color.green.opacity(0.18)
            : Color.secondary.opacity(0.18)
    }

    // MARK: Lookups

    private var sessionLogs: [ExerciseLog] {
        session.logs.filter { $0.exercise == exercise }
    }

    private var completedSetCount: Int {
        sessionLogs.count
    }

    private func existingLog(forSetIndex index: Int) -> ExerciseLog? {
        sessionLogs.first { $0.setIndex == index }
    }

    /// UX-203: liefert den Index des "naechsten anstehenden" Sets — also
    /// den niedrigsten setIndex ohne existing log. Nil = alle Sets dieser
    /// Uebung sind completed. Wird in `body` einmal evaluiert und an die
    /// SetRow-Children durchgereicht, damit der visuelle Active-Highlight
    /// in einer einzigen Quelle der Wahrheit lebt.
    private var activeSetIndex: Int? {
        // Set der Logs ueber setIndex bilden — O(n) Lookup statt n×n.
        let completed = Set(sessionLogs.map(\.setIndex))
        for i in 0..<exercise.sets where !completed.contains(i) {
            return i
        }
        return nil
    }

    /// Most recent log of this exercise + setIndex from a prior COMPLETED session.
    /// Live in-progress logs are filtered out so the hint shows what the user did
    /// LAST workout, not what they just typed two minutes ago.
    private func previousLog(forSetIndex index: Int) -> ExerciseLog? {
        exercise.logs
            .filter {
                $0.session?.isCompleted == true
                && $0.setIndex == index
            }
            .sorted { $0.date > $1.date }
            .first
    }

    // MARK: - DEL-195 Warmup-Ramp

    /// Die Rampe, falls für diese Übung sinnvoll — sonst nil. Bedingungen:
    ///   * `pref_show_warmups` an (globaler Toggle, DEL-092)
    ///   * Strength-Working-Set (kein Cardio, kein TimeBased, keine
    ///     Warmup-/Cooldown-Übung — die IST schon das Aufwärmen)
    ///   * Barbell-Übung (der Leere-Stange-Schritt setzt eine Stange voraus)
    ///   * ein Referenzgewicht existiert (Plan-Vorschlag oder letzter Satz 1)
    private var warmupRamp: [WarmupStep]? {
        guard showWarmups,
              !exercise.isCardio,
              !exercise.isTimeBased,
              exercise.role == .workingSet,
              isBarbellExercise,
              let workingKg = referenceWeightKg else { return nil }

        if weightUnitRaw == "lbs" {
            // lbs-Konventionen: 45-lbs-Bar, 5-lbs-Increment, Heavy ab 220 lbs.
            let workingLbs = workingKg / 0.453592
            return WarmupRampCalculator.ramp(
                workingWeightKg: workingLbs,
                barWeightKg: 45,
                roundingIncrementKg: 5,
                heavySingleThreshold: 220
            )
        }
        return WarmupRampCalculator.ramp(workingWeightKg: workingKg)
    }

    /// Barbell-Detection: DEL-159-Override gewinnt, sonst Library-Lookup
    /// über den System-Namen. Custom-Übungen ohne Equipment → kein Ramp.
    private var isBarbellExercise: Bool {
        if let equipment = exercise.equipment {
            return equipment == .barbell
        }
        return ExerciseLibraryData.all.first { $0.name == exercise.name }?.equipment == .barbell
    }

    /// Zielgewicht für die Rampe: Plan-Vorschlag (Smart-Progression pflegt
    /// `suggestedWeight`), sonst das Gewicht von Satz 1 der letzten Session.
    private var referenceWeightKg: Double? {
        if let suggested = exercise.suggestedWeight, suggested > 0 {
            return suggested
        }
        if let previous = previousLog(forSetIndex: 0), previous.weight > 0 {
            return previous.weight
        }
        return nil
    }

    private func warmupRampSection(_ ramp: [WarmupStep]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { rampExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame")
                        .font(.caption)
                        .foregroundStyle(Color.deltiqOrange)
                    Text("warmup.ramp.title", bundle: .module)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: rampExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if rampExpanded {
                ForEach(Array(ramp.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: 8) {
                        Text(stepWeightText(step))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("× \(step.reps)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    /// "Leere Stange" für den Bar-Schritt, sonst kompakte Gewichtsanzeige
    /// in der User-Einheit (32,5 kg / 75 lbs — ohne erzwungene Nullen,
    /// Plate-Gewichte haben maximal eine Nachkommastelle).
    private func stepWeightText(_ step: WarmupStep) -> String {
        if step.isBarOnly {
            return String(localized: "warmup.ramp.emptyBar", bundle: .module)
        }
        let unit = weightUnitRaw == "lbs" ? "lbs" : "kg"
        let number = step.weightKg.formatted(.number.precision(.fractionLength(0...1)))
        return "\(number) \(unit)"
    }

    // MARK: Actions

    /// DEL-058: nimmt jetzt das `LoggedSetValues`-Bundle und uebernimmt
    /// auch Cardio-Felder (distanceKm/durationSeconds) in den persistierten
    /// `ExerciseLog`.
    private func logSet(setIndex: Int, values: LoggedSetValues) {
        let log = ExerciseLog(
            date: Date(),
            setIndex: setIndex,
            weight: values.weight,
            reps: values.reps,
            rpe: 0,                          // unused in this UI; reserved for future
            rir: values.rir,
            comment: nil,
            exercise: exercise,
            session: session,
            distanceKm: values.distanceKm,
            durationSeconds: values.durationSeconds
        )
        modelContext.insert(log)
        onSetLogged(setIndex)
    }

    /// DEL-045: Tap-on-completed-row revert. Loescht den `ExerciseLog` fuer
    /// diesen Set-Index, sodass die Row wieder in den editable State zurueck-
    /// faellt (TextFields aktiv, Checkmark hollow). Kein Notify nach oben —
    /// der Rest-Timer wird *nicht* zurueckgesetzt, weil der User vermutlich
    /// nur einen Tippfehler korrigieren will, nicht die ganze Pause-Logik
    /// neu starten.
    private func unlogSet(setIndex: Int) {
        guard let log = existingLog(forSetIndex: setIndex) else { return }
        modelContext.delete(log)
    }

    // MARK: - DEL-157 Dynamisches Set-Management

    /// Seed-Quelle fuer einen frisch hinzugefuegten Satz: der Log des Satzes
    /// DIREKT DARUEBER in dieser Session. `nil` fuer den ersten Satz oder
    /// wenn der Satz darueber noch nicht geloggt ist.
    private func seedLog(forSetIndex index: Int) -> ExerciseLog? {
        guard index > 0 else { return nil }
        return existingLog(forSetIndex: index - 1)
    }

    /// Haengt einen weiteren Satz-Slot an. `exercise.sets` ist die Struktur-
    /// Quelle der Wahrheit (der ForEach rendert `0..<sets`) — ein Increment
    /// genuegt, der neue SetRow erscheint leer + seedet sich vom Vorgaenger.
    /// Mutation auf der Plan-/Ad-Hoc-Exercise ist gewollt: identisch zu dem,
    /// was der ExerciseEditor taete, nur ohne den Umweg.
    private func addSet() {
        exercise.sets += 1
    }

    /// Entfernt den Satz an `index`: loescht dessen Log (falls vorhanden),
    /// schiebt die `setIndex` aller dahinterliegenden Logs um 1 nach unten
    /// (luckenlose Nummerierung) und dekrementiert `exercise.sets`. Der
    /// `structureToken` wird neu gewuerfelt, damit alle Rows frisch aus ihren
    /// neu zugeordneten Logs seeden. Der letzte verbleibende Satz ist nicht
    /// loeschbar (Caller gated via `exercise.sets > 1`).
    private func removeSet(at index: Int) {
        guard exercise.sets > 1 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            if let log = existingLog(forSetIndex: index) {
                modelContext.delete(log)
            }
            for log in sessionLogs where log.setIndex > index {
                log.setIndex -= 1
            }
            exercise.sets -= 1
            structureToken = UUID()
        }
    }
}
#endif
