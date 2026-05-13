#if canImport(SwiftUI)
import SwiftUI

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

    /// Adds a native "Fertig" toolbar button INTO the keyboard's accessory
    /// bar (the gray strip directly above the keyboard) — NOT a floating
    /// pill above the keyboard. Without this, the decimal-pad keyboard
    /// covers the bottom of the screen and the user has no way to navigate
    /// back, since Apple's number-pad keyboards have no built-in
    /// return/dismiss key.
    ///
    /// Plus: `.scrollDismissesKeyboard(.interactively)` lets the user
    /// dismiss the keyboard by swiping the Form/ScrollView downward —
    /// matches the Notes-/Mail-/Reminders-app gesture (DEL-036).
    ///
    /// Uses `UIResponder.resignFirstResponder` (instead of `@FocusState`)
    /// so the modifier is fully stateless and can be applied at any view
    /// level via a one-liner. No-op on macOS.
    @ViewBuilder
    func keyboardDismissToolbar() -> some View {
        #if os(iOS)
        self
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Text("Fertig").fontWeight(.semibold)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}
#endif
