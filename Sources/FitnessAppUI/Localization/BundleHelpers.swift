#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// Convenience reference to this package's localization bundle. Without this, every
/// `Text("key")` would resolve against `Bundle.main` (the host app) — and miss our
/// `Localizable.xcstrings`.
extension LocalizedStringResource.BundleDescription {
    /// Points to the FitnessAppUI bundle so `LocalizedStringResource` calls in
    /// `DomainEnums+Localization` and similar modules find the catalog.
    static var fitnessAppUI: Self {
        .atURL(Bundle.module.bundleURL)
    }
}
#endif
