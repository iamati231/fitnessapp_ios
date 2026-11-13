#if canImport(SwiftUI)
import Foundation
import UniformTypeIdentifiers
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Manages local media files for custom exercise demonstrations.
/// Files live in `<app documents>/custom_exercise_media/<UUID>.<ext>`.
/// Only for `isCustom` ExerciseTemplate entries — system exercises use bundle GIFs.
enum CustomExerciseMediaStore {

    /// Supported local media types for `fileImporter`.
    static let videoTypes: [UTType] = [.movie]
    static let gifTypes: [UTType] = [.gif]

    /// Max allowed video duration in seconds.
    static let maxVideoSeconds: Double = 15

    // MARK: - File access

    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_exercise_media", isDirectory: true)
    }

    /// Returns the absolute URL for a stored filename.
    static func url(forFilename filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    static func fileExists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forFilename: filename).path)
    }

    // MARK: - Write / Delete

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(forFilename: filename))
    }

    // MARK: - Import helper

    /// Max allowed file size (100 MB).
    static let maxBytes = 100_000_000

    /// Opens security-scoped URL, copies file to storage, returns filename.
    /// Throws `CustomMediaError` on failure.
    static func `import`(from url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw CustomMediaError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Size check via metadata — avoids loading the full file into RAM.
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxBytes {
            throw CustomMediaError.fileTooLarge
        }

        let ext = url.pathExtension.lowercased().isEmpty ? "mp4" : url.pathExtension.lowercased()

        // Duration check for video files (not GIFs).
        #if canImport(AVFoundation)
        if ext != "gif" {
            let asset = AVURLAsset(url: url)
            let duration = asset.duration
            if duration.isValid && !duration.isIndefinite && duration.seconds > maxVideoSeconds {
                throw CustomMediaError.tooLong
            }
        }
        #endif

        let dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + ext
        do {
            try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(filename))
        } catch {
            throw CustomMediaError.readFailed
        }
        return filename
    }
}

enum CustomMediaError: LocalizedError {
    case accessDenied, readFailed, fileTooLarge, tooLong

    var errorDescription: String? {
        switch self {
        case .accessDenied, .readFailed: return String(localized: "customExercise.media.importError", bundle: .module)
        case .fileTooLarge: return String(localized: "customExercise.media.fileTooLarge", bundle: .module)
        case .tooLong: return String(localized: "customExercise.media.videoTooLong", bundle: .module)
        }
    }
}
#endif
