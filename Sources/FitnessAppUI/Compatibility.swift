#if canImport(SwiftUI)
import SwiftUI

// MARK: - Branding

public extension Color {
    /// Deltiq's primary accent — neon-orange (#FF9F0A). Verwendet fuer
    /// Aktion-Highlights in der ActiveWorkoutView (Checkmark, RIR-Slider,
    /// Hold-Timer-Countdown, Progress-Rings). Als Code-Konstante statt
    /// Asset-Catalog, damit der Wert ohne Bundle-Path-Magic ueberall in
    /// der Library + Widget-Target verfuegbar ist (DEL-045).
    ///
    /// Light- + Dark-Mode identisch — Apple's HIG-Standard "vibrant"-
    /// Akzent, der auf beiden Hintergrund-Tones funktioniert.
    static let deltiqOrange = Color(red: 1.0, green: 0.624, blue: 0.039)
}

// MARK: - DEL-059 Premium Polish Modifier

public extension View {
    /// Subtile Licht-Kante on top of a card/input. Erzeugt das "plastisch
    /// erhabene"-Gefuehl aus teuren macOS/iOS-Apps.
    ///
    /// DEL-066: ColorScheme-aware Fallback.
    ///   * **Dark Mode**: 1 px weisser Stroke + `.blendMode(.screen)` →
    ///     feiner Highlight-Saum auf dunklem Hintergrund.
    ///   * **Light Mode**: 1 px schwarzer Stroke + `.blendMode(.multiply)` →
    ///     leichter Schatten-Saum, der das Element vom weissen Hintergrund
    ///     abhebt statt unsichtbar zu sein.
    ///
    /// Hitt-Testing wird abgeschaltet, damit Taps durch den Overlay auf
    /// das darunterliegende TextField/Button durchgehen.
    func innerLightStroke(cornerRadius: CGFloat = 8, opacity: Double = 0.10) -> some View {
        modifier(InnerLightStrokeModifier(cornerRadius: cornerRadius, opacity: opacity))
    }

    /// DEL-066 — internes ViewModifier-Backing fuer `innerLightStroke`, das
    /// per `@Environment(\.colorScheme)` zwischen Dark/Light Variante wechselt.

    /// Premium-Label-Styling: winziger, gesperrter, fetter Caption-Text.
    /// "KG", "WDH", "PACE", "RIR" — alles sekundaere Labels, die durch
    /// `.tracking(1.5)` + `.weight(.bold)` extrem viel Kontrast zu den
    /// grossen Zahlenwerten daneben schaffen. Uppercase-Wandlung NICHT
    /// hier — Caller uebergibt den String bereits in Grossbuchstaben,
    /// damit unicode-spezifische Umlaute (ß) korrekt bleiben.
    func deltiqLabel() -> some View {
        self
            .font(.caption2.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(.secondary)
            // Geraete-Abnahme (Runde 8, docs/DELTIQ_DEVICE_ACCEPTANCE.md,
            // E04): bei maximaler Bedienungshilfen-Textgroesse (AX5) brach
            // "SATZ" in SetRow.SetRowColumns' festbreitem Spalten-Header
            // buchstabenweise um (S/a/t/z untereinander), weil .caption2
            // als Dynamic-Type-Textstil ungebremst mitskaliert. Gleiches
            // Muster wie der bereits gefixte SetRow.weightInput (Runde 3).
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Cross-platform toolbar placement

extension ToolbarItemPlacement {
    /// Trailing-Position in der Navigation-Bar, plattform-sicher.
    ///
    /// `.topBarTrailing` ist `@available(macOS, unavailable)`. Fuenf Views
    /// haben es direkt benutzt (DEL-096 und DEL-136, Mai 2026), womit der
    /// macOS-Build des Pakets seit dem scheiterte — und mit ihm
    /// `swift test`, weil der auf dem Host baut. Aufgefallen ist das erst,
    /// als DEL-217 den Test-Lauf ins Release-Gate gehaengt hat: die
    /// ~300 Core-Tests liefen zweieinhalb Monate lang gar nicht.
    ///
    /// iOS behaelt exakt `.topBarTrailing` — die Alternative
    /// `.primaryAction` waere plattformneutral, wuerde auf Views mit
    /// mehreren Toolbar-Items aber die Reihenfolge veraendern, und das
    /// laesst sich ohne Simulator nicht beurteilen. macOS bekommt
    /// `.automatic`; dort ist die Platzierung nur fuer Previews relevant,
    /// die App selbst ist iOS-only.
    static var deltiqTrailing: ToolbarItemPlacement {
        #if os(iOS) || os(visionOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

// MARK: - Cross-platform view shims

/// Cross-platform shims for SwiftUI modifiers that don't exist on macOS.
extension View {
    /// `.keyboardType(.decimalPad)` on iOS/visionOS; no-op on macOS.
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Lets the user dismiss the keyboard by:
    ///   1. Swiping the Form/ScrollView downward (`.scrollDismissesKeyboard(.interactively)`)
    ///   2. Tapping anywhere in the empty background area (added via the
    ///      `.onTapGesture` chain below, which fires `resignFirstResponder`
    ///      on the responder chain).
    ///
    /// DEL-045-Update Punkt 3: Wir haben den frueheren "Fertig"-Button im
    /// keyboard-accessory entfernt, weil er Platz wegnimmt und unsauber
    /// aussieht. Die Dismiss-UX laeuft jetzt rein ueber Hintergrund-Tap +
    /// Scroll-Geste — was wesentlich naeher am System-Default ist (Notes-/
    /// Mail-App).
    ///
    /// No-op on macOS (keine On-Screen-Tastatur).
    @ViewBuilder
    func keyboardDismissToolbar() -> some View {
        #if os(iOS)
        self
            .scrollDismissesKeyboard(.interactively)
            .background(
                // Voll-flaechige Tap-Catcher hinter der View — fuengt Tippen
                // ins "Leere" ab und dismissed die Tastatur. WICHTIG: NICHT
                // .contentShape(Rectangle()) auf self setzen, weil das Taps
                // auf Buttons/Slider/etc. schluckt. Stattdessen ein hinten-
                // liegender Color.clear-Layer, der nur dann triggert wenn
                // kein interaktives Element vorne den Tap absorbiert hat.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
            )
        #else
        self
        #endif
    }
}

// MARK: - DEL-066 InnerLightStrokeModifier

/// ColorScheme-aware Inner-Stroke. Dark-Mode → weiss + screen-blend
/// (Highlight). Light-Mode → schwarz + multiply-blend (subtiler Schatten).
private struct InnerLightStrokeModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(strokeColor, lineWidth: 1)
                .blendMode(blendMode)
                .allowsHitTesting(false)
        )
    }

    private var strokeColor: Color {
        switch colorScheme {
        case .dark:  return Color.white.opacity(opacity)
        case .light: return Color.black.opacity(max(0.04, opacity * 0.5))
        @unknown default: return Color.white.opacity(opacity)
        }
    }

    private var blendMode: BlendMode {
        switch colorScheme {
        case .dark:  return .screen
        case .light: return .multiply
        @unknown default: return .screen
        }
    }
}
#endif
