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
