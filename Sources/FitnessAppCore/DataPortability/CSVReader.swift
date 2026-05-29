// DEL-174: CSVReader — RFC-4180 parser for the import pipeline.
//
// Counterpart to `CSVWriter`. Takes a UTF-8 string (already decoded from
// the unpacked archive entry) and yields a header row plus typed rows.
// Each row is a `[String: String]` keyed by the header — this way the
// import service can pick fields by name and tolerate column reordering
// or new additive columns added in a future formatVersion.
//
// **Spec we accept** (slightly more lenient than RFC 4180):
//   - Field delimiter: `,`
//   - Record delimiter: `\r\n` OR `\n` (older Excel exports use CRLF,
//     macOS Numbers / Python pandas often write LF)
//   - Fields may be wrapped in double quotes; inside quotes a `""` pair
//     decodes to a single `"`
//   - Trailing empty line is tolerated and skipped
//   - First record is the header
//   - UTF-8 only (we ship UTF-8 from the exporter, so foreign-locale
//     re-encodings will surface as parse errors → captured as row errors)

import Foundation

/// A parsed CSV row: the original line index (1-based, *excluding* the
/// header) plus the field map. The line index lets the caller include
/// `row N` in error messages without having to remember to count
/// themselves.
public struct CSVRow: Sendable {
    public let lineNumber: Int
    public let fields: [String: String]

    public init(lineNumber: Int, fields: [String: String]) {
        self.lineNumber = lineNumber
        self.fields = fields
    }

    /// Convenience getter — empty string for missing keys, so the caller
    /// can write `row["weight_kg"]` without optional-chaining everywhere.
    /// The downside (typo'd column name → silent empty) is acceptable
    /// because the headers come from a fixed schema we control.
    public subscript(_ key: String) -> String {
        fields[key] ?? ""
    }
}

/// Stateless reader. Initialize with the raw CSV text, then call
/// `rows()` to get the parsed rows lazily. Header is parsed eagerly so
/// the caller can sanity-check the schema before iterating.
public struct CSVReader {

    public let headers: [String]
    private let body: [[String]]   // raw rows after header

    /// Throws `CSVReadError.empty` when the input has no data.
    public init(_ text: String) throws {
        let records = Self.parse(text)
        guard let first = records.first else {
            throw CSVReadError.empty
        }
        self.headers = first
        self.body = Array(records.dropFirst())
    }

    /// All non-header rows, in source order. Each row is keyed by the
    /// header. Rows with fewer fields than the header get padded with
    /// empty strings; surplus fields are truncated (mirrors the exporter
    /// behaviour for symmetry).
    public func rows() -> [CSVRow] {
        let count = headers.count
        return body.enumerated().map { (idx, raw) in
            var fields = raw
            if fields.count < count {
                fields.append(contentsOf: Array(repeating: "", count: count - fields.count))
            } else if fields.count > count {
                fields = Array(fields.prefix(count))
            }
            var map: [String: String] = [:]
            for (h, v) in zip(headers, fields) {
                map[h] = v
            }
            // Header row is line 1; first data row starts at 2.
            return CSVRow(lineNumber: idx + 2, fields: map)
        }
    }

    // MARK: - Parser

    /// Splits the text into records (each record is an array of fields).
    /// Hand-rolled state machine — Foundation has no built-in CSV parser
    /// and pulling in another dep just for this is overkill.
    static func parse(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            if inQuotes {
                if c == "\"" {
                    // Lookahead for escaped quote
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" {
                        currentField.append("\"")
                        i = text.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = text.index(after: i)
                        continue
                    }
                } else {
                    currentField.append(c)
                    i = text.index(after: i)
                    continue
                }
            }
            // Not in quotes
            switch c {
            case "\"":
                inQuotes = true
            case ",":
                currentRecord.append(currentField)
                currentField = ""
            case "\r":
                // Eat CR; LF (if present) will terminate the record
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "\n" {
                    i = next
                }
                currentRecord.append(currentField)
                currentField = ""
                records.append(currentRecord)
                currentRecord = []
            case "\n":
                currentRecord.append(currentField)
                currentField = ""
                records.append(currentRecord)
                currentRecord = []
            default:
                currentField.append(c)
            }
            i = text.index(after: i)
        }
        // Tail: dangling field/record without trailing newline
        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField)
            records.append(currentRecord)
        }
        // Drop trailing empty records (a stray blank line at EOF is common)
        while let last = records.last, last.count == 1 && last[0].isEmpty {
            records.removeLast()
        }
        return records
    }
}

// MARK: - Errors

public enum CSVReadError: Error, LocalizedError {
    case empty

    public var errorDescription: String? {
        switch self {
        case .empty: return "CSV file is empty."
        }
    }
}

// MARK: - Typed accessors

extension CSVRow {

    /// Optional ISO-8601 parser. Accepts both with-fractional-seconds
    /// (exporter default) and without — older exports / handwritten
    /// CSVs may drop the fractional part. UTC is assumed when no offset
    /// is present.
    public func date(_ key: String) -> Date? {
        let raw = self[key]
        guard !raw.isEmpty else { return nil }
        return CSVRow.iso8601WithFraction.date(from: raw)
            ?? CSVRow.iso8601NoFraction.date(from: raw)
    }

    /// Locale-independent `Double` parser. Empty → nil. We DO NOT accept
    /// `","` as decimal separator — the exporter only ever emits `.` and
    /// accepting `,` here would collide with the field delimiter on
    /// malformed inputs.
    public func double(_ key: String) -> Double? {
        let raw = self[key]
        guard !raw.isEmpty else { return nil }
        return Double(raw)
    }

    /// `Int` parser. Empty → nil.
    public func int(_ key: String) -> Int? {
        let raw = self[key]
        guard !raw.isEmpty else { return nil }
        return Int(raw)
    }

    /// Boolean parser. `true` / `1` → true, `false` / `0` / empty → false.
    /// Anything else returns nil so the caller can flag the row.
    public func bool(_ key: String) -> Bool? {
        switch self[key].lowercased() {
        case "true", "1":   return true
        case "false", "0", "": return false
        default:            return nil
        }
    }

    /// Convenience: trims whitespace, returns nil if empty after trim.
    public func optionalString(_ key: String) -> String? {
        let trimmed = self[key].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let iso8601WithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
