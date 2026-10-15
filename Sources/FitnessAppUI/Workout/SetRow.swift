#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppCore
import FitnessAppData
#if canImport(UIKit)
import UIKit
#endif

/// Single row inside an `ExerciseCard` — represents one planned set of an exercise.
///
/// **DEL-045 redesign, Signature-Geruest 2.16 aktualisiert:**
///   - Strength + Cardio: kompaktes Single-Line-Layout
///     `[Satz #] [kg-Input] [Wdh-Input] [Spacer] [RIR-Kapsel] [Checkmark-Icon]`
///     plus optional ausklappbarem RIR-Regler darunter (nur bei Bedarf, kein
///     fester Platzverbrauch mehr fuer ruhende Saetze).
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
    /// DEL-157: Log des Satzes DIREKT DARUEBER in DIESER Session. Dient als
    /// Seed-Quelle fuer dynamisch hinzugefuegte Saetze ("+ Satz") — der neue
    /// Satz erbt Gewicht/Reps/RIR vom darueberliegenden. `nil` fuer den
    /// ersten Satz oder wenn der Satz darueber noch nicht geloggt ist.
    var seedLog: ExerciseLog? = nil
    /// DEL-157: Optionaler Delete-Hook. Non-nil → Long-Press-ContextMenu mit
    /// "Satz entfernen". Der Parent (ExerciseCard) loescht den Log, reindext
    /// die verbleibenden Saetze und dekrementiert `exercise.sets`.
    var onRequestDelete: (() -> Void)? = nil
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
    /// Signature-Geruest 2.16: der RIR-Regler ist nur noch bei Bedarf
    /// eingeblendet (Tap auf `rirCapsule`), statt permanent eine feste
    /// Statuszone zu belegen.
    @State private var rirExpanded = false

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
        // DEL-157: Long-Press-ContextMenu zum Entfernen des Satzes, wenn der
        // Parent einen Delete-Hook liefert (Active-Workout mit >1 Satz).
        if let onRequestDelete {
            rowBody.contextMenu {
                Button(role: .destructive, action: onRequestDelete) {
                    Label {
                        Text("active.set.remove", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        } else {
            rowBody
        }
    }

    @ViewBuilder
    private var rowBody: some View {
        if exercise.isCardio {
            // DEL-058: dedizierte CardioSetRow mit Distanz / Dauer / Pace.
            cardioSetRow
                .onAppear { initializeOnce() }
        } else if exercise.isTimeBased {
            // Time-based: Hold-Timer-Card mit 3-2-1 Countdown +
            // automatischem Speichern (DEL-040 + DEL-045 Schritt 4).
            timeBasedSetView
                .onAppear { initializeOnce() }
                .onDisappear {
                    invalidateHoldTimer()
                    // Bugfix (Audit): ohne dies bleibt `activeTimedSet` fuer
                    // den Rest der Session auf dieser Zeile stehen, wenn sie
                    // waehrend eines laufenden Holds verschwindet (z.B. die
                    // Uebung wird im Ad-Hoc-Workout geloescht) - danach kann
                    // KEINE zeitbasierte Uebung mehr starten
                    // (`isBlockedByOtherTimedExercise` bleibt dauerhaft
                    // `true`). Identity-checked, daher gefahrlos auch beim
                    // gewoehnlichen Wegblaettern aufzurufen.
                    releaseTimedExerciseLockIfHeld()
                }
        } else {
            // Strength (inkl. Bodyweight per BW-Placeholder): kompaktes
            // Layout (DEL-045 Schritt 1+2).
            compactSetRow
                .onAppear { initializeOnce() }
        }
    }

    // MARK: - DEL-045 Compact Set Row (Strength + Cardio)

    /// Kompaktes Layout: Satz-Nummer, KG, Wdh, Spacer, RIR-Kapsel, Checkmark
    /// — alle in einer HStack. Darunter zwei OPTIONALE Zeilen (Signature-
    /// Geruest 2.16): der ausgeklappte RIR-Regler (Tap auf die Kapsel) und
    /// der "letztes Mal"-Vergleich (nur beim aktiven Satz). Ein ruhender Satz
    /// (completed oder upcoming, kein Regler offen) braucht dadurch keine
    /// feste zweite Zone mehr.
    ///
    /// UX-203 Layering der Visual-States:
    ///   * completed → ganze Row Opacity 0.55, kein Background
    ///   * active    → leichter DeltiqOrange-Tint (8% Fill) + 3pt Brand-
    ///                 Akzent am linken Rand. Der User sieht sofort,
    ///                 welche Row als naechstes dran ist.
    ///   * upcoming  → neutral, kein Background, kein Akzent
    private var compactSetRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Layout-Fix 2026-05-21: HStack-Spacing 12 → 8. Auf iPhone-SE
            // (375pt Bildschirm) ist die HStack mit 7 Children (Set-Nummer,
            // weightInput, "KG", plateCalcButton, repsInput, "WDH",
            // Checkmark) plus Spacer knapp am Overflow — mit 12pt Spacing
            // zwischen jeden zwei kommt zu viel Luft zusammen, mit 8pt
            // bleibt's auch bei 3-stelligem Gewicht (125 kg) komfortabel.
            //
            // Bugfix (Nutzer-Feedback, Screenshot Ganzkoerper C/Front Squat):
            // 8pt war bei Hantelübungen (`plateCalcButton` zusätzlich im
            // Layout) weiterhin zu knapp, sobald die RIR-Kapsel einen
            // Halbschritt-Wert zeigt ("RIR 2,5" statt "RIR 2" - zwei Zeichen
            // breiter). Die Eingabezeile ragte dann minimal ueber den
            // Bildschirmrand hinaus; da die Seite in einer `ScrollView`
            // innerhalb der Exercise-TabView sitzt, zentriert SwiftUI den zu
            // breiten Inhalt und beschneidet ihn beidseitig — sichtbar als
            // abgeschnittener Uebungsname links UND abgeschnittene Werte
            // rechts, obwohl nur EIN Element (die Kapsel) tatsaechlich zu
            // breit war. 8 → 6pt (siehe auch `rirCapsule`-Padding unten)
            // schafft den fehlenden Puffer zurueck.
            HStack(spacing: 6) {
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
                    // SwiftUI die Text-Labels weg, wenn der Row-Inhalt knapp
                    // wird.
                    Text("unit.kg.upper", bundle: .module)
                        .deltiqLabel()
                        .fixedSize()
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

                // README 2.25 (Nutzer-Feedback, fuenf Simulator-Screenshots):
                // die Eingabezeile ist mit Satznummer/Gewicht/KG/Aufladung/
                // Wdh/WDH/Haekchen bereits fast voll (340 von 342 pt auf
                // einem 390-pt-Schirm) - die Kapsel war das einzige flexible
                // Kind ohne `.fixedSize()`/`.lineLimit(1)` und bekam nur die
                // verbleibenden ~2pt, der Wert brach darin Zeichen fuer
                // Zeichen um. Bei aufgeklapptem Satz zieht die Kapsel jetzt
                // in `rirSliderRow` (dort ist Platz) - hier bleibt sie nur
                // als getoenter Aufklapp-Knopf, wenn die Zone geschlossen ist.
                if !rirExpanded {
                    rirCapsule
                }
                checkmarkButton
            }
            // Layout-Fix 2026-05-21 (Iteration 2): minHeight 44 auf der
            // Input-HStack. Verhindert dass die Row beim Tippen oder
            // Plate-Button-Toggle senkrecht ruckelt — die intrinsische
            // Hoehe der Children kann minimal schwanken (Font-Metrics
            // zwischen Placeholder + Zahl), 44pt deckt beide Faelle ab
            // und matched Apple's HIG-Minimum-Touch-Target-Size.
            .frame(minHeight: 44)

            // Signature-Geruest 2.16: der Regler belegt nur noch Platz,
            // wenn er per Tap auf `rirCapsule` aufgeklappt wurde.
            if rirExpanded, !isCompleted {
                rirSliderRow
                    .padding(.leading, 36)
                    .transition(.opacity)
            }

            // Signature-Geruest 2.16: der "letztes Mal"-Vergleich gilt nur
            // noch fuer den AKTIVEN Satz, in voller Laenge auf eigener
            // Zeile — vorher stand er bei JEDEM nicht abgeschlossenen Satz
            // inline hinter dem RIR-Regler und wurde dort abgeschnitten
            // (einziger Schutz war `.lineLimit(1)` + `.minimumScaleFactor`).
            if isActiveSet, let prev = previousLog {
                previousHintLine(prev)
                    .padding(.leading, 36)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            // Signature-Geruest 2.2: die aktive Zeile bekommt Radius 12
            // statt 10 (nur sie - abgeschlossene/kommende Zeilen bleiben
            // bei 10, das Handoff nennt explizit nur die aktive Zeile).
            RoundedRectangle(cornerRadius: isActiveSet ? 12 : 10)
                .fill(rowStateBackground)
        )
        .overlay(alignment: .leading) {
            // UX-203, angepasst: 2pt statt 3pt Brand-Akzent links bei der
            // aktiven Row. Wirkt wie ein "du-bist-hier"-Marker und ist im
            // Dark-Mode auch ohne Background-Tint sichtbar.
            if isActiveSet {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.deltiqOrange)
                    .frame(width: 2)
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
                    // Verifikation (Review): `rirExpanded` ueberlebt sonst
                    // einen Log→Unlog-Zyklus (die View-Identitaet bleibt
                    // ueber `structureToken` stabil) - ohne Reset klappt der
                    // Regler nach dem Un-Loggen ungefragt wieder auf, obwohl
                    // der User die Kapsel gar nicht erneut angetippt hat.
                    rirExpanded = false
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

    /// Signature-Geruest 2.17: Barbell-Detection nach demselben Fallback-
    /// Muster wie `ExerciseCard.isBarbellExercise` — DEL-159-Override
    /// gewinnt, sonst Library-Lookup ueber den System-Namen.
    private var isBarbellExercise: Bool {
        if let equipment = exercise.equipment {
            return equipment == .barbell
        }
        return ExerciseLibraryData.all.first { $0.name == exercise.name }?.equipment == .barbell
    }

    /// DEL-085: Quick-Access-Button fuer den Plate-Calculator. Sitzt als
    /// Badge auf der Gewichts-Eingabe (`weightInput`-Overlay), sichtbar wenn
    /// ein konkretes Gewicht > 0 eingetragen ist UND die Uebung mit einer
    /// Hantelstange ausgefuehrt wird (also keine Bodyweight-/Cardio-/
    /// TimeBased-Lifts). Tap oeffnet ein Popover mit der Aufladungs-
    /// Visualisierung — der eigentliche Content lebt in `PlatePopoverContent`
    /// weiter unten.
    ///
    /// Bugfix (Nutzer-Feedback): 28×28 → 22×22, da das Badge nur noch als
    /// kleiner Eck-Akzent auf `weightInput` sitzt, nicht mehr als eigenstaendiges
    /// Element in der Eingabezeile Platz beansprucht.
    @ViewBuilder
    private func plateCalculatorButton(weight: Double) -> some View {
        Button {
            showingPlatePopover = true
        } label: {
            Image(systemName: "scalemass.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange)
                .font(.caption)
                .frame(width: 22, height: 22)
                .background(Color.deltiqOrange.opacity(0.16))
                .clipShape(Circle())
                // Dezenter Rand, damit das Badge sich von der dahinterliegenden
                // `weightInput`-Fuellung absetzt, auch wenn es sie ueberlappt.
                .overlay(Circle().strokeBorder(Color.Deltiq.background, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        // Bugfix: war hartcodiert deutsch ("Hantel-Aufladung anzeigen"),
        // nie uebersetzt.
        .accessibilityLabel(Text("activeSet.plateCalculator.accessibilityLabel", bundle: .module))
        .popover(isPresented: $showingPlatePopover, arrowEdge: .top) {
            PlatePopoverContent(
                targetWeight: weight,
                barWeight: barWeightKgRaw,
                unitRaw: weightUnitRaw,
                exerciseName: exercise.name
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
            // Cap 2026-05-21: hartes 500-kg-Maximum auf der Gewichts-
            // Eingabe — verhindert utopische Werte (User-Vertipper,
            // versehentlich angetippter Zahlenpad) die dann sinnlos in
            // den Plate-Calculator + History fliessen.
            // `PlateCalculator.maxTargetKg = 500.0` ist die kanonische
            // Konstante; wenn die jemals erhoeht wird, propagiert der
            // Cap automatisch.
            .onChange(of: weight) { _, newValue in
                if let w = newValue, w > PlateCalculator.maxTargetKg {
                    weight = PlateCalculator.maxTargetKg
                }
            }
            // Bugfix (Nutzer-Feedback, Screenshots Ganzkoerper B): der
            // Aufladungs-Knopf sass vorher als eigenes HStack-Kind zwischen
            // "KG" und `repsInput` — bei Langhantel-Uebungen beanspruchte er
            // zusaetzliche ~34pt, die der `rirCapsule` fehlten (siehe dort)
            // UND liess die Zeile je nach Equipment unterschiedlich breit
            // wirken. Als Badge auf der Gewichts-Eingabe selbst braucht er
            // keinen eigenen Platz im linearen Layout mehr — Zeile ist jetzt
            // fuer jedes Equipment gleich aufgebaut.
            .overlay(alignment: .topTrailing) {
                if isBarbellExercise {
                    let plateShown = (weight ?? 0) > 0 && !exercise.isTimeBased
                    plateCalculatorButton(weight: weight ?? 0)
                        .offset(x: 6, y: -6)
                        .opacity(plateShown ? 1 : 0)
                        .allowsHitTesting(plateShown)
                }
            }
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
                    // README 2.25 (Review-Befund): ohne Reset bleibt der
                    // Regler aufgeklappt, wenn der User bei offener RIR-Zone
                    // direkt das Haekchen tippt statt vorher die Kapsel
                    // erneut anzutippen - `rirCapsule` wuerde dann NIRGENDS
                    // mehr gerendert (weder in der Eingabezeile, `!rirExpanded`
                    // greift nicht mehr, noch in `rirSliderRow`, `!isCompleted`
                    // greift nicht mehr), der RIR-Wert verschwindet komplett
                    // aus der Zeile bis zum naechsten Un-/Relog. Gleiches
                    // Reset-Muster wie beim Unlog-Pfad unten (`onTapGesture`).
                    rirExpanded = false
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
    /// Signature-Geruest 1.7: Orange bedeutet jetzt ausschliesslich "aktiv",
    /// nicht mehr "fertig" — ein abgehaktes Working-Set bekommt daher Gruen
    /// statt der Brand-Farbe. Warmup/Cooldown bleiben auf Grau, unveraendert.
    private var checkmarkColor: Color {
        if isCompleted {
            return exercise.role.skipsProgression
                ? Color.secondary
                : Color.Deltiq.success
        }
        return Color.secondary.opacity(0.5)
    }

    /// Signature-Geruest 2.16: Kapsel statt permanentem Regler — zeigt den
    /// aktuellen RIR-Wert, Tap klappt `rirSliderRow` auf/zu. Gesperrt bei
    /// abgeschlossenen Saetzen (zeigt dann nur noch den geloggten Wert),
    /// gleiches Sperr-Muster wie `weightInput`/`repsInput`.
    /// README 2.24: gefuellt statt nur getoent, solange die Zone offen ist.
    /// README 2.25 (Nutzer-Feedback): `.fixedSize()` + `.lineLimit(1)` -
    /// dieselbe Absicherung, die "KG"/"WDH" seit dem Layout-Fix vom 21. Mai
    /// tragen. Ohne sie war die Kapsel das einzige flexible Kind der
    /// Eingabezeile-HStack und wurde auf ~2pt zusammengedrueckt - der Wert
    /// brach darin Zeichen fuer Zeichen um (unlesbar) UND bestimmte die
    /// Zeilenhoehe ueber seine Zeichenzahl ("RIR 1" vs "RIR 3,5" - jeder
    /// Halbschritt aenderte die Hoehe). Wird bei aufgeklapptem Satz nicht
    /// mehr in der Eingabezeile gebraucht (siehe Aufrufstelle dort) - lebt
    /// dann in `rirSliderRow`, wo Platz ist.
    ///
    /// Bugfix (Nutzer-Feedback, Screenshots Ganzkoerper B): "RIR 2,5" war bei
    /// Hantelübungen (zusaetzliches Plate-Icon in der Zeile, siehe dort)
    /// selbst mit `.minimumScaleFactor(0.85)` nicht mehr unterzubringen - bei
    /// echtem Overflow hat SwiftUI der Kapsel praktisch keine Breite mehr
    /// gelassen, der Text wurde auf ein einzelnes "R" zusammengequetscht.
    /// Der Aufladungs-Knopf ist jetzt kein eigenes HStack-Kind mehr (siehe
    /// `weightInput`), trotzdem bleibt die Kapsel kompakt ("R3"/"R2,5" statt
    /// "RIR 3"/"RIR 2,5") als zusaetzlicher Puffer - sie ist bei jedem
    /// Halbschritt-Wert die einzige Komponente mit variabler Breite. Der
    /// sichtbare Text ist bewusst kuerzer als der gesprochene: VoiceOver
    /// hoert weiterhin die volle Form ueber `.accessibilityLabel`.
    private var rirCapsule: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { rirExpanded.toggle() }
        } label: {
            Text("R\(rir.formattedRIR)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(rirExpanded ? .white : Color.deltiqOrange)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                // Mindestbreite statt reiner Inhaltsbreite - verhindert, dass
                // die Kapsel bei einstelligen Werten ("R0") optisch zum
                // Kreis statt einer Pille wird.
                .frame(minWidth: 32)
                .background(rirExpanded ? Color.deltiqOrange : Color.deltiqOrange.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .opacity(isCompleted ? 0.6 : 1.0)
        .accessibilityLabel(
            Text(String(format: String(localized: "activeSet.rirCapsule.accessibilityLabel", bundle: .module), rir.formattedRIR))
        )
        .accessibilityHint(Text("activeSet.rirCapsule.accessibilityHint", bundle: .module))
    }

    /// UX-203: HStack-Spacing 10 → 14, plus dedizierte Slider-min-Höhe via
    /// .frame(height: 24), damit der Touch-Bereich nicht mehr aus einem zu
    /// engen Container gedrückt wird.
    ///
    /// README 2.24 (Nutzer-Feedback, zwei Simulator-Screenshots): der
    /// Erklaerungstext war ein `.overlay` mit fester `.offset(y: -38)`
    /// UEBER dem Regler - bei laengeren Texten (1-3 Zeilen je Halbschritt,
    /// neun Katalog-Eintraege `rir.tooltip.0`...`.4plus`) legte er sich
    /// damit auf `weightInput`/`repsInput`, also genau die Felder, in die
    /// man gerade tippt. Jetzt eine normale Zeile UNTER dem Regler mit
    /// reservierter Mindesthoehe statt eines Timer-gesteuerten Overlays -
    /// `RIRTooltipController`/`RIRTooltipBloop.isVisible`/`showRirTooltips`
    /// werden hier nicht mehr gebraucht. Bleiben unveraendert im Einsatz
    /// fuer `ExerciseEditorView.targetRIRSliderRow` (eigene Instanz dort) -
    /// der Regler steht dort allein in einer Section und verdeckt nichts,
    /// eine bewusst eigene Entscheidung.
    ///
    /// Dazu eine sichtbare Skala, weil der Regler vorher nicht sagte, was
    /// er misst (Label "RIR" ohne Erklaerung, keine Enden-Beschriftung,
    /// Wert doppelt). Die 11 Rasterstriche sind rein dekorativ (`.background`
    /// HINTER dem Slider, `allowsHitTesting(false)` + `accessibilityHidden`)
    /// - Drag-Gesture, Werte-Fuellung und VoiceOver-Adjustable-Action bleiben
    /// beim nativen `Slider`, absichtlich NICHT durch einen selbstgebauten
    /// Regler ersetzt (Touch-Handling + Accessibility eines Custom-Reglers
    /// liessen sich hier nicht verifizieren).
    private var rirSliderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // README 2.25: die Kapsel selbst statt eines bloßen "RIR"-Labels
            // - sie zieht bei aufgeklapptem Satz hier ein (siehe `rirCapsule`-
            // Doc), weil die Eingabezeile ihr keinen Platz mit Breite geben
            // kann. `.center` statt `.firstTextBaseline`, weil die Kapsel
            // (Button+Capsule, kein reiner Text) keine sinnvolle
            // Baseline neben einem Fliesstext hat.
            HStack(alignment: .center, spacing: 8) {
                rirCapsule
                Text("active.set.rir.subtitle", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
            .background(alignment: .center) {
                HStack(spacing: 0) {
                    ForEach(0..<11) { index in
                        Rectangle()
                            .fill(Color.secondary.opacity(index.isMultiple(of: 2) ? 0.35 : 0.2))
                            .frame(width: 1, height: index.isMultiple(of: 2) ? 8 : 5)
                        if index < 10 { Spacer(minLength: 0) }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            HStack {
                Text("active.set.rir.scaleMin", bundle: .module)
                Spacer()
                Text("active.set.rir.scaleMax", bundle: .module)
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            Text(LocalizedStringKey(RIRTooltipBloop.tooltipKey(for: rir)), bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32, alignment: .topLeading)
        }
    }

    /// Signature-Geruest 2.16: eigene, volle Zeile statt Inline-Anhaengsel
    /// hinter dem RIR-Regler — vorher wurde der Hinweis auf schmalen
    /// Bildschirmen (`.lineLimit(1)` + `.minimumScaleFactor(0.8)`)
    /// abgeschnitten bzw. verkleinert. Nur der aktive Satz zeigt sie
    /// (siehe Aufrufstelle), daher kein zusaetzliches Gate hier noetig.
    private func previousHintLine(_ log: ExerciseLog) -> some View {
        // Bug-Fix 2026-05-22: "letztes:" war hardcoded DE. Jetzt via
        // `active.set.previousFormat`-Catalog-Key mit %@-Placeholder →
        // DE/EN/TR sauber.
        Text(String(format:
            String(localized: "active.set.previousFormat", bundle: .module),
            previousLogHint(log)))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        // DEL-149: `exercise.displayName` statt rohem `exercise.name`. Der
        // gespeicherte DE-Base wird hier in den User-sichtbaren Hint-String
        // weitergereicht — wir lokalisieren am Source, sodass der gesamte
        // blocking-Pfad (auch cross-row) sprachfest bleibt.
        ActiveTimedSetID(
            exerciseID: exercise.persistentModelID,
            setIndex: setIndex,
            exerciseName: exercise.displayName
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

    /// Kompakte Zusammenfassung des letzten Satzes dieser Uebung + Satz-Nummer.
    ///
    /// DEL-220: drei Baustellen behoben.
    ///   * **Cardio zeigte Unsinn.** Der Cardio-Zweig der Row rendert diesen
    ///     Hint (siehe `editableTrailing`), die Funktion kannte aber nur
    ///     TimeBased und Strength — ein Lauf-Log landete im Gewicht/Reps-Pfad
    ///     und erschien als "letztes: 0 kg × 0", weil Cardio-Logs weight und
    ///     reps auf 0 haben. Jetzt Distanz + Dauer aus `distanceKm`/
    ///     `durationSeconds`.
    ///   * **RIR fehlte.** Der wichtigste Teil der Progressions-Entscheidung
    ///     ("8 Wdh bei RIR 0" vs. "8 Wdh bei RIR 3") war nicht sichtbar,
    ///     obwohl er geloggt wird. Nur angehaengt, wenn die Uebung ueberhaupt
    ///     RIR fuehrt (nicht bei Cardio).
    ///   * **" kg" war hartkodiert** → `unit.kg.lower`.
    ///
    /// Bewusst NICHT geaendert: die Einheit bleibt kg. Die Werte sind
    /// projektweit in kg persistiert und das Eingabefeld daneben ist mit "KG"
    /// beschriftet — hier "lbs" anzuzeigen wuerde einen kg-Wert falsch
    /// etikettieren. Eine echte lbs-Unterstuetzung ist ein eigenes,
    /// querschnittliches Thema (Eingabe, Volumen, PRs, Charts, CSV).
    private func previousLogHint(_ log: ExerciseLog) -> String {
        // DEL-128: Sek-Unit aus xcstrings.
        if exercise.isTimeBased {
            let secUnit = String(localized: "unit.seconds.short", bundle: .module)
            return "\(log.reps) \(secUnit)"
        }

        if exercise.isCardio {
            let kmUnit = String(localized: "unit.km.lower", bundle: .module)
            let distance = log.distanceKm ?? 0
            let seconds = log.durationSeconds ?? 0
            // Nur eine der beiden Groessen geloggt → die andere weglassen,
            // statt "0 km" bzw. "in 00:00" zu behaupten.
            switch (distance > 0, seconds > 0) {
            case (true, true):
                return String(
                    format: String(localized: "active.set.previousCardio", bundle: .module),
                    "\(formatWeight(distance)) \(kmUnit)",
                    PaceCalculator.formatDuration(seconds)
                )
            case (true, false):
                return "\(formatWeight(distance)) \(kmUnit)"
            case (false, true):
                return PaceCalculator.formatDuration(seconds)
            case (false, false):
                return "—"
            }
        }

        let kgUnit = String(localized: "unit.kg.lower", bundle: .module)
        let base = "\(formatWeight(log.weight, decimals: 1)) \(kgUnit) × \(log.reps)"
        let rirPart = String(
            format: String(localized: "active.set.previousRIR", bundle: .module),
            log.rir.formattedRIR
        )
        return "\(base) · \(rirPart)"
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
            // DEL-239: Das GEPLANTE Gewicht gewinnt, wenn es NIEDRIGER ist als
            // das letzte geloggte.
            //
            // Vorher stand hier `previousLog.weight > 0 ? previousLog.weight :
            // exercise.suggestedWeight` — der letzte geloggte Wert gewann immer,
            // `suggestedWeight` war nur Fallback fuer Bodyweight-Saetze. Damit
            // war jede geplante Reduktion im Training UNSICHTBAR: das Feld
            // zeigte die alte Last, waehrend die Warmup-Rampe (ExerciseCard)
            // schon mit dem reduzierten Wert rechnete — reduzierte Aufwaerm-
            // stufen ueber un-reduziertem Arbeitsgewicht, auf einem Screen. Die
            // Saetze landeten mit der alten Last im Log, also sah auch die
            // Historie keine Reduktion.
            //
            // Bewusst NUR nach unten: `suggestedWeight` liegt im Normalfall
            // durch die Progression HOEHER als der letzte Log, und dort soll
            // weiterhin der zuletzt tatsaechlich gehobene Wert vorstehen (der
            // Nutzer entscheidet selbst, ob er heute zulegt). Ein niedrigerer
            // Plan-Wert ist dagegen immer eine Absicht — Absenz-Deload,
            // Overreaching-Deload oder eine manuelle Korrektur nach unten.
            let planned = exercise.suggestedWeight
            if previousLog.weight > 0 {
                weight = (planned.map { $0 < previousLog.weight } ?? false)
                    ? planned
                    : previousLog.weight
            } else {
                weight = planned
            }
            reps = previousLog.reps
            rir = previousLog.rir
            // DEL-058 Cardio init aus previousLog — Felder bleiben leer, der
            // Placeholder zeigt die letzten Werte als Hint. Kein Pre-Fill
            // wuerde den User zwingen, das Feld zu loeschen, BEVOR er heute
            // tippt — bei Lauf-Logs nicht erwuenscht.
        } else if let seedLog {
            // DEL-157: dynamisch hinzugefuegter Satz ohne eigene Historie —
            // erbt Gewicht/Reps/RIR vom Satz direkt darueber in DIESER
            // Session, sodass der User nicht von 0 anfangen muss.
            weight = seedLog.weight > 0 ? seedLog.weight : exercise.suggestedWeight
            reps = seedLog.reps
            rir = seedLog.rir
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

    private func formatWeight(_ w: Double, decimals: Int = 2) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: decimals).formatted(decimals: decimals)
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
            // Signature-Geruest 2.2: gleiche Radius-Anpassung wie
            // compactSetRow - beide Zeilentypen teilen dieses Snippet.
            RoundedRectangle(cornerRadius: isActiveSet ? 12 : 10)
                .fill(rowStateBackground)
        )
        .overlay(alignment: .leading) {
            if isActiveSet {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.deltiqOrange)
                    .frame(width: 2)
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
            // Bug-Fix 2026-05-22: lokalisiert via active.set.previousFormat.
            Text(String(format:
                String(localized: "active.set.previousFormat", bundle: .module),
                cardioPreviousHint(prev)))
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
    /// Bevorzugtes Standard-Langhantel-Gewicht (`pref_bar_weight_kg`).
    let barWeight: Double
    let unitRaw: String
    let exerciseName: String

    /// Signature-Geruest 2.17 Nachtrag: SZ-Stange (~10 kg) und Trap-Bar
    /// (~25 kg) sind ebenfalls `.barbell`, teilen sich bisher aber die eine
    /// Standard-Einstellung — die Aufladung rechnet fuer sie mit der
    /// falschen Stange.
    private enum BarType: String, Hashable {
        case standard, ezBar, trapBar
    }

    @State private var barType: BarType

    /// README 2.17 (28c): Skull Crusher ist immer SZ, Trap-Bar-Kreuzheben
    /// immer Trap - bei jedem Oeffnen auf Standard zurueckzufallen zeigt
    /// dort jedes Mal zuerst die falsche Zahl. Gemerkt wird Name -> Stange,
    /// dasselbe Muster wie der Bibliotheks-Rueckfall fuer `equipment` -
    /// kein Feld am Datenmodell, keine Migration.
    private static let barTypeByExerciseKey = "pref_bar_type_by_exercise"

    private static func rememberedBarType(for exerciseName: String) -> BarType {
        let stored = UserDefaults.standard.dictionary(forKey: barTypeByExerciseKey) as? [String: String]
        guard let raw = stored?[exerciseName], let matched = BarType(rawValue: raw) else { return .standard }
        return matched
    }

    private static func rememberBarType(_ type: BarType, for exerciseName: String) {
        var stored = (UserDefaults.standard.dictionary(forKey: barTypeByExerciseKey) as? [String: String]) ?? [:]
        stored[exerciseName] = type.rawValue
        UserDefaults.standard.set(stored, forKey: barTypeByExerciseKey)
    }

    init(targetWeight: Double, barWeight: Double, unitRaw: String, exerciseName: String) {
        self.targetWeight = targetWeight
        self.barWeight = barWeight
        self.unitRaw = unitRaw
        self.exerciseName = exerciseName
        _barType = State(initialValue: Self.rememberedBarType(for: exerciseName))
    }

    private var unit: PlateCalculator.Unit {
        PlateCalculator.Unit(rawValue: unitRaw) ?? .kg
    }

    private var effectiveBarWeight: Double {
        switch barType {
        case .standard: return barWeight
        case .ezBar: return 10
        case .trapBar: return 25
        }
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

            // Signature-Geruest: DeltiqSegmentedPicker statt System-Picker,
            // gleiches Muster wie die Einheiten-Auswahl in PlateCalculatorView.
            DeltiqSegmentedPicker(
                options: [
                    DeltiqSegmentedOption(
                        BarType.standard,
                        label: String(localized: "barbell.loading.type.standard", bundle: .module)
                    ),
                    DeltiqSegmentedOption(
                        BarType.ezBar,
                        label: String(localized: "barbell.loading.type.ezBar", bundle: .module)
                    ),
                    DeltiqSegmentedOption(
                        BarType.trapBar,
                        label: String(localized: "barbell.loading.type.trapBar", bundle: .module)
                    )
                ],
                selection: $barType
            )
            .onChange(of: barType) { _, newValue in
                Self.rememberBarType(newValue, for: exerciseName)
            }

            Text("Stange: \(formatWeight(effectiveBarWeight)) \(unit.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // DEL-085 / DEL-092-Fix: PlateCalculator.calculate liefert ein
            // flaches `[PlateConfig]`, KEIN Wrapper-Struct mit `.plates` /
            // `.actualWeight`. `actualWeight` rechnen wir manuell (Stange +
            // 2× pro-Seite-Summe) — selbe Formel wie in PlateCalculatorView.
            let plates = PlateCalculator.calculate(target: targetWeight, bar: effectiveBarWeight, unit: unit)
            let perSideLoaded = plates.reduce(0.0) { $0 + Double($1.count) * $1.weight }
            let actualWeight = effectiveBarWeight + 2 * perSideLoaded

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
