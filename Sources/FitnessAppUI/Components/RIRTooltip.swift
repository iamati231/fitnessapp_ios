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
                    // Smoke-Test-Fix 2026-05-22: lineLimit 2 → 3 fuer
                    // laengere Sprachen (TR "Orta uyaran — 3 temiz tekrar
                    // daha yapılabilir." passt mit 2 Zeilen knapp nicht).
                    // Plus minimumScaleFactor 0.8 als Fallback wenn der
                    // Slider-Container die Breite stark begrenzt — Text
                    // schrumpft leicht statt "..." anzuzeigen.
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Smoke-Test-Fix 2026-05-22: maxWidth 240 verhindert dass
            // der Bloop von der Slider-HStack horizontal eingequetscht
            // wird (vorher nahm er die intrinsische Slider-Breite, was
            // bei den engen SetRow-Layouts auf iPhone-SE zu Truncation
            // fuehrte).
            .frame(maxWidth: 240)
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

    /// Maps Float-RIR → Catalog-Key. RIR-Slider arbeiten in 0.5-Steps,
    /// aber die Erklärungs-Texte sind in Integer-Buckets organisiert
    /// (0/1/2/3/4+). `rounded(.down)` floored 1.5 → 1, 2.5 → 2 — das ist
    /// die semantisch passendere Richtung (User-Wahrnehmung "fast 2" vs
    /// "schon 3" → fast immer "noch 2 drin").
    static func tooltipKey(for rir: Float) -> String {
        let bucket = Int(rir.rounded(.down))
        switch bucket {
        case ..<0: return "rir.tooltip.0"   // Defensive (Slider-Range ist 0...5)
        case 0:    return "rir.tooltip.0"
        case 1:    return "rir.tooltip.1"
        case 2:    return "rir.tooltip.2"
        case 3:    return "rir.tooltip.3"
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
