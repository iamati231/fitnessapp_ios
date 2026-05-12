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

    /// Adds a "Fertig" toolbar button above the keyboard that dismisses
    /// focus. Without this, the decimal-pad keyboard covers the bottom of
    /// the screen and the user has no way to navigate back — Apple's
    /// number-pad keyboards have no built-in return/dismiss key.
    ///
    /// Uses `UIResponder.resignFirstResponder` (instead of `@FocusState`)
    /// so the modifier is fully stateless and can be applied at any view
    /// level via a one-liner. No-op on macOS.
    @ViewBuilder
    func keyboardDismissToolbar() -> some View {
        #if os(iOS)
        self.toolbar {
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
        #else
        self
        #endif
    }
}
#endif
