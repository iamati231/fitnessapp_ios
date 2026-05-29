// DEL-173: CSVWriter — RFC-4180-compliant CSV emitter for the data export.
//
// The export pipeline (FitnessAppData/DataExportService) feeds raw rows from
// SwiftData @Model fetches into this writer; the result is a single UTF-8
// Data blob per file that gets bundled into a ZIP archive.
//
// We deliberately keep this Pure-Swift (no Foundation-specific encoders) so
// the same type can be unit-tested on Windows host (where the test target
// builds without SwiftData) and on macOS/iOS targets.
//
// **Spec we follow** (RFC 4180):
//   - Fields separated by `,`
//   - Records separated by `\r\n`
//   - Fields containing `,`, `"`, `\r`, or `\n` are wrapped in double quotes
//   - Embedded `"` is escaped by doubling: `"` → `""`
//   - First record is the header row
//   - UTF-8, no BOM (Excel-safe enough; we accept that German umlauts may
//     display garbled in older Excel — Numbers/LibreOffice handle UTF-8 fine
//     and that's what most users will reach for)

import Foundation

/// Streaming CSV emitter. Append rows then call `data()` to get the final
/// UTF-8 payload. Single-use — once `data()` is called the buffer is final.
public struct CSVWriter {

    private var buffer: String = ""
    private let columnCount: Int

    /// Creates a new writer and immediately writes the header row.
    public init(headers: [String]) {
        self.columnCount = headers.count
        appendRow(headers)
    }

    /// Appends a row. Fewer columns than the header → empty strings are
    /// padded in; more columns → the surplus is truncated. We log neither
    /// case loudly because the caller (DataExportService) controls both
    /// sides of the schema and a mismatch would be a programming bug, not
    /// runtime data.
    public mutating func appendRow(_ values: [String]) {
        var normalized = values
        if normalized.count < columnCount {
            normalized.append(contentsOf: Array(repeating: "", count: columnCount - normalized.count))
        } else if normalized.count > columnCount {
            normalized = Array(normalized.prefix(columnCount))
        }
        let escaped = normalized.map(Self.escape)
        buffer.append(escaped.joined(separator: ","))
        buffer.append("\r\n")
    }

    /// Convenience for nil-tolerant rows. `nil` becomes an empty field —
    /// CSVs don't have a real "NULL" sentinel and an empty cell is the
    /// least surprising representation for downstream tools.
    public mutating func appendRow(_ values: [String?]) {
        appendRow(values.map { $0 ?? "" })
    }

    /// Finalizes the writer and returns UTF-8 bytes. Force-unwrapping the
    /// data() result is safe because String → UTF-8 conversion cannot fail
    /// for any well-formed Swift String.
    public func data() -> Data {
        buffer.data(using: .utf8)!
    }

    // MARK: - Escaping

    /// Quotes the field iff it contains a delimiter, double-quote, CR, or LF.
    /// Inside a quoted field, embedded `"` doubles up to `""`.
    static func escape(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        if !needsQuoting {
            return field
        }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

// MARK: - Value formatting helpers

extension CSVWriter {

    /// ISO-8601 UTC formatter — single shared instance to dodge the
    /// allocation cost in tight export loops.
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Canonical ISO-8601 timestamp (UTC, fractional seconds). Per the
    /// data-portability spec we ship timestamps in UTC and let the
    /// importer / downstream tool render to local time.
    public static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    /// Locale-independent decimal formatting. We always emit `.` as the
    /// separator (CSV is shipped internationally; comma would collide with
    /// the field delimiter and German Excel locale settings cause endless
    /// pain). Trailing zeros after the requested fractions are kept for
    /// columnar alignment in spreadsheet preview.
    public static func decimal(_ value: Double, fractionDigits: Int = 2) -> String {
        String(format: "%.\(fractionDigits)f", value)
    }

    /// Optional variant — empty cell if the value is nil.
    public static func decimal(_ value: Double?, fractionDigits: Int = 2) -> String {
        guard let value else { return "" }
        return decimal(value, fractionDigits: fractionDigits)
    }

    /// Boolean as "true" / "false" lowercase — the most portable form for
    /// CSV (Excel/Numbers/Python pandas all accept it without ceremony).
    public static func bool(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}
