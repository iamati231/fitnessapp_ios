import Foundation

/// Sex used as input to body-composition formulas (Navy KFA, Deurenberg, Mifflin-St Jeor).
/// Independent of any user-facing identity concept — purely a formula parameter.
public enum BodyFormulaProfile: String, Codable, Sendable, CaseIterable {
    case male
    case female
}
