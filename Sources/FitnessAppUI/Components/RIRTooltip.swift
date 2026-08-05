#if canImport(SwiftUI)
import SwiftUI

/// DEL-143: Erklärungs-"Bloop" für RIR-Slider.
///
/// Erscheint beim Drag-Start (`isVisible == true`), zeigt einen kurzen,
/// dynamisch zum aktuellen RIR-Wert passenden Erklärungstext, und
/// verschwindet 1.8 s nach Drag-Ende. Caller (SetRow, ExerciseEditor)
/// wraps seinen Slider in `.overlay(alignment: .top) { RIRTooltipBloop(rir:isVisible:) }`
/// und steuert das `isVisible`-Binding via `onEditingChanged`-Callback
/// des Sliders.
///
/// **Positionierung-Hinweis:** der Caller ist verantwortlich für die
/// Verschiebung über den Slider-Thumb (z.B. via `.offset(y: -40)`),
/// damit das Bloop NICHT vom Finger verdeckt wird. Hier rendern wir
/// nur das Capsule-Pill — Layout-Kontext bestimmt der Caller, weil
/// der Slider auch innerhalb einer HStack mit Labels links/rechts
/// sitzen kann (siehe SetRow.statusZone).
@available(iOS 17.0, macOS 14.0, *)
public struct RIRTooltipBloop: View {

    public let rir: Float
    public let isVisible: Bool

    public init(rir: Float, isVisible: Bool) {
        self.rir = rir
        self.isVisible = isVisible
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                Text(LocalizedStringKey(Self.tooltipKey(for: rir)), bundle: .module)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    // Smoke-Test-Fix 2026-05-22 (Iteration 2): lineLimit
                    // ganz weg → Text bricht so oft um wie noetig.
                    // minimumScaleFactor weiter als Schrumpf-Fallback.
                    // Die Breiten-Constraint kommt JETZT vom umgebenden
                    // .frame() (siehe unten), nicht mehr vom Parent —
                    // SwiftUI weiss damit deterministisch wieviel
                    // Raum dem Text zur Verfuegung steht.
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Smoke-Test-Fix 2026-05-22 (Iteration 2): explizite Breiten-
            // Range statt nur maxWidth. Vorher gab `maxWidth: 240` nur
            // eine Obergrenze; bei engem parent-offered-width
            // (Slider-Container in SetRow auf iPhone-SE) komprimierte
            // SwiftUI den Bloop trotzdem auf ~120pt und truncated den
            // Text. Mit `minWidth: 200` zwingen wir SwiftUI mindestens
            // 200pt zu allozieren — das reicht fuer alle drei Sprachen
            // mit 2-3 Zeilen Umbruch. `idealWidth: 220` bestimmt den
            // bevorzugten Wert wenn das Parent flexibel ist; `maxWidth:
            // 240` verhindert Off-Screen-Sliding auf iPhone-SE
            // (375pt - Card-Padding ~76 = 299pt verfuegbar, 240 sitzt
            // bequem drin).
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)
            // Kartenflaeche/Radius geprueft: bewusst `.regularMaterial`
            // statt Color.Deltiq.surface - das Bloop ist ein transientes
            // Popover ueber wechselndem Untergrund (Slider/Card-Farben),
            // kein persistenter Bento-Card-Container. Radius 12 passt zur
            // Familie kleinerer Controls (siehe DayPickerSheet-Rows),
            // nicht zur 20pt-Karten-Konvention. Gleiches Material-Muster
            // wie der swapResultToast in DayEditorView.
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .opacity
            ))
            .zIndex(1000)
            .allowsHitTesting(false)
        }
    }

    /// Maps Float-RIR → Catalog-Key im 0.5er-Raster des Sliders.
    ///
    /// DEL-205: Vorher floorte das Mapping auf Integer-Buckets — 2.5 zeigte
    /// denselben Text wie 2 ("noch 2 Wiederholungen möglich"), was bei einem
    /// bewusst gewählten Halbwert irreführend war. Jetzt hat jeder Halbschritt
    /// einen eigenen Range-Text ("noch 2-3 Wiederholungen möglich").
    /// Mapping über `rir * 2` gerundet, damit Float-Wackler (2.4999) nicht
    /// in den falschen Bucket kippen.
    static func tooltipKey(for rir: Float) -> String {
        let halfSteps = Int((rir * 2).rounded())
        switch halfSteps {
        case ...0: return "rir.tooltip.0"      // Defensive (Slider-Range ist 0...5)
        case 1:    return "rir.tooltip.0_5"
        case 2:    return "rir.tooltip.1"
        case 3:    return "rir.tooltip.1_5"
        case 4:    return "rir.tooltip.2"
        case 5:    return "rir.tooltip.2_5"
        case 6:    return "rir.tooltip.3"
        case 7:    return "rir.tooltip.3_5"
        default:   return "rir.tooltip.4plus"
        }
    }
}

/// DEL-143: State-Holder + Auto-Hide-Timer für Tooltip-Sichtbarkeit.
/// Wird als `@State`-Property in der Slider-View instanziiert; ihre
/// `setVisible(_:)`-Methode handhabt das Show-Immediately/Hide-Delayed-
/// Verhalten zentral.
///
/// Verwendung:
/// ```swift
/// @State private var rirTooltip = RIRTooltipController()
///
/// Slider(value: $rir, in: 0...5, step: 0.5, onEditingChanged: { editing in
///     rirTooltip.setVisible(editing)
/// })
/// .overlay(alignment: .top) {
///     RIRTooltipBloop(rir: rir, isVisible: rirTooltip.isVisible)
///         .offset(y: -38)
/// }
/// ```
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Observable
public final class RIRTooltipController {

    public var isVisible: Bool = false

    /// Aktueller Hide-Task — wird gecancelt wenn der User wieder am
    /// Slider zieht, bevor der erste Hide ausgelöst hat. Verhindert
    /// dass das Tooltip aus dem Hintergrund verschwindet während der
    /// User noch interagiert.
    private var hideTask: Task<Void, Never>?

    public init() {}

    /// Hide-Delay nach Drag-Release. Ticket: 1.5-2 Sekunden — wir
    /// nehmen den Mittelwert.
    private let hideDelay: Duration = .milliseconds(1800)

    /// Triggert show/hide basierend auf dem Slider-Edit-State.
    ///   * `editing == true` → Tooltip sofort zeigen, alten Hide-Task
    ///     canceln.
    ///   * `editing == false` → Tooltip nach `hideDelay` ausblenden.
    public func setVisible(_ editing: Bool) {
        hideTask?.cancel()
        if editing {
            withAnimation(.easeOut(duration: 0.18)) {
                isVisible = true
            }
        } else {
            hideTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: hideDelay)
                if Task.isCancelled { return }
                withAnimation(.easeIn(duration: 0.25)) {
                    self.isVisible = false
                }
            }
        }
    }

    /// Hard-reset (z.B. wenn der User die Settings-Toggle ausschaltet
    /// während ein Tooltip sichtbar ist).
    public func forceHide() {
        hideTask?.cancel()
        isVisible = false
    }
}
#endif
