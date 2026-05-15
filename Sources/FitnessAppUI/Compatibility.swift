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
    /// erhabene"-Gefuehl aus teuren macOS/iOS-Apps:
    /// 1 px weisser Stroke + `.blendMode(.screen)`. Im Dark-Mode entsteht
    /// ein feiner Highlight-Saum auf dunklem Hintergrund; im Light-Mode
    /// ist screen-blend mit Weiss praktisch unsichtbar → sicher fuer beide
    /// ColorSchemes ohne if/else.
    ///
    /// Hitt-Testing wird abgeschaltet, damit Taps durch den Overlay auf
    /// das darunterliegende TextField/Button durchgehen.
    func innerLightStroke(cornerRadius: CGFloat = 8, opacity: Double = 0.10) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(opacity), lineWidth: 1)
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
    }

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
#endif
