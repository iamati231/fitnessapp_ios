#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Olympic-bar visualization with stacked plates — port of Android `PlateBarVisualization.kt`.
///
/// **Design invariants** (1:1 from Android tickets F182 / F186 / F188 / F189):
/// * Bar takes a **fixed 50%** of the canvas width — never lengthens with more plates.
/// * No right-side collar — directly after the last plate the empty sleeve runs out.
/// * Inner-sleeve stub on the LEFT (~20pt) marks where the rod ends and the loadable area begins.
/// * Plates are pure shapes — no text labels (IWF colors plus a legend below identify them).
/// * Plate height scales with weight; plate width has two tiers (≥10 unit = 10pt, <10 = 5pt).
/// * 3D look: vertical gradient (light top, solid middle, dark bottom) plus a faint dark stroke
///   so neighbouring same-color plates stay visually distinct.
@available(iOS 17.0, macOS 14.0, *)
public struct PlateBarVisualization: View {
    public let plates: [PlateConfig]
    public let unit: PlateCalculator.Unit

    public init(plates: [PlateConfig], unit: PlateCalculator.Unit) {
        self.plates = plates
        self.unit = unit
    }

    public var body: some View {
        Canvas { context, size in
            draw(in: context, size: size)
        }
        .frame(height: 96)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: Drawing

    private func draw(in context: GraphicsContext, size: CGSize) {
        let isLbs = unit == .lbs
        let canvasH = size.height
        let cy = canvasH / 2

        let barH: CGFloat = 7
        let maxPlateH = canvasH * 0.943
        let plateGap: CGFloat = 2
        let stubW: CGFloat  = 20
        let stubH = barH * 2.6

        // Bar takes 50% of canvas width — fixed, plate-count-independent.
        let rodRight = size.width * 0.5

        // ── 1) Rod ────────────────────────────────────────────────────────────
        let rodTop = cy - barH / 2
        let rodRect = CGRect(x: 0, y: rodTop, width: rodRight, height: barH)
        context.fill(
            Path(roundedRect: rodRect, cornerRadius: barH / 2),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: hex(0xD8D8D8), location: 0.0),
                    .init(color: hex(0x7E7E7E), location: 0.5),
                    .init(color: hex(0xC8C8C8), location: 1.0)
                ]),
                startPoint: CGPoint(x: 0, y: rodTop),
                endPoint:   CGPoint(x: 0, y: rodTop + barH)
            )
        )

        // ── 2) Inner-sleeve stub ──────────────────────────────────────────────
        let stubTop = cy - stubH / 2
        let stubRect = CGRect(x: 0, y: stubTop, width: stubW, height: stubH)
        context.fill(
            Path(roundedRect: stubRect, cornerRadius: 2),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: hex(0xB0B0B0), location: 0.0),
                    .init(color: hex(0x555555), location: 0.5),
                    .init(color: hex(0xA0A0A0), location: 1.0)
                ]),
                startPoint: CGPoint(x: 0, y: stubTop),
                endPoint:   CGPoint(x: 0, y: stubTop + stubH)
            )
        )
        // Stub gloss
        context.fill(
            Path(roundedRect: CGRect(x: 0, y: stubTop, width: stubW, height: stubH * 0.18),
                 cornerRadius: 2),
            with: .color(.white.opacity(0.20))
        )

        // ── 3) Compute plate scaling ──────────────────────────────────────────
        let expanded = plates.flatMap { Array(repeating: $0.weight, count: $0.count) }
        guard !expanded.isEmpty else { return }

        let rawTotal = expanded.reduce(CGFloat(0)) { $0 + plateWidth(for: $1) }
                     + max(CGFloat(expanded.count - 1), 0) * plateGap
        let sleeveAvailable = max(rodRight - stubW - 4, 1)
        let scale: CGFloat = rawTotal > sleeveAvailable
            ? max(sleeveAvailable / rawTotal, 0.05)
            : 1.0

        // ── 4) Plates ─────────────────────────────────────────────────────────
        var rightX = stubW + plateGap / 2
        for w in expanded {
            let pw = plateWidth(for: w) * scale
            let ph = maxPlateH * plateHeightFactor(for: w, isLbs: isLbs)
            let top = cy - ph / 2
            let plateRect = CGRect(x: rightX, y: top, width: pw, height: ph)
            let path = Path(roundedRect: plateRect, cornerRadius: 2)

            let baseRGB = plateRGB(for: w, isLbs: isLbs)
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: baseRGB.lightened(by: 0.18).color, location: 0.0),
                        .init(color: baseRGB.color,                    location: 0.5),
                        .init(color: baseRGB.darkened(by: 0.20).color, location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint:   CGPoint(x: 0, y: top + ph)
                )
            )

            // Top gloss (12% of plate height)
            context.fill(
                Path(roundedRect: CGRect(x: rightX, y: top, width: pw, height: ph * 0.12),
                     cornerRadius: 2),
                with: .color(.white.opacity(0.22))
            )
            // Dark stroke (separates same-color neighbours)
            context.stroke(path, with: .color(.black.opacity(0.40)), lineWidth: 0.7)

            rightX += pw + plateGap * scale
        }
    }

    // MARK: Lookups

    /// Plate visual height as a fraction of `maxPlateH`.
    /// Largest plate = 1.00, smallest ≈ 0.32 — same scale as Android.
    private func plateHeightFactor(for w: Double, isLbs: Bool) -> CGFloat {
        if isLbs {
            switch w {
            case 45...: return 1.00
            case 35...: return 0.93
            case 25...: return 0.83
            case 10...: return 0.71
            case 5...:  return 0.56
            case 2.5...: return 0.42
            default:    return 0.32
            }
        } else {
            switch w {
            case 25...: return 1.00
            case 20...: return 0.93
            case 15...: return 0.83
            case 10...: return 0.71
            case 5...:  return 0.56
            case 2.5...: return 0.42
            default:    return 0.32
            }
        }
    }

    /// Two width tiers — heavy plates (≥10) get 10pt, light ones 5pt.
    private func plateWidth(for w: Double) -> CGFloat { w >= 10 ? 10 : 5 }

    /// IWF competition colours for kg, US gym standard for lbs.
    private func plateRGB(for w: Double, isLbs: Bool) -> RGB {
        if isLbs {
            switch w {
            case 45...:  return RGB(0xEF, 0x44, 0x44)  // red    (45 lbs)
            case 35...:  return RGB(0x3B, 0x82, 0xF6)  // blue   (35 lbs)
            case 25...:  return RGB(0xF5, 0x9E, 0x0B)  // amber  (25 lbs)
            case 10...:  return RGB(0x22, 0xC5, 0x5E)  // green  (10 lbs)
            case 5...:   return RGB(0x8B, 0x5C, 0xF6)  // purple (5 lbs)
            case 2.5...: return RGB(0x9C, 0xA3, 0xAF)  // gray   (2.5 lbs)
            default:     return RGB(0x6B, 0x72, 0x80)  // dark gray (1.25 lbs)
            }
        } else {
            switch w {
            case 25...:  return RGB(0xC8, 0x00, 0x0A)  // IWF red    (25 kg)
            case 20...:  return RGB(0x1A, 0x4F, 0xC1)  // IWF blue   (20 kg)
            case 15...:  return RGB(0xCC, 0xA2, 0x00)  // IWF yellow (15 kg)
            case 10...:  return RGB(0x1A, 0x7A, 0x3C)  // IWF green  (10 kg)
            case 5...:   return RGB(0xB8, 0xB8, 0xB8)  // silver     (5 kg)
            case 2.5...: return RGB(0xD4, 0x30, 0x30)  // small red  (2.5 kg)
            default:     return RGB(0x98, 0x98, 0x98)  // small silver (1.25 kg)
            }
        }
    }

    private var accessibilityDescription: String {
        guard !plates.isEmpty else { return "Stange ohne Plates" }
        let parts = plates.map { "\($0.count) mal \(formattedWeight($0.weight)) \(unit.rawValue)" }
        return "Beladung pro Seite: " + parts.joined(separator: ", ")
    }

    /// Bugfix (Audit): war `specifier: "%g"` ohne Locale, zeigte VoiceOver
    /// also immer den Punkt als Dezimaltrenner, waehrend der sichtbare Text
    /// auf dem selben Screen (`PlateCalculatorView.formatPlate`) korrekt das
    /// lokalisierte Komma nutzt. Gleiches Muster wie dort.
    private func formattedWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.formattedTwoDecimals
    }
}

// MARK: - Color math (lighten / darken)

private struct RGB {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = Double(r) / 255
        self.g = Double(g) / 255
        self.b = Double(b) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    var color: Color { Color(red: r, green: g, blue: b) }

    /// Linear interpolation toward white.
    func lightened(by factor: Double) -> RGB {
        RGB(r: r + (1 - r) * factor,
            g: g + (1 - g) * factor,
            b: b + (1 - b) * factor)
    }

    /// Linear interpolation toward black.
    func darkened(by factor: Double) -> RGB {
        RGB(r: r * (1 - factor),
            g: g * (1 - factor),
            b: b * (1 - factor))
    }
}

private func hex(_ value: UInt32) -> Color {
    let r = Double((value >> 16) & 0xFF) / 255
    let g = Double((value >>  8) & 0xFF) / 255
    let b = Double( value        & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("100 kg / 20 kg Bar") {
    let plates = PlateCalculator.calculate(target: 100, bar: 20, unit: .kg)
    return PlateBarVisualization(plates: plates, unit: .kg)
        .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("500 kg Max-Load") {
    let plates = PlateCalculator.calculate(target: 500, bar: 20, unit: .kg)
    return PlateBarVisualization(plates: plates, unit: .kg)
        .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("315 lbs / 45 lbs Bar") {
    let plates = PlateCalculator.calculate(target: 315, bar: 45, unit: .lbs)
    return PlateBarVisualization(plates: plates, unit: .lbs)
        .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Leere Stange") {
    PlateBarVisualization(plates: [], unit: .kg)
        .padding()
}
#endif
#endif
