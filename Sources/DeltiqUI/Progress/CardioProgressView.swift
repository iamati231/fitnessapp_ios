#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct CardioProgressView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            String(localized: "progress.section.cardio", bundle: .module),
            systemImage: "heart.fill",
            description: Text("progress.placeholder.comingSoon", bundle: .module)
        )
        .navigationTitle(String(localized: "progress.section.cardio", bundle: .module))
    }
}
#endif
