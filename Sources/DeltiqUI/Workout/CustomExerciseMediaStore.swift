#if canImport(SwiftUI)
import Foundation
import UniformTypeIdentifiers

/// Manages local media files for custom exercise demonstrations.
/// Files live in `<app documents>/custom_exercise_media/<UUID>.<ext>`.
/// Only for `isCustom` ExerciseTemplate entries — system exercises use bundle GIFs.
enum CustomExerciseMediaStore {

    /// Supported local media types for `fileImporter`.
    static let videoTypes: [UTType] = [.movie]
    static let gifTypes: [UTType] = [.gif]

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

    /// Copies `data` to storage, returns the saved filename (UUID + ext).
    static func save(data: Data, fileExtension ext: String) throws -> String {
        let dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + ext.lowercased()
        try data.write(to: dir.appendingPathComponent(filename))
        return filename
    }

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(forFilename: filename))
    }

    // MARK: - Import helper

    /// Max allowed file size (100 MB).
    static let maxBytes = 100_000_000

    /// Opens security-scoped URL, copies data to storage, returns filename.
    /// Throws `CustomMediaError` on failure.
    static func `import`(from url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw CustomMediaError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw CustomMediaError.readFailed
        }
        guard data.count <= maxBytes else { throw CustomMediaError.fileTooLarge }
        let ext = url.pathExtension.lowercased().isEmpty ? "mp4" : url.pathExtension.lowercased()
        return try save(data: data, fileExtension: ext)
    }
}

enum CustomMediaError: LocalizedError {
    case accessDenied, readFailed, fileTooLarge

    var errorDescription: String? {
        switch self {
        case .accessDenied, .readFailed: return String(localized: "customExercise.media.importError", bundle: .module)
        case .fileTooLarge: return String(localized: "customExercise.media.fileTooLarge", bundle: .module)
        }
    }
}
#endif
