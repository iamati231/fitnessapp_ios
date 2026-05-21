#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppCore
import FitnessAppData
#if canImport(UIKit)
import UIKit
#endif

/// Single row inside an `ExerciseCard` — represents one planned set of an exercise.
///
/// **DEL-045 redesign:**
///   - Strength + Cardio: kompaktes Single-Line-Layout
///     `[Satz #] [kg-Input] [Wdh-Input] [Spacer] [Checkmark-Icon]`
///     plus RIR-Slider in einem Container mit FESTER HOEHE darunter (verhindert
///     Layout-Shifts beim Toggle in den completed-State).
///   - Tap auf einen completed-Set → ExerciseLog wird geloescht, Row wechselt
///     zurueck in den editierbaren Status (Tippfehler-Korrektur).
///   - Time-based (Plank, Wall Sit, etc.): eigener Flow mit Countdown-Overlay
///     + Live-Hold-Timer (DEL-040). Per-Sekunde-Beeps bei 3/2/1, GO-Sound
///     bei Erreichung der Ziel-Zeit (DEL-045 Schritt 4).
@available(iOS 17.0, macOS 14.0, *)
struct SetRow: View {
    let setIndex: Int
    let exercise: Exercise
    let session: WorkoutSession
    let existingLog: ExerciseLog?
    let previousLog: ExerciseLog?
    /// DEL-097 + DEL-108: Session-Lock fuer time-based Halte-Timer auf
    /// **Set-Ebene** (Exercise × setIndex). Nil = Slot frei. Die SetRow
    /// setzt diesen Slot in `startCountdown()`, raeumt ihn in
    /// `stopHoldAndLog()` wieder ab. Andere Rows (same exercise different
    /// set, ODER cross-exercise) lesen den Slot fuer ihren Disabled-Hint.
    @Binding var activeTimedSet: ActiveTimedSetID?
    /// UX-203: Markiert die "naechste anstehende" Set-Row in der Card.
    /// Genau ein Set in jeder ExerciseCard ist aktiv (der erste mit
    /// `existingLog == nil`). Wenn alle Sets completed sind oder dieser
    /// Set später kommt, bleibt das false — die Row rendert dann im
    /// neutralen "upcoming"-Style.
    let isActiveSet: Bool
    /// Called when the user taps the checkmark on an editable row.
    /// DEL-058: `LoggedSetValues` bundle ersetzt das frueher dreistellige
    /// (weight, reps, rir)-Tuple, damit Cardio-Felder (distance, duration)
    /// mitwandern koennen ohne dass jede Callsite umgeschrieben wird.
    let onLogged: (LoggedSetValues) -> Void
    /// Called when the user taps a completed row to revert it back to editable.
    /// Parent (ExerciseCard) is responsible for deleting the corresponding
    /// `ExerciseLog` from the model context.
    let onUnlog: () -> Void

    @State private var weight: Double?
    @State private var reps: Int = 0
    @State private var rir: Float = 2.0
    @State private var didInit = false

    /// DEL-058 Cardio-State. Wird nur initialisiert + befuellt wenn die
    /// Uebung `.isCardio == true` ist; ansonsten bleiben die Felder leer.
    @State private var cardioDistanceText: String = ""
    @State private var cardioDurationText: String = ""

    /// DEL-040: Zustands-Maschine fuer den Halte-Timer bei isTimeBased-Uebungen.
    @State private var holdState: HoldState = .idle
    @State private var holdTimer: Timer?

    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true

    /// DEL-072: Accessibility — respektiere die System-Praeferenz "Reduce
    /// Motion". Wenn true, ersetzen wir Spring-Animationen durch ruhige
    /// `easeInOut`-Variante.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// DEL-072: Dynamic-Type-skalierter Checkmark-Icon-Size. Default 28pt
    /// fuer system-default-Schriftgroesse; skaliert proportional bei
    /// groesseren Stufen.
    @ScaledMetric(relativeTo: .title2) private var checkmarkIconSize: CGFloat = 28

    /// DEL-085: Popover-State fuer den Plate-Calculator. UI ist nur fuer
    /// Strength-Lifts mit Gewicht > 0 sinnvoll — Bodyweight / Cardio /
    /// TimeBased blenden den Button aus.
    @State private var showingPlatePopover = false
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"
    @AppStorage("pref_bar_weight_kg") private var barWeightKgRaw: Double = 20

    enum HoldState: Equatable {
        case idle
        case countingDown(secondsLeft: Int)
        case holding(elapsedSeconds: Int)
    }

    private var isCompleted: Bool { existingLog != nil }

    /// DEL-060: explizite Drei-Wege-Verzweigung der UI nach Uebungs-
    /// Kategorie. Cardio gewinnt VOR TimeBased — falls jemals jemand
    /// versehentlich beide Flags setzt, soll lieber Cardio-Eingabe
    /// erscheinen (sonst sucht der User vergeblich nach Distanz-Feld).
    ///
    /// Vier konzeptionelle Modi nach Ticket:
    ///   1. Cardio (Run/Bike) → CardioSetRow (Distanz/Dauer/Pace)
    ///   2. TimeBased (Plank/Wall-Sit) → Hold-Timer-Card mit Countdown
    ///   3. Bodyweight → Strength-UI mit BW-Placeholder (DEL-045-Update,
    ///      kein eigener Branch — der "kg"-Input ist optional und nimmt
    ///      `nil` als "Bodyweight" entgegen)
    ///   4. Strength (Standard) → compactSetRow mit kg + Wdh
    var body: some View {
        if exercise.isCardio {
            // DEL-058: dedizierte CardioSetRow mit Distanz / Dauer / Pace.
            cardioSetRow
                .onAppear { initializeOnce() }
        } else if exercise.isTimeBased {
            // Time-based: Hold-Timer-Card mit 3-2-1 Countdown +
            // automatischem Speichern (DEL-040 + DEL-045 Schritt 4).
            timeBasedSetView
                .onAppear { initializeOnce() }
                .onDisappear { invalidateHoldTimer() }
        } else {
            // Strength (inkl. Bodyweight per BW-Placeholder): kompaktes
            // Layout (DEL-045 Schritt 1+2).
            compactSetRow
                .onAppear { initializeOnce() }
        }
    }

    // MARK: - DEL-045 Compact Set Row (Strength + Cardio)

    /// Kompaktes Layout: Satz-Nummer, KG, Wdh, Spacer, Checkmark — alle in
    /// einer HStack. RIR-Slider darunter in einem ZStack mit fester Hoehe,
    /// damit das Toggle isCompleted↔editable keinen Layout-Shift triggert.
    ///
    /// UX-203 Layering der Visual-States:
    ///   * completed → ganze Row Opacity 0.55, kein Background
    ///   * active    → leichter DeltiqOrange-Tint (8% Fill) + 3pt Brand-
    ///                 Akzent am linken Rand. Der User sieht sofort,
    ///                 welche Row als naechstes dran ist.
    ///   * upcoming  → neutral, kein Background, kein Akzent
    private var compactSetRow: some View {
        VStack(spacing: 10) {
            // Layout-Fix 2026-05-21: HStack-Spacing 12 → 8. Auf iPhone-SE
            // (375pt Bildschirm) ist die HStack mit 7 Children (Set-Nummer,
            // weightInput, "KG", plateCalcButton, repsInput, "WDH",
            // Checkmark) plus Spacer knapp am Overflow — mit 12pt Spacing
            // zwischen jeden zwei kommt zu viel Luft zusammen, mit 8pt
            // bleibt's auch bei 3-stelligem Gewicht (125 kg) komfortabel.
            HStack(spacing: 8) {
                // DEL-059 + UX-203: Rounded-Design + monospacedDigit fuer
                // konsistente Zahlen-Ausrichtung (sonst springt der Slot
                // zwischen 1-stellig und 2-stellig). Active-Set bekommt
                // Brand-Color, completed bleibt secondary, upcoming primary.
                Text("\(setIndex + 1)")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(setNumberColor)
                    .frame(width: 24, alignment: .leading)

                if !exercise.isCardio {
                    weightInput
                    // DEL-128: KG-Label via xcstrings.
                    // Layout-Fix 2026-05-21: `.fixedSize()` zwingt das Label
                    // auf seine intrinsische Breite — sonst komprimiert
                    // SwiftUI die Text-Labels weg, wenn der Row-Inhalt
                    // (3-stelliges Gewicht + Plate-Button + 2 Inputs +
                    // Labels) auf iPhone-SE-Breite knapp wird.
                    Text("unit.kg.upper", bundle: .module)
                        .deltiqLabel()
                        .fixedSize()
                    // DEL-085: Plate-Calculator-Quick-Access. Nur sichtbar,
                    // wenn ein konkretes Gewicht eingegeben ist UND die Uebung
                    // ueberhaupt mit einer Hantelstange ausgefuehrt wird —
                    // also nicht bei Bodyweight (weight nil/0) und nicht bei
                    // TimeBased.
                    if let w = weight, w > 0, !exercise.isTimeBased {
                        plateCalculatorButton(weight: w)
                    }
                }

                repsInput
                // DEL-128: WDH/REPS/TKR — reuse `unit.reps.short` (lowercase
                // "Wdh"/"reps"/"tkr") und uppercase im Caller. ASCII-Strings,
                // kein Unicode-Drama mit `.uppercased()`.
                // Layout-Fix 2026-05-21: identischer `.fixedSize()`-Schutz.
                Text(String(localized: "unit.reps.short", bundle: .module).uppercased())
                    .deltiqLabel()
                    .fixedSize()

                Spacer(minLength: 6)

                checkmarkButton
            }

            // Status-Container mit FESTER HOEHE — verhindert Layout-Shift beim
            // Toggle isCompleted↔editable. UX-203: 28 → 38 fuer den RIR-
            // Slider, damit Slider + Wert + previous-Hint nicht mehr in
            // einer 28pt-Klemme stecken.
            statusZone
                .frame(height: 38)
                .padding(.leading, 36)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowStateBackground)
        )
        .overlay(alignment: .leading) {
            // UX-203: 3pt-Brand-Akzent links bei der aktiven Row. Wirkt wie
            // ein "du-bist-hier"-Marker und ist im Dark-Mode auch ohne
            // Background-Tint sichtbar.
            if isActiveSet {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.deltiqOrange)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .opacity(isCompleted ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .animation(.easeInOut(duration: 0.2), value: isActiveSet)
        .contentShape(Rectangle())
        // DEL-045 Schritt 2: Tap auf completed-Row revert zurueck zu editable.
        .onTapGesture {
            if isCompleted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onUnlog()
                }
            }
        }
    }

    /// UX-203: 3-State-Background.
    /// - completed → clear (Opacity macht das Dimming)
    /// - active    → 8% DeltiqOrange-Fill
    /// - upcoming  → clear
    private var rowStateBackground: Color {
        if isCompleted { return .clear }
        if isActiveSet { return Color.deltiqOrange.opacity(0.08) }
        return .clear
    }

    /// UX-203: Set-Nummer-Farbe je nach State.
    /// - completed → secondary (dim)
    /// - active    → DeltiqOrange (Brand-Akzent matched left border)
    /// - upcoming  → primary (neutral, voll sichtbar)
    private var setNumberColor: Color {
        if isCompleted { return .secondary }
        if isActiveSet { return Color.deltiqOrange }
        return .primary
    }

    /// DEL-085: Quick-Access-Button fuer den Plate-Calculator. Wird neben
    /// dem KG-Feld eingeblendet, wenn ein konkretes Gewicht > 0 eingetragen
    /// ist UND die Uebung mit einer Hantelstange ausgefuehrt wird (also
    /// keine Bodyweight-/Cardio-/TimeBased-Lifts). Tap oeffnet ein Popover
    /// mit der Aufladungs-Visualisierung — der eigentliche Content lebt in
    /// `PlatePopoverContent` weiter unten.
    @ViewBuilder
    private func plateCalculatorButton(weight: Double) -> some View {
        Button {
            showingPlatePopover = true
        } label: {
            Image(systemName: "scalemass.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
                .font(.callout)
                .frame(width: 28, height: 28)
                .background(Color.deltiqOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hantel-Aufladung anzeigen")
        .popover(isPresented: $showingPlatePopover, arrowEdge: .top) {
            PlatePopoverContent(
                targetWeight: weight,
                barWeight: barWeightKgRaw,
                unitRaw: weightUnitRaw
            )
            .padding(16)
            .frame(minWidth: 260, idealWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var weightInput: some View {
        // DEL-045-Update: Bodyweight-Fix. Placeholder ist "BW" — wenn der User
        // das Feld leer laesst, wird der Satz als 0.0 kg geloggt (Liegestuetze,
        // Pull-ups, etc.). Kein Validierungs-Blocker mehr auf weight.
        // DEL-091: Bei einer eben gewappten Uebung (`swappedFromOriginal != nil`)
        // hat der Migrator `suggestedWeight = nil` gesetzt — die alte Last
        // passt selten zum neuen Bewegungsablauf. Statt eines nackten "-"-
        // oder "BW"-Placeholders zeigen wir einen klaren Hint, dass das
        // Gewicht hier neu kalibriert werden muss.
        TextField(weightPlaceholder, value: $weight, format: .number, prompt: Text(weightPlaceholder))
            .decimalKeyboard()
            .monospacedDigit()
            .frame(width: 56)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .innerLightStroke(cornerRadius: 8)
            .multilineTextAlignment(.center)
            .disabled(isCompleted)
            .opacity(isCompleted ? 0.6 : 1.0)
    }

    /// DEL-091: dynamisches Placeholder-Wording.
    ///   * Fresh-swap (Original archived) → "→ kg" (Pfeil signalisiert
    ///     "neuer Wert noetig")
    ///   * Bodyweight (kein Suggested + nichts gemerkt) → "BW"
    ///   * Standard → "—"
    private var weightPlaceholder: String {
        if exercise.swappedFromOriginal != nil, weight == nil {
            return "→ kg"
        }
        return "BW"
    }

    private var repsInput: some View {
        TextField("-", value: $reps, format: .number, prompt: Text("-"))
            .decimalKeyboard()
            .monospacedDigit()
            .frame(width: 48)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .innerLightStroke(cornerRadius: 8)
            .multilineTextAlignment(.center)
            .disabled(isCompleted)
            .opacity(isCompleted ? 0.6 : 1.0)
    }

    private var checkmarkButton: some View {
        Button {
            if !isCompleted {
                // UX-204: Light-Impact-Haptik beim Satz-Check — der haptische
                // "Klick" macht das Speichern spuerbar ohne aufdringlich zu
                // werden. Wird VOR der State-Mutation getriggert, damit der
                // Impuls und die Spring-Anim synchron starten.
                DeltiqHaptics.impact(.light)
                // DEL-059 + DEL-072: Snappy Spring fuer wuchtigen Save-Tap.
                // Reduce-Motion-Pfad ersetzt den Spring durch ein ruhiges
                // easeInOut — Apple-HIG-Konform.
                withAnimation(checkmarkAnimation) {
                    logCurrentValues()
                }
            }
            // Bei isCompleted handled der Row-onTapGesture das Revert.
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                // DEL-072: ScaledMetric-Wert statt hard-coded 28pt —
                // skaliert mit Dynamic-Type bei groesseren Schriftgroessen.
                .font(.system(size: checkmarkIconSize))
                // DEL-059: hierarchical-rendering gibt dem Symbol Tiefe
                // (innerer Ring leicht dunkler als Fuellung).
                .symbolRenderingMode(.hierarchical)
                // DEL-087: Warmup/Cooldown-Saetze bekommen graue Checkmark
                // statt der orange Brand-Color — visuell klar abgegrenzt
                // von den Working-Sets.
                .foregroundStyle(checkmarkColor)
                // DEL-059: Bounce — kurz auf 1.06 wenn completed.
                // DEL-072: bei Reduce-Motion KEIN Bounce.
                .scaleEffect((isCompleted && !reduceMotion) ? 1.06 : 1.0)
                .accessibilityLabel(isCompleted ? "Satz fertig" : "Satz speichern")
                .accessibilityHint(isCompleted
                    ? "Doppeltippe, um den Satz zur Bearbeitung zurueckzuholen"
                    : "Doppeltippe, um den Satz zu speichern")
        }
        .buttonStyle(.plain)
        .disabled(!canLog && !isCompleted)
        .opacity((!canLog && !isCompleted) ? 0.4 : 1.0)
    }

    /// DEL-072: Animation-Variante je nach Reduce-Motion-Praeferenz.
    private var checkmarkAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)
    }

    /// DEL-087: Checkmark-Farbe je nach Exercise-Rolle und Completed-State.
    /// Working-Sets bekommen die Brand-Color (DeltiqOrange); Warmup/Cooldown
    /// gehen auf Grau — klar abgegrenzt vom "echten" Progressions-Lift.
    private var checkmarkColor: Color {
        if isCompleted {
            return exercise.role.skipsProgression
                ? Color.secondary
                : Color.deltiqOrange
        }
        return Color.secondary.opacity(0.5)
    }

    /// ZStack mit fester Hoehe (per `.frame(height: 28)` am Caller).
    /// - editable: RIR-Slider mit Label
    /// - completed: Status-Text "vor X Sek abgeschlossen" + Previous-Hint
    @ViewBuilder
    private var statusZone: some View {
        if isCompleted, let log = existingLog {
            // Status-Text — gleicher Container-Slot, kein Springen.
            Text(completedSummary(log))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if !exercise.isCardio {
            // UX-203: HStack-Spacing 10 → 14, plus dedizierte Slider-min-
            // Höhe via .frame(height: 24), damit der Touch-Bereich nicht
            // mehr aus dem 28pt-Container gedrückt wird. Previous-Hint
            // bekommt explizite .caption2 + .tertiary → klar als ruhige
            // Sekundär-Info abgesetzt vom RIR-Wert.
            HStack(spacing: 14) {
                // Layout-Fix 2026-05-21: `.fixedSize()` damit der RIR-Label
                // im engen Slider-Zone-Layout nicht komprimiert wird.
                Text("RIR").deltiqLabel().fixedSize()
                Slider(
                    value: Binding(
                        get: { Double(rir) },
                        set: { rir = Float($0) }
                    ),
                    in: 0...5,
                    step: 0.5
                )
                .tint(Color.deltiqOrange)
                .frame(minHeight: 24)
                Text(formatRIR(rir))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(width: 32, alignment: .trailing)
                if let prev = previousLog {
                    Text("· letztes: \(previousLogHint(prev))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        } else {
            // Cardio editable: kein RIR, nur evtl. Hint
            if let prev = previousLog {
                Text("letztes: \(previousLogHint(prev))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
            }
        }
    }

    private func completedSummary(_ log: ExerciseLog) -> String {
        // DEL-128: Sek/Wdh-Unit-Label via xcstrings.
        let rel = log.date.formatted(.relative(presentation: .named))
        if exercise.isCardio {
            let unit = exercise.isTimeBased
                ? String(localized: "unit.seconds.short", bundle: .module)
                : String(localized: "unit.reps.short", bundle: .module)
            return "\(log.reps) \(unit) · \(rel)"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps) (RIR \(formatRIR(log.rir))) · \(rel)"
    }

    // MARK: - DEL-040 + DEL-045 Schritt 4: Hold-Timer (isTimeBased)

    @ViewBuilder
    private var timeBasedSetView: some View {
        switch holdState {
        case .idle:
            holdIdleView
        case .countingDown(let secondsLeft):
            holdCountdownView(secondsLeft: secondsLeft)
        case .holding(let elapsed):
            holdRunningView(elapsedSeconds: elapsed)
        }
    }

    private var holdIdleView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: String(localized: "set.numberLabel", bundle: .module), setIndex + 1))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isCompleted, let log = existingLog {
                    // DEL-128: Sek-Unit aus xcstrings.
                    let secUnit = String(localized: "unit.seconds.short", bundle: .module)
                    Text("\(log.reps) \(secUnit) · \(log.date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !isCompleted {
                // DEL-128: "Ziel: X Sek halten" via xcstrings-Format.
                Text(String(format: String(localized: "holdTimer.target.format", bundle: .module),
                            targetHoldSeconds))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                // DEL-097: Wenn eine ANDERE Time-Exercise schon laeuft,
                // zeigen wir statt des Start-Buttons einen disabled-Hinweis
                // mit Bezug auf die blockierende Uebung.
                if isBlockedByOtherTimedExercise {
                    blockedByOtherTimerHint
                } else {
                    Button {
                        startCountdown()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("Start")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.deltiqOrange.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation { onUnlog() }
                } label: {
                    Label("Korrigieren", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    /// DEL-097: Disabled-Pseudo-Button, der anstelle des "Start"-CTAs
    /// erscheint, wenn eine andere zeitbasierte Uebung gerade laeuft.
    /// Tippbar bleibt nichts — wir wollen den User explizit zwingen, zur
    /// laufenden Uebung zurueckzunavigieren und sie abzuschliessen.
    private var blockedByOtherTimerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(blockingMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("set.lockedHint", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(0.85)
        .accessibilityLabel(blockingMessage + ". Beende die laufende Übung zuerst.")
    }

    /// DEL-097 + DEL-108: True wenn der Session-weite Time-Set-Lock von
    /// einem ANDEREN Satz gehalten wird (gleiche oder fremde Uebung —
    /// egal, jeder andere Satz blockt). Delegiert an `TimedExerciseGuard.
    /// isBlockedByOther` (Core) mit dem zusammengesetzten Set-Identifier.
    private var isBlockedByOtherTimedExercise: Bool {
        TimedExerciseGuard.isBlockedByOther(
            candidateID: myTimedSetID,
            candidateIsTimeBased: exercise.isTimeBased,
            activeTimedExerciseID: activeTimedSet
        )
    }

    /// Compound-Key fuer den Lock. exerciseName wird denormalisiert
    /// mitgespeichert, damit blockierte Rows den Namen ohne weiteren
    /// Lookup ins UI bringen koennen.
    private var myTimedSetID: ActiveTimedSetID {
        ActiveTimedSetID(
            exerciseID: exercise.persistentModelID,
            setIndex: setIndex,
            exerciseName: exercise.name
        )
    }

    /// Anzeige-String fuer den Blocked-Hint. Same-exercise different-set
    /// (z.B. "Plank Satz 1 läuft, du bist auf Satz 2") und cross-exercise
    /// (z.B. "Plank läuft, du bist auf Wall Sit") werden mit der gleichen
    /// Formulierung abgedeckt — der User sieht eh nur die Row, in der er
    /// gerade ist, und weiss, was er als naechstes machen muss.
    private var blockingMessage: String {
        if let name = activeTimedSet?.exerciseName, !name.isEmpty {
            return "„\(name)“ läuft bereits"
        }
        return "Eine andere zeitbasierte Übung läuft bereits"
    }

    private func holdCountdownView(secondsLeft: Int) -> some View {
        VStack(spacing: 6) {
            // UX-203: Mono-Digits, damit der 3/2/1-Countdown visuell stabil
            // bleibt (Proportional-Glyphen liessen die Zahl pro Sekunde
            // leicht "wackeln", weil die Glyph-Breite je Ziffer variiert).
            Text(secondsLeft == 0 ? "GO!" : "\(secondsLeft)")
                .font(.system(size: 80, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.deltiqOrange)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: secondsLeft)
            Text(secondsLeft == 0 ? "Los geht's!" : "Mach dich bereit ...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func holdRunningView(elapsedSeconds elapsed: Int) -> some View {
        let target = targetHoldSeconds
        let progress = min(1.0, Double(elapsed) / Double(max(target, 1)))
        let reached = elapsed >= target
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(elapsed)")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(reached ? Color.deltiqOrange : .primary)
                    .contentTransition(.numericText())
                // DEL-128: SEK/SEC/SN reuse `unit.seconds.short` + uppercase.
                Text("/ \(target) \(String(localized: "unit.seconds.short", bundle: .module).uppercased())")
                    .deltiqLabel()
                Spacer()
                if reached {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)   // DEL-059
                        .foregroundStyle(Color.deltiqOrange)
                        .scaleEffect(1.05)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(reached ? Color.deltiqOrange : Color.deltiqOrange.opacity(0.6))
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())

            Button {
                stopHoldAndLog()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "stop.fill")
                    Text(reached ? "Satz speichern" : "Stoppen & speichern")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.deltiqOrange.opacity(reached ? 0.30 : 0.18))
                .foregroundStyle(Color.deltiqOrange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var targetHoldSeconds: Int {
        exercise.repsMin > 0 ? exercise.repsMin : 30
    }

    /// 3-Sekunden-Countdown mit Per-Sekunde-Beeps. Bei 3/2/1 ertoent ein
    /// kurzer System-Beep, bei 0 (= "GO!") ein laengerer, tieferer Ton.
    /// Erfuellt DEL-045 Schritt 3-Audio.
    /// DEL-097 + DEL-108: Lock-Claim direkt beim Countdown-Start. Slot-
    /// Identifier ist jetzt set-level (Exercise × setIndex), nicht mehr
    /// exercise-only. Damit blockt der naechste Plank-Satz, solange der
    /// vorige noch laeuft — Regression von DEL-097 geschlossen.
    private func startCountdown() {
        // Defensive — UI rendert den Button schon disabled, aber wenn
        // jemand die View aus einem anderen Pfad fired (Voice Control,
        // Tests), wollen wir den Lock-Check trotzdem haben.
        guard !isBlockedByOtherTimedExercise else { return }
        activeTimedSet = myTimedSetID
        holdState = .countingDown(secondsLeft: 3)
        playCountdownBeep()   // initial Beep fuer "3"
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                guard case .countingDown(let left) = holdState else {
                    timer.invalidate()
                    return
                }
                if left > 1 {
                    holdState = .countingDown(secondsLeft: left - 1)
                    playCountdownBeep()
                } else if left == 1 {
                    holdState = .countingDown(secondsLeft: 0)
                    playGoSound()
                } else {
                    timer.invalidate()
                    startHolding()
                }
            }
        }
    }

    private func startHolding() {
        holdState = .holding(elapsedSeconds: 0)
        let target = targetHoldSeconds
        var didFireFinishedFeedback = false
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                guard case .holding(let elapsed) = holdState else {
                    timer.invalidate()
                    return
                }
                let next = elapsed + 1
                holdState = .holding(elapsedSeconds: next)
                if next == target && !didFireFinishedFeedback {
                    didFireFinishedFeedback = true
                    triggerHoldCompleteFeedback()
                }
            }
        }
    }

    private func stopHoldAndLog() {
        invalidateHoldTimer()
        guard case .holding(let elapsed) = holdState else { return }
        // DEL-040: TimeBased speichert die Hold-Sekunden in `reps` —
        // historische Convention, bleibt fuer Backward-Compat erhalten.
        // DEL-060: ZUSAETZLICH `durationSeconds` setzen, sodass spaetere
        // Analytik einheitlich auf das Duration-Feld zugreifen kann (statt
        // Sonderfall fuer TimeBased zu pflegen). `distanceKm` bleibt nil —
        // Plank/Wall-Sit haben keine Distanz.
        onLogged(LoggedSetValues(
            weight: 0,
            reps: elapsed,
            rir: 0,
            distanceKm: nil,
            durationSeconds: elapsed
        ))
        holdState = .idle
        // DEL-097: Lock freigeben — nur wenn WIR ihn gehalten haben.
        // Defensive Identity-Check, falls zwei Threads parallel den Slot
        // beruehren (sollte nicht passieren, schadet aber nichts).
        releaseTimedExerciseLockIfHeld()
    }

    /// DEL-097 + DEL-108: Identity-checked Lock-Release. Wird auch vom
    /// Countdown-Abbruch (Tap waehrend "GO!") und vom `unlog`-Pfad genutzt,
    /// damit der Slot nicht verwaist haengen bleibt.
    /// Equality auf `ActiveTimedSetID` ist `(exerciseID, setIndex)` —
    /// exerciseName ist nur Display.
    private func releaseTimedExerciseLockIfHeld() {
        if activeTimedSet == myTimedSetID {
            activeTimedSet = nil
        }
    }

    private func invalidateHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    // MARK: - Audio + Haptic Helpers

    /// Kurzer hoher Beep bei jedem Countdown-Tick (3, 2, 1). DEL-045-Update
    /// Punkt 4: AVAudioPlayer + `beep_short.wav` statt System-Sound.
    private func playCountdownBeep() {
        if timerSoundEnabled {
            TimerSoundPlayer.shared.playShort()
        }
        #if canImport(UIKit) && !os(watchOS)
        if timerHapticsEnabled {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }

    /// Laengerer, deutlich anderer Ton fuer "GO" (Start-Signal). DEL-045-
    /// Update Punkt 4: AVAudioPlayer + `beep_long.wav` statt System-Sound.
    private func playGoSound() {
        if timerSoundEnabled {
            TimerSoundPlayer.shared.playLong()
        }
        #if canImport(UIKit) && !os(watchOS)
        if timerHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    /// Sound + Haptic beim Erreichen der Ziel-Hold-Zeit.
    private func triggerHoldCompleteFeedback() {
        #if canImport(UIKit) && !os(watchOS)
        if timerHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
        if timerSoundEnabled {
            // Auch hier der laengere Ton — gleicher GO-Klang als "Du hast es
            // geschafft"-Signal.
            TimerSoundPlayer.shared.playLong()
        }
    }

    // MARK: - State init / formatting / logging

    private func previousLogHint(_ log: ExerciseLog) -> String {
        // DEL-128: Sek-Unit aus xcstrings.
        if exercise.isTimeBased {
            let secUnit = String(localized: "unit.seconds.short", bundle: .module)
            return "\(log.reps) \(secUnit)"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps)"
    }

    private func initializeOnce() {
        guard !didInit else { return }
        didInit = true

        // Wenn die Row als bereits-geloggt erscheint (z.B. nach Re-Render),
        // dann nehme die Werte aus dem existingLog statt vom previousLog.
        // Damit zeigen die TextFields nach Tap auf "Unlog" die richtigen
        // Werte des gerade entfernten Logs an.
        if let log = existingLog {
            weight = log.weight > 0 ? log.weight : exercise.suggestedWeight
            reps = log.reps
            rir = log.rir
            // DEL-058 Cardio init aus existing log.
            if let d = log.distanceKm, d > 0 {
                cardioDistanceText = d == d.rounded()
                    ? "\(Int(d))" : d.truncated(to: 2).formattedTwoDecimals
            }
            if let s = log.durationSeconds, s > 0 {
                cardioDurationText = PaceCalculator.formatDuration(s)
            }
        } else if let previousLog {
            weight = previousLog.weight > 0 ? previousLog.weight : exercise.suggestedWeight
            reps = previousLog.reps
            rir = previousLog.rir
            // DEL-058 Cardio init aus previousLog — Felder bleiben leer, der
            // Placeholder zeigt die letzten Werte als Hint. Kein Pre-Fill
            // wuerde den User zwingen, das Feld zu loeschen, BEVOR er heute
            // tippt — bei Lauf-Logs nicht erwuenscht.
        } else {
            weight = exercise.suggestedWeight
            reps = midpoint(exercise.repsMin, exercise.repsMax)
            rir = exercise.targetRir
        }
    }

    private func midpoint(_ a: Int, _ b: Int) -> Int { (a + b) / 2 }

    /// DEL-045-Update: Bodyweight-Fix. Strength: speicherbar sobald reps > 0
    /// (Gewicht optional, leer = 0).
    /// DEL-058: Cardio: speicherbar sobald Distanz ODER Dauer geparsed werden
    /// kann — User soll z.B. nur eine Dauer eintragen koennen ohne Distanz
    /// (Pace bleibt dann undefined, aber das Workout zaehlt).
    private var canLog: Bool {
        if exercise.isCardio {
            let hasDistance = PaceCalculator.parseDistanceToKm(cardioDistanceText) != nil
            let hasDuration = PaceCalculator.parseDurationToSeconds(cardioDurationText) != nil
            return hasDistance || hasDuration
        }
        return reps > 0
    }

    private func logCurrentValues() {
        guard canLog else { return }
        // Tastatur sofort dismissen — keyboardDismissToolbar liefert auf iOS
        // keinen "Fertig"-Button mehr, daher hier explizit resignen (DEL-045-
        // Update Punkt 3).
        dismissKeyboard()
        let values: LoggedSetValues
        if exercise.isCardio {
            // DEL-058: Cardio → Distanz/Dauer parsen, reps/weight/rir bleiben 0.
            values = LoggedSetValues(
                weight: 0,
                reps: 0,
                rir: 0,
                distanceKm: PaceCalculator.parseDistanceToKm(cardioDistanceText),
                durationSeconds: PaceCalculator.parseDurationToSeconds(cardioDurationText)
            )
        } else {
            // Strength (oder Time-Based hold, das ueber stopHoldAndLog laeuft).
            let w = exercise.isTimeBased ? 0.0 : (weight ?? 0)
            values = LoggedSetValues(weight: w, reps: reps, rir: rir)
        }
        onLogged(values)
    }

    /// Resigne der gerade-fokussierten responder-Kette. iOS-only; auf macOS
    /// ein No-Op (es gibt dort keine On-Screen-Tastatur).
    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatRIR(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }

    // MARK: - DEL-058 Cardio Set Row

    /// Cardio-Eingabe: Distanz (km) + Dauer (MM:SS) + Live-Pace + Checkmark.
    /// DEL-061: Tighter spacing + feste Label-Breiten, damit auf iPhone-SE
    /// (375pt) nichts mehr abgeschnitten wird. KM-Label sitzt in eigener
    /// 24pt-Box, ZEIT/min-Label entfaellt komplett zugunsten von Pace
    /// rechtsbuendig.
    @ViewBuilder
    private var cardioSetRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // UX-203: Mono-Digits + state-aware Color (siehe compactSetRow).
                Text("\(setIndex + 1)")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(setNumberColor)
                    .frame(width: 20, alignment: .leading)

                cardioDistanceInput
                cardioDurationInput

                Spacer(minLength: 4)

                // DEL-061: Pace-Anzeige rechtsbuendig, eigene fixe Box,
                // schrumpft notfalls mit minimumScaleFactor statt umzubrechen.
                cardioPaceLabel

                checkmarkButton
            }

            // UX-203: 28 → 36, gleicher Breathing-Room-Step wie statusZone
            // im Strength-Pfad.
            cardioStatusZone
                .frame(height: 36)
                .padding(.leading, 28)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowStateBackground)
        )
        .overlay(alignment: .leading) {
            if isActiveSet {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.deltiqOrange)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .opacity(isCompleted ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .animation(.easeInOut(duration: 0.2), value: isActiveSet)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompleted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onUnlog()
                }
            }
        }
    }

    /// DEL-061: feste TextField-Breite + fest verankertes KM-Label, damit
    /// auf iPhone-SE-Breite nichts ueberlappt oder abgeschnitten wird.
    private var cardioDistanceInput: some View {
        HStack(spacing: 4) {
            TextField("0.0", text: $cardioDistanceText, prompt: Text(cardioDistancePlaceholder))
                .decimalKeyboard()
                .monospacedDigit()
                .frame(width: 55)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .innerLightStroke(cornerRadius: 8)
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .opacity(isCompleted ? 0.6 : 1.0)
            Text("KM")
                .deltiqLabel()
                .frame(width: 22, alignment: .leading)   // fix → kein Cut
        }
    }

    /// DEL-061: das frueher hinten dranhaengende "min"-Label entfaellt — die
    /// MM:SS-Convention reicht visuell. Kein Label = mehr Platz fuer das
    /// breitere Pace-Display rechts.
    private var cardioDurationInput: some View {
        TextField("MM:SS", text: $cardioDurationText, prompt: Text(cardioDurationPlaceholder))
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #endif
            .monospacedDigit()
            .frame(width: 65)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .innerLightStroke(cornerRadius: 8)
            .multilineTextAlignment(.center)
            .disabled(isCompleted)
            .opacity(isCompleted ? 0.6 : 1.0)
    }

    /// Live-Pace-Anzeige in Neon-Orange. Recomputed pro Tastenanschlag
    /// dank `@State`-Bindings auf den Text-Feldern.
    /// DEL-061: rechtsbuendig, fixe Box, `.lineLimit(1)` +
    /// `.minimumScaleFactor(0.8)` als Fallback bei langen Pace-Werten
    /// (z.B. "12:45 /km" Walk-Pace).
    private var cardioPaceLabel: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("PACE").deltiqLabel()
            Text(currentPace)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.deltiqOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 72, alignment: .trailing)
    }

    private var currentPace: String {
        let km = PaceCalculator.parseDistanceToKm(cardioDistanceText)
        let secs = PaceCalculator.parseDurationToSeconds(cardioDurationText)
        return PaceCalculator.pace(distanceKm: km, durationSeconds: secs)
    }

    /// Placeholder im Distanz-Feld: target aus dem Plan, sonst leer.
    private var cardioDistancePlaceholder: String {
        guard let target = exercise.targetDistanceKm else { return "km" }
        return target == target.rounded()
            ? "\(Int(target))"
            : target.truncated(to: 2).formattedTwoDecimals
    }

    /// Placeholder im Dauer-Feld: target aus dem Plan in MM:SS, sonst leer.
    private var cardioDurationPlaceholder: String {
        guard let mins = exercise.targetDurationMinutes else { return "MM:SS" }
        return "\(mins):00"
    }

    /// Statuszeile unter den Inputs — abgeschlossener Set zeigt geloggtes
    /// Resultat, editable State zeigt previous-Run-Hint (falls vorhanden).
    @ViewBuilder
    private var cardioStatusZone: some View {
        if isCompleted, let log = existingLog {
            Text(cardioCompletedSummary(log))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let prev = previousLog,
                  prev.distanceKm != nil || prev.durationSeconds != nil {
            Text("letztes: \(cardioPreviousHint(prev))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
        }
    }

    private func cardioCompletedSummary(_ log: ExerciseLog) -> String {
        let rel = log.date.formatted(.relative(presentation: .named))
        let bits = cardioBitsString(distance: log.distanceKm, duration: log.durationSeconds)
        return "\(bits) · \(rel)"
    }

    private func cardioPreviousHint(_ log: ExerciseLog) -> String {
        cardioBitsString(distance: log.distanceKm, duration: log.durationSeconds)
    }

    /// Format: "5,20 km · 28:30 · 5:29 /km" — leere Felder werden ausgelassen.
    private func cardioBitsString(distance: Double?, duration: Int?) -> String {
        var parts: [String] = []
        if let distance, distance > 0 {
            let dStr = distance == distance.rounded()
                ? "\(Int(distance))"
                : distance.truncated(to: 2).formattedTwoDecimals
            parts.append("\(dStr) km")
        }
        if let duration, duration > 0 {
            parts.append(PaceCalculator.formatDuration(duration))
        }
        if let distance, let duration, distance > 0, duration > 0,
           let pace = PaceCalculator.minutesPerKm(distanceKm: distance, durationSeconds: duration) {
            parts.append(PaceCalculator.formatPace(pace))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - DEL-085 PlatePopoverContent

/// Kompakte Plate-Calculator-Ansicht fuer das Popover in SetRow. Reusable
/// auch von anderen Quick-Access-Punkten.
@available(iOS 17.0, macOS 14.0, *)
private struct PlatePopoverContent: View {
    let targetWeight: Double
    let barWeight: Double
    let unitRaw: String

    private var unit: PlateCalculator.Unit {
        PlateCalculator.Unit(rawValue: unitRaw) ?? .kg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("barbell.loading.title", bundle: .module)
                } icon: {
                    Image(systemName: "scalemass.fill")
                }
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                Text("\(formatWeight(targetWeight)) \(unit.rawValue)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color.deltiqOrange)
            }
            Text("Stange: \(formatWeight(barWeight)) \(unit.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // DEL-085 / DEL-092-Fix: PlateCalculator.calculate liefert ein
            // flaches `[PlateConfig]`, KEIN Wrapper-Struct mit `.plates` /
            // `.actualWeight`. `actualWeight` rechnen wir manuell (Stange +
            // 2× pro-Seite-Summe) — selbe Formel wie in PlateCalculatorView.
            let plates = PlateCalculator.calculate(target: targetWeight, bar: barWeight, unit: unit)
            let perSideLoaded = plates.reduce(0.0) { $0 + Double($1.count) * $1.weight }
            let actualWeight = barWeight + 2 * perSideLoaded

            if plates.isEmpty {
                Label {
                    Text("barbell.loading.empty", bundle: .module)
                } icon: {
                    Image(systemName: "minus")
                }
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                // Reuse der existing Visualization, kompakte Hoehe.
                PlateBarVisualization(plates: plates, unit: unit)
                    .frame(height: 84)
                Text(perSideText(plates, unit: unit))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if abs(actualWeight - targetWeight) > 0.01 {
                Text("Erreichbar: \(formatWeight(actualWeight)) \(unit.rawValue) (Δ \(formatWeight(actualWeight - targetWeight)) \(unit.rawValue))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// "Pro Seite: 2× 20 · 1× 10 · 1× 2,5" — kompakter Text-Output der
    /// Aufladungs-Liste, ergaenzt die visuelle Bar.
    ///
    /// Bug-Fix 2026-05-21: vorher las der Code `grouped[w]?.count` —
    /// das ist aber die LAENGE des PlateConfig-Arrays (immer 1, weil
    /// PlateCalculator pro Gewichtsklasse genau einen Eintrag emittiert),
    /// NICHT die Anzahl der Scheiben pro Seite (`PlateConfig.count`).
    /// Resultat: "1× 25 · 1× 2,5" statt korrektem "2× 25 · 1× 2,5"
    /// fuer 125 kg @ 20 kg-Bar. Die visuelle Bar war richtig, der Text
    /// nicht.
    ///
    /// Da PlateCalculator OHNEHIN pro weight nur einen Eintrag liefert
    /// (siehe `calculate()`-Implementation), ist das Dictionary-Grouping
    /// hier auch unnoetig — direkt iterieren ist klarer + bug-frei.
    private func perSideText(_ plates: [PlateConfig], unit: PlateCalculator.Unit) -> String {
        let parts = plates
            .sorted { $0.weight > $1.weight }
            .map { p in "\(p.count)× \(formatWeight(p.weight))" }
        return "Pro Seite: " + parts.joined(separator: " · ") + " \(unit.rawValue)"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }
}

// MARK: - DEL-058 LoggedSetValues

/// Bundle, das alle Felder eines geloggten Satzes durch den `onLogged`-
/// Callback wandern laesst. Vorher war's ein dreistelliges Tuple — DEL-058
/// hat Cardio-Felder (`distanceKm` / `durationSeconds`) dazugeholt; statt
/// jede Callsite umzuschreiben, packen wir alles in eine Wertestruktur.
public struct LoggedSetValues: Sendable, Hashable {
    public let weight: Double
    public let reps: Int
    public let rir: Float
    public let distanceKm: Double?
    public let durationSeconds: Int?

    public init(
        weight: Double,
        reps: Int,
        rir: Float,
        distanceKm: Double? = nil,
        durationSeconds: Int? = nil
    ) {
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
    }
}
#endif
