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

    enum HoldState: Equatable {
        case idle
        case countingDown(secondsLeft: Int)
        case holding(elapsedSeconds: Int)
    }

    private var isCompleted: Bool { existingLog != nil }

    var body: some View {
        if exercise.isTimeBased && !exercise.isCardio {
            // Time-based: ganz anderer Flow (Hold-Timer-Card).
            // DEL-040 + DEL-045 Schritt 4.
            timeBasedSetView
                .onAppear { initializeOnce() }
                .onDisappear { invalidateHoldTimer() }
        } else if exercise.isCardio {
            // DEL-058: dedizierte CardioSetRow mit Distanz / Dauer / Pace.
            cardioSetRow
                .onAppear { initializeOnce() }
        } else {
            // Strength: kompaktes Layout (DEL-045 Schritt 1+2).
            compactSetRow
                .onAppear { initializeOnce() }
        }
    }

    // MARK: - DEL-045 Compact Set Row (Strength + Cardio)

    /// Kompaktes Layout: Satz-Nummer, KG, Wdh, Spacer, Checkmark — alle in
    /// einer HStack. RIR-Slider darunter in einem ZStack mit fester Hoehe,
    /// damit das Toggle isCompleted↔editable keinen Layout-Shift triggert.
    private var compactSetRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("\(setIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24, alignment: .leading)

                if !exercise.isCardio {
                    weightInput
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                repsInput
                Text(exercise.isCardio ? "Wdh" : "Wdh")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                checkmarkButton
            }

            // Status-Container mit FESTER HOEHE — verhindert Layout-Shift beim
            // Toggle isCompleted↔editable.
            statusZone
                .frame(height: 28)
                .padding(.leading, 34)
        }
        .padding(.vertical, 6)
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

    private var weightInput: some View {
        // DEL-045-Update: Bodyweight-Fix. Placeholder ist "BW" — wenn der User
        // das Feld leer laesst, wird der Satz als 0.0 kg geloggt (Liegestuetze,
        // Pull-ups, etc.). Kein Validierungs-Blocker mehr auf weight.
        TextField("BW", value: $weight, format: .number, prompt: Text("BW"))
            .decimalKeyboard()
            .frame(width: 56)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .multilineTextAlignment(.center)
            .disabled(isCompleted)
            .opacity(isCompleted ? 0.6 : 1.0)
    }

    private var repsInput: some View {
        TextField("-", value: $reps, format: .number, prompt: Text("-"))
            .decimalKeyboard()
            .frame(width: 48)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .multilineTextAlignment(.center)
            .disabled(isCompleted)
            .opacity(isCompleted ? 0.6 : 1.0)
    }

    private var checkmarkButton: some View {
        Button {
            if !isCompleted {
                logCurrentValues()
            }
            // Bei isCompleted handled der Row-onTapGesture das Revert.
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(isCompleted ? Color.deltiqOrange : Color.secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!canLog && !isCompleted)
        .opacity((!canLog && !isCompleted) ? 0.4 : 1.0)
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
            HStack(spacing: 10) {
                Text("RIR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(rir) },
                        set: { rir = Float($0) }
                    ),
                    in: 0...5,
                    step: 0.5
                )
                .tint(Color.deltiqOrange)
                Text(formatRIR(rir))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                if let prev = previousLog {
                    Text("· letztes: \(previousLogHint(prev))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        let rel = log.date.formatted(.relative(presentation: .named))
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? "Sek" : "Wdh") · \(rel)"
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
                Text("Satz \(setIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isCompleted, let log = existingLog {
                    Text("\(log.reps) Sek · \(log.date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !isCompleted {
                Text("Ziel: \(targetHoldSeconds) Sek halten")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
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

    private func holdCountdownView(secondsLeft: Int) -> some View {
        VStack(spacing: 6) {
            Text(secondsLeft == 0 ? "GO!" : "\(secondsLeft)")
                .font(.system(size: 80, weight: .black, design: .rounded))
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
                Text("/ \(target) Sek")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if reached {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Color.deltiqOrange)
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
    private func startCountdown() {
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
        // DEL-040: TimeBased speichert die Hold-Sekunden in `reps`. RIR 0
        // (Hold-Timer ist bis-zum-Limit gehalten worden), kein Gewicht.
        onLogged(LoggedSetValues(weight: 0, reps: elapsed, rir: 0))
        holdState = .idle
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
        if exercise.isTimeBased {
            return "\(log.reps) Sek"
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
    /// Statusleiste ist hier ein abgeschlossener Set-Text mit dem Pace-Wert.
    @ViewBuilder
    private var cardioSetRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("\(setIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24, alignment: .leading)

                cardioDistanceInput
                cardioDurationInput
                cardioPaceLabel

                Spacer(minLength: 4)

                checkmarkButton
            }

            // Fixed-Height-Statuszeile wie compactSetRow — verhindert
            // Layout-Shift beim Toggle isCompleted↔editable.
            cardioStatusZone
                .frame(height: 28)
                .padding(.leading, 34)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompleted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onUnlog()
                }
            }
        }
    }

    private var cardioDistanceInput: some View {
        HStack(spacing: 4) {
            TextField("km", text: $cardioDistanceText, prompt: Text(cardioDistancePlaceholder))
                .decimalKeyboard()
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .opacity(isCompleted ? 0.6 : 1.0)
            Text("km").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var cardioDurationInput: some View {
        HStack(spacing: 4) {
            TextField("MM:SS", text: $cardioDurationText, prompt: Text(cardioDurationPlaceholder))
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .frame(width: 70)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .opacity(isCompleted ? 0.6 : 1.0)
            Text("min").font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Live-Pace-Anzeige in Neon-Orange. Recomputed pro Tastenanschlag
    /// dank `@State`-Bindings auf den Text-Feldern.
    private var cardioPaceLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Pace")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(currentPace)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.deltiqOrange)
        }
        .frame(width: 78, alignment: .leading)
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
