#if canImport(SwiftUI)
import SwiftUI
import ImageIO
import FitnessAppCore

/// Zeigt das Ausfuehrungs-GIF einer Uebung — animiert (Detail, Workout)
/// oder als statisches erstes Frame (Auswahl-Listen, kein Ruckeln beim
/// Scrollen). Zeigt einen Platzhalter, wenn `ExerciseMediaProvider` kein
/// GIF kennt — nie ein falsches GIF, nie ein Crash.
///
/// Erstes `UIViewRepresentable` in diesem Repo (siehe `SwipeBackEnabler`
/// in `Theme.swift` fuer das einzige bisherige UIKit-Interop-Beispiel,
/// dort allerdings `UIViewControllerRepresentable`) — entsprechend
/// ausfuehrlich kommentiert, weil es hier keine etablierte Konvention
/// gibt, an der sich spaetere Aenderungen orientieren koennten.
public struct ExerciseGifView: View {
    private let exerciseName: String
    private let displayName: String
    private let animated: Bool
    private let cornerRadius: CGFloat

    public init(
        exerciseName: String,
        displayName: String,
        animated: Bool = true,
        cornerRadius: CGFloat = Deltiq.Radius.input
    ) {
        self.exerciseName = exerciseName
        self.displayName = displayName
        self.animated = animated
        self.cornerRadius = cornerRadius
    }

    private var gifURL: URL? {
        guard let fileName = ExerciseMediaProvider.gifFileName(forExerciseName: exerciseName) else {
            return nil
        }
        return Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "ExerciseGifs")
    }

    public var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder
    private var content: some View {
        if let gifURL {
            #if canImport(UIKit)
            if animated {
                GifImageView(url: gifURL)
            } else {
                StaticGifFrameView(url: gifURL, placeholder: placeholder)
            }
            #else
            // macOS-Zweig von ActiveWorkoutView (kein UIKit): immer das
            // erste Frame, nie animiert — ImageIO/CGImageSource ist
            // plattformuebergreifend, nur der UIImageView-Wrapper ist es nicht.
            StaticGifFrameView(url: gifURL, placeholder: placeholder)
            #endif
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.Deltiq.fill
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.Deltiq.textTertiary)
        }
    }

    private var accessibilityText: String {
        let format = String(localized: "exercise.gif.a11y", bundle: .module)
        return String(format: format, displayName)
    }
}

// MARK: - Statisches erstes Frame (Auswahl-Listen)

/// Dekodiert nur `Frame 0` im Hintergrund und zeigt es als normales
/// SwiftUI-`Image` — kein UIKit-Bridging pro Listenzeile, profitiert von
/// SwiftUIs eigenem View-Recycling in Listen.
private struct StaticGifFrameView<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder

    @State private var frame: CGImage?

    var body: some View {
        Group {
            if let frame {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .task(id: url) {
            let decoded = await Task.detached(priority: .userInitiated) {
                GifDecoder.loadFirstFrame(from: url)
            }.value
            if !Task.isCancelled {
                frame = decoded
            }
        }
    }
}

// MARK: - Animierte Darstellung (Detail, Workout)

#if canImport(UIKit)
import UIKit

/// `UIViewRepresentable`, weil SwiftUI keine native GIF-Animation kennt.
/// Dekodiert alle Frames + Delays im Hintergrund via `CGImageSource` und
/// spielt sie ueber `UIImageView.animationImages` in Dauerschleife ab.
struct GifImageView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var loadedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url

        let targetURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            guard let decoded = GifDecoder.loadFrames(from: targetURL) else { return }
            DispatchQueue.main.async {
                // Zwischenzeitlich ein anderes GIF angefordert (Uebung
                // gewechselt, View wiederverwendet) -> verwerfen.
                guard context.coordinator.loadedURL == targetURL else { return }
                uiView.image = decoded.images.first
                uiView.animationImages = decoded.images
                uiView.animationDuration = decoded.duration
                uiView.animationRepeatCount = 0
                uiView.startAnimating()
            }
        }
    }

    static func dismantleUIView(_ uiView: UIImageView, coordinator: Coordinator) {
        uiView.stopAnimating()
        uiView.animationImages = nil
    }
}
#endif

// MARK: - GIF-Dekodierung

enum GifDecoder {
    static func loadFirstFrame(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    #if canImport(UIKit)
    static func loadFrames(from url: URL) -> (images: [UIImage], duration: TimeInterval)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var images: [UIImage] = []
        images.reserveCapacity(count)
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            duration += frameDuration(source: source, index: index)
        }
        guard !images.isEmpty else { return nil }
        return (images, duration > 0 ? duration : Double(images.count) * 0.1)
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay > 0 ? delay : 0.1
    }
    #endif
}
#endif
