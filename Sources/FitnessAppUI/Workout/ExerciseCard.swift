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
    /// P8 Stufe-2 (Session-Inhaltsvertrag, Wiederaufnahme-Isolation): der
    /// zum Session-Start (bzw. durch In-Session-Edits) eingefrorene Stand
    /// dieser Übung — Quelle für Name/Rolle/Cardio-Zeitbasiert-Klassifikation/
    /// Satzvorgaben (Sets/Reps/Pause/RIR/Distanz/Dauer). `exercise` bleibt
    /// für Logging-Identität und Felder außerhalb des Snapshot-Vertrags
    /// (Equipment/Barbell-Erkennung, `suggestedWeight`, GIF-Lookup)
    /// maßgeblich. Siehe `ActiveWorkoutView.resolvedExercises`/
    /// `SessionContentResolver` für die Auflösung.
    let content: TrainingDayContentSnapshot.ExerciseEntry
    let session: WorkoutSession
    /// Task 8 (laufcoaching-remediation-round-2, Decision 1): durchgereicht
    /// von `ActiveWorkoutView`s live `@Query private var profiles` bis zu
    /// jeder `SetRow` - siehe dortige Doku-Kommentare fuer die "live, nicht
    /// eingefroren"-Begruendung. Beide Felder sind reine Pass-through-Werte,
    /// kein eigener State/Cache hier.
    let cardioCoachingEnabled: Bool
    let current5kReferenceSeconds: Int?
    /// Fix I-2 (Final-Review, Round 2): `true` nur, wenn der Tag dieser
    /// Session zu einem `generationSource == .cardioCoach`-Plan gehoert -
    /// siehe `SetRow.targetPaceHint` fuer die konkrete Gating-Verwendung.
    let isCoachGeneratedPlan: Bool
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
    /// Runde 10 (Settings → Training): identischer Key/Default wie
    /// `SetRow.setDisplayModeRaw` — der gemeinsame Spaltenkopf ergibt nur im
    /// "column"-Modus Sinn, "classic" beschriftet jedes Feld stattdessen
    /// direkt in der Satzzeile selbst (siehe `SetRow.labeledField`).
    @AppStorage("pref_set_display_mode") private var setDisplayModeRaw: String = "column"
    @State private var rampExpanded = false

    /// Bugfix "Workout-GIF-Overlay": frueher war hier ein animiertes
    /// `ExerciseGifView` fix im Header eingebettet — je nach GIF-
    /// Seitenverhaeltnis hat dessen `UIImageView`-Bruecke die vorgegebene
    /// 44x44-Frame durchbrochen und das GIF ueber Name/Satzzeilen gelegt
    /// (Root-Cause-Fix: `GifImageView.sizeThatFits`). Im aktiven Workout
    /// zeigt die Karte jetzt gar kein GIF mehr inline, nur noch einen
    /// kleinen Play-Button (`gifButton`), der `ExerciseGifSheet` oeffnet.
    @State private var showingGifSheet = false

    /// Korrektur post-Review (Dynamic Type): identische Deklaration (gleiche
    /// Basis, gleiches `relativeTo`) wie `SetRow.checkmarkIconSize` — beide
    /// werden von SwiftUI im selben Environment (gleiche Dynamic-Type-Stufe)
    /// ausgewertet und liefern dadurch GARANTIERT denselben skalierten Wert,
    /// statt einer statischen Zahl, die bei groesseren Schriftstufen vom
    /// tatsaechlichen Checkmark-Icon abweichen wuerde. `SetRowColumns` kann
    /// das nicht selbst halten, da `@ScaledMetric` Live-Environment-Zugriff
    /// braucht (ein `enum` mit `static let` hat keinen).
    @ScaledMetric(relativeTo: .title2) private var checkmarkColumnPlaceholderWidth: CGFloat = 28

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
            // Korrektur post-Review (RIR strukturell statt komprimiert):
            // Spalten-Beschriftung einmal pro Uebung statt "KG"/"WDH" in
            // jeder einzelnen SetRow. Nur fuer Strength/Bodyweight sinnvoll
            // (Cardio/TimeBased haben ein eigenes Zeilenlayout ohne diese
            // Spalten).
            if !content.isCardio && !content.isTimeBased && setDisplayModeRaw != "classic" {
                setRowColumnHeader
            }
            ForEach(0..<content.sets, id: \.self) { setIndex in
                SetRow(
                    setIndex: setIndex,
                    exercise: exercise,
                    content: content,
                    session: session,
                    existingLog: existingLog(forSetIndex: setIndex),
                    previousLog: previousLog(forSetIndex: setIndex),
                    cardioCoachingEnabled: cardioCoachingEnabled,
                    current5kReferenceSeconds: current5kReferenceSeconds,
                    isCoachGeneratedPlan: isCoachGeneratedPlan,
                    seedLog: seedLog(forSetIndex: setIndex),
                    onRequestDelete: content.sets > 1 ? { removeSet(at: setIndex) } : nil,
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
                if setIndex < content.sets - 1 {
                    // Signature-Geruest 1.6: Trennlinie einheitlich 6% statt
                    // der bisherigen 20% - die Active-Set-Background-Tint
                    // uebernimmt weiterhin die primaere visuelle Trennung.
                    Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                }
            }

            if completedSetCount >= content.sets {
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

    // MARK: Set-Spalten-Header

    /// Korrektur post-Review (RIR strukturell statt komprimiert): einmalige
    /// Spaltenbeschriftung oberhalb der Satzzeilen. Nutzt dieselben
    /// `SetRow.SetRowColumns`-Breiten wie `SetRow.singleLineInputRow`, damit
    /// Header und Satzzeilen spaltengenau ausgerichtet sind.
    ///
    /// Korrektur post-Review (Nachbesserung): eigener `ViewThatFits` statt
    /// starrem Ein-Zeilen-Layout — faellt `SetRow.compactSetRow` bei
    /// schmalem Display/grosser Dynamic-Type-Stufe auf sein zweizeiliges
    /// `twoLineInputRow` zurueck, zeigt dieser Header analog
    /// `reducedSetRowColumnHeader` (nur noch Satz/kg/Wdh, exakt was auf
    /// Zeile 1 des Fallbacks steht). "RIR" wird in diesem reduzierten
    /// Zustand bewusst NICHT hier oben beschriftet (stuende ueber der
    /// leeren ersten Zeile, waehrend die Kapsel auf Zeile 2 gewandert ist)
    /// — stattdessen traegt `twoLineInputRow`s zweite Zeile dort ein
    /// eigenes Inline-"RIR"-Label direkt neben der Kapsel. Beide Varianten
    /// nutzen exakt dieselben Spaltenbreiten/Abstaende wie die jeweilige
    /// Satzzeilen-Variante, wodurch `ViewThatFits` bei GLEICHER verfuegbarer
    /// Breite auch zur GLEICHEN Entscheidung kommt wie die Satzzeile selbst
    /// — zwei unabhaengige `ViewThatFits`-Aufrufe, aber mit identischen
    /// Eingabegroessen statt zweier nur zufaellig uebereinstimmender Werte.
    private var setRowColumnHeader: some View {
        ViewThatFits(in: .horizontal) {
            fullSetRowColumnHeader
            reducedSetRowColumnHeader
        }
    }

    /// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs):
    /// der Spaltenkopf stand hart auf "KG", obwohl `SetRow.weightInput`
    /// darunter seit dieser Runde die gewaehlte Einheit respektiert.
    private var weightColumnHeaderKey: LocalizedStringKey {
        weightUnitRaw == "lbs" ? "unit.lbs.upper" : "unit.kg.upper"
    }

    private var fullSetRowColumnHeader: some View {
        HStack(spacing: SetRow.SetRowColumns.spacing) {
            Text("set.column.setLabel", bundle: .module)
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.setNumberWidth, alignment: .leading)
            Color.clear.frame(width: SetRow.SetRowColumns.weightGroupLeadingInset, height: 1)
            Text(weightColumnHeaderKey, bundle: .module)
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.weightWidth, alignment: .center)
            Text(String(localized: "unit.reps.short", bundle: .module).uppercased())
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.repsWidth, alignment: .center)
            Color.clear.frame(width: SetRow.SetRowColumns.plateWidth, height: 1)
            Spacer(minLength: 6)
            // Korrektur post-Review (Dynamic Type): `RIRValueTextStyle`
            // statt eigenem Font/Padding/Frame — exakt dieselbe Breiten-
            // vorgabe wie `rirCapsule` selbst nutzt, damit beide bei JEDER
            // Dynamic-Type-Stufe exakt gleich breit bleiben (geteilter Code
            // statt zweier Zahlen, die haetten auseinanderlaufen koennen).
            Text("set.column.rirLabel", bundle: .module)
                .modifier(SetRow.RIRValueTextStyle())
                .foregroundStyle(.secondary)
            Color.clear.frame(width: checkmarkColumnPlaceholderWidth, height: 1)
        }
        .padding(.horizontal, 8)
        // Jedes Eingabefeld traegt sein eigenes Accessibility-Label bereits
        // (siehe SetRow); der Header ist eine rein visuelle Spaltenangabe,
        // wird VoiceOver-Nutzern aber als EIN zusammengefasstes Element
        // einmalig vorgelesen statt als vier separate Stopps.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("set.column.header.accessibilityLabel", bundle: .module))
    }

    /// Reduzierte Variante fuer `SetRow.twoLineInputRow` — exakt dieselben
    /// Spalten wie dessen erste Zeile (Satz/kg/Wdh, kein Plate-/RIR-/
    /// Checkmark-Platzhalter mehr), damit `ViewThatFits` hier bei der
    /// gleichen Breite kippt wie die Satzzeile selbst.
    private var reducedSetRowColumnHeader: some View {
        HStack(spacing: SetRow.SetRowColumns.spacing) {
            Text("set.column.setLabel", bundle: .module)
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.setNumberWidth, alignment: .leading)
            Color.clear.frame(width: SetRow.SetRowColumns.weightGroupLeadingInset, height: 1)
            Text(weightColumnHeaderKey, bundle: .module)
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.weightWidth, alignment: .center)
            Text(String(localized: "unit.reps.short", bundle: .module).uppercased())
                .deltiqLabel()
                .frame(width: SetRow.SetRowColumns.repsWidth, alignment: .center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("set.column.header.reducedAccessibilityLabel", bundle: .module))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // DEL-124: Active-Workout Card-Header via displayName.
                    // P8 Stufe-2: eingefrorener Name — ein externes Umbenennen
                    // waehrend die Session laeuft darf den Kartentitel nicht aendern.
                    Text(displayName)
                        .font(.headline)
                    // DEL-087: Pill markiert Warmup/Cooldown-Uebungen optisch.
                    if let pillText = content.role.localizedPillText {
                        Text(pillText)
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
            gifButton
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
        // Bugfix "Workout-GIF-Overlay": Sheet lebt am Header, nicht an der
        // ganzen Karte — `exercise` ist ein stabiles `let` pro Card-Instanz,
        // das Sheet zeigt also auch bei schnellem Seitenwechsel nie das GIF
        // einer anderen Uebung (jede Praesentation erzeugt zudem ein frisches
        // `ExerciseGifSheet`/`GifImageView`, kein geteilter Zustand zwischen
        // Oeffnen-Vorgaengen). Sets/Timer/aktuelle Seite bleiben unberuehrt,
        // weil `ExerciseCard` waehrenddessen einfach weiter gemountet bleibt.
        .sheet(isPresented: $showingGifSheet) {
            ExerciseGifSheet(exerciseName: exercise.name, displayName: exercise.displayName)
        }
    }

    /// Kleiner Play-Button statt des frueheren Inline-GIFs (siehe
    /// `showingGifSheet`-Kommentar). Nur sichtbar, wenn `ExerciseMediaProvider`
    /// ueberhaupt ein GIF fuer diese Uebung kennt — kein leerer Button, kein
    /// Platzhalter-Icon fuer eine nicht vorhandene Ressource.
    @ViewBuilder
    private var gifButton: some View {
        if hasGif {
            Button {
                showingGifSheet = true
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(gifButtonAccessibilityText))
        }
    }

    private var hasGif: Bool {
        ExerciseMediaProvider.gifFileName(forExerciseName: exercise.name) != nil
    }

    private var gifButtonAccessibilityText: String {
        let format = String(localized: "exercise.gif.button.a11y", bundle: .module)
        return String(format: format, exercise.displayName)
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
    /// P8 Stufe-2: eingefrorener Anzeigename — custom-first wie
    /// `Exercise.displayName`, aber aus `content` statt der Live-Übung
    /// gespeist (siehe `TimedFormatDisplayExercise` in `WorkoutSummaryView`
    /// für dasselbe Muster in der Historie).
    private var displayName: String {
        if let custom = content.customNameSnapshot, !custom.isEmpty { return custom }
        return Exercise.resolvedDisplayName(forStoredName: content.nameSnapshot)
    }

    private var targetText: String {
        let pauseLabel = String(localized: "exercise.rest.label", bundle: .module)
        // Signature-Geruest 2.16: mm:ss statt reiner Sekundenzahl ("150s" ->
        // "2:30") - gleicher Formatter, den der Rest der App fuer Dauern
        // schon nutzt (siehe TimedWorkoutPlayerView/WorkoutSummaryView etc.).
        // `restSeconds == 0` ist ein bewusst gueltiger Wert (Drop-Sets,
        // Supersets, Rest-Pause, siehe Kommentar bei ActiveWorkoutView's
        // Timer-Start) - `PaceCalculator.formatDuration(0)` liefert dafuer
        // "—" (gedacht fuer "keine Dauer vorhanden"), was hier faelschlich
        // nach fehlendem statt nach bewusst leerem Wert aussehen wuerde.
        // P8 Stufe-2: Satzvorgaben kommen aus `content` (eingefroren), nicht
        // aus der Live-Übung — eine externe Änderung während die Session
        // offen ist darf diese Anzeige nicht beeinflussen.
        let restText = content.restSeconds > 0
            ? PaceCalculator.formatDuration(content.restSeconds)
            : "0:00"
        if content.isCardio {
            let cardioLabel = String(localized: "exercise.kind.cardio", bundle: .module)
            let fmt = String(localized: "exercise.target.cardioFormat", bundle: .module)
            return String(format: fmt, cardioLabel, restText, pauseLabel)
        }
        let unit = content.isTimeBased
            ? String(localized: "unit.seconds.short", bundle: .module)
            : String(localized: "unit.reps.short", bundle: .module)
        let range = content.repsMin == content.repsMax
            ? "\(content.repsMin)"
            : "\(content.repsMin)-\(content.repsMax)"
        let fmt = String(localized: "exercise.target.strengthFormat", bundle: .module)
        return String(format: fmt, content.sets, range, unit, restText, pauseLabel)
    }

    private var progressPill: some View {
        Text("\(completedSetCount) / \(content.sets)")
            .font(.caption.weight(.bold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(progressFillColor)
            .foregroundStyle(completedSetCount >= content.sets ? .green : .primary)
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
        completedSetCount >= content.sets
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
        for i in 0..<content.sets where !completed.contains(i) {
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
            let workingLbs = WeightUnit.lbs.fromKg(workingKg)
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
    /// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs-
    /// Nachtest): fehlender `context.save()` nach dem Insert hier selbst -
    /// derselbe Musterfehler wie bereits zwoelf Mal zuvor in dieser App
    /// gefunden und gefixt (zuletzt `CardioGoalEditorView.save()`), diesmal
    /// im eigentlichen Satz-Logging. Auf dem Geraet reproduziert: ein gerade
    /// geloggter Satz (gruener Haken, Volumen-Anzeige aktualisiert) ging bei
    /// einem Kaltstart kurz danach verloren - unabhaengig von kg/lbs, betraf
    /// auch das bereits bestehende Kaltstart-sichere `unlogSet` direkt
    /// darunter als Gegenbeispiel (siehe dessen Doku-Kommentar).
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
        try? modelContext.save()
        onSetLogged(setIndex)
    }

    /// DEL-045: Tap-on-completed-row revert. Loescht den `ExerciseLog` fuer
    /// diesen Set-Index, sodass die Row wieder in den editable State zurueck-
    /// faellt (TextFields aktiv, Checkmark hollow). Kein Notify nach oben —
    /// der Rest-Timer wird *nicht* zurueckgesetzt, weil der User vermutlich
    /// nur einen Tippfehler korrigieren will, nicht die ganze Pause-Logik
    /// neu starten.
    /// TestingBot-Regressionscheck (Block A, Deltiq-Abnahme, siehe
    /// `PlansListView.deletePlans`-Doku): ohne sofortigen `context.save()`
    /// verlaesst sich die Loeschung auf SwiftDatas impliziten Autosave — ein
    /// kurz danach folgender Kaltstart konnte den Satz wieder als
    /// abgeschlossen anzeigen. `removeSet` (unten) ist sicher, weil darauf
    /// stets `TrainingDayContentSnapshotWriter.recordSetCountChange` folgt,
    /// der selbst speichert — `unlogSet` hat keinen solchen Folgeaufruf.
    private func unlogSet(setIndex: Int) {
        guard let log = existingLog(forSetIndex: setIndex) else { return }
        modelContext.delete(log)
        try? modelContext.save()
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
        // P8 Stufe-2: "+ Satz" ist eine ausdrückliche Aktion DIESER laufenden
        // Session (gilt für jede Session, nicht nur Ad-hoc) — hält den
        // eigenen Inhaltsstand synchron, statt beim nächsten Resolve auf den
        // alten, eingefrorenen `sets`-Wert zurückzufallen.
        TrainingDayContentSnapshotWriter.recordSetCountChange(for: exercise, in: session, context: modelContext)
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
            TrainingDayContentSnapshotWriter.recordSetCountChange(for: exercise, in: session, context: modelContext)
            structureToken = UUID()
        }
    }
}
#endif
