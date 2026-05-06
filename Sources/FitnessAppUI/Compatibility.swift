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
}
#endif
