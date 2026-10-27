import Foundation

/// Deterministic parser for voice-dictated workout text.
/// Handles German number words, units, set patterns, and exercise matching
/// against ExerciseLibraryData. No external dependencies.
public final class VoiceWorkoutParser: @unchecked Sendable {

    public init() {}

    // MARK: - Dictionaries

    static let deNumbers: [String: Int] = [
        "null": 0,
        "ein": 1, "eine": 1, "einem": 1, "einen": 1, "eins": 1,
        "zwei": 2, "drei": 3, "vier": 4,
        "fünf": 5, "fuenf": 5, "funf": 5,
        "sechs": 6, "sieben": 7, "acht": 8, "neun": 9,
        "zehn": 10, "elf": 11,
        "zwölf": 12, "zwoelf": 12, "zwolf": 12,
        "dreizehn": 13, "vierzehn": 14,
        "fünfzehn": 15, "fuenfzehn": 15, "funfzehn": 15,
        "sechzehn": 16, "siebzehn": 17, "achtzehn": 18, "neunzehn": 19,
        "zwanzig": 20,
        "dreißig": 30, "dreissig": 30, "dreizig": 30,
        "vierzig": 40,
        "fünfzig": 50, "fuenfzig": 50, "funfzig": 50,
        "sechzig": 60, "siebzig": 70, "achtzig": 80, "neunzig": 90,
        "hundert": 100, "einhundert": 100
    ]

    static let weightUnits: [String: Double] = [
        "kg": 1.0, "kilo": 1.0, "kilogramm": 1.0, "kilos": 1.0,
        "lb": 0.453592, "lbs": 0.453592, "pfund": 0.5,
        "pound": 0.453592, "pounds": 0.453592
    ]

    static let repUnits: Set<String> = [
        "wiederholungen", "wiederholung", "wdh", "wdhl",
        "reps", "rep", "mal"
    ]

    // Maps unit string → seconds per count
    static let timeUnits: [String: Int] = [
        "sekunden": 1, "sekunde": 1, "sek": 1, "s": 1,
        "minuten": 60, "minute": 60, "min": 60
    ]

    static let setWords: Set<String> = [
        "sätze", "satze", "saetze", "satz"
    ]

    static let jeweilsWords: Set<String> = [
        "jeweils", "je", "jeder", "jede", "jedem", "jedes"
    ]

    static let blockSplitters: Set<String> = [
        "dann", "danach", "anschließend", "anschliessend",
        "außerdem", "ausserdem", "zusätzlich", "zusaetzlich"
    ]

    static let fillers: Set<String> = [
        "mit", "und", "einem", "einer", "von", "für", "fur",
        "noch", "dem", "der", "die", "das", "im", "in", "auf",
        "an", "zu", "pro", "je", "einen"
    ]

    // Tens for compound numbers like "einundzwanzig"
    private static let compoundTens: [(String, Int)] = [
        ("zwanzig", 20), ("dreißig", 30), ("dreissig", 30), ("dreizig", 30),
        ("vierzig", 40), ("fünfzig", 50), ("fuenfzig", 50), ("funfzig", 50),
        ("sechzig", 60), ("siebzig", 70), ("achtzig", 80), ("neunzig", 90)
    ]

    // MARK: - Public API

    /// Parse a single-set dictation (e.g. "Bankdrücken 60 Kilo zehn Wiederholungen").
    /// Returns the first recognized draft. Context weight used for "same weight" references.
    public func parseSet(_ text: String, previousWeight: Double? = nil) -> VoiceDraftSet {
        let sets = parseWorkout(text, previousWeight: previousWeight)
        guard let first = sets.first else {
            return VoiceDraftSet(rawText: text)
        }
        return first
    }

    /// Parse a full workout dictation into individual set drafts.
    public func parseWorkout(_ text: String, previousWeight: Double? = nil) -> [VoiceDraftSet] {
        let blocks = splitIntoBlocks(text)
        var result: [VoiceDraftSet] = []
        var lastWeight = previousWeight

        for block in blocks {
            let sets = parseOneBlock(block, previousWeight: lastWeight)
            result.append(contentsOf: sets)
            lastWeight = sets.first?.weightKg ?? lastWeight
        }
        return result
    }

    // MARK: - Number Parsing

    func parseNumber(_ token: String) -> Int? {
        let t = token.lowercased()
        if let n = Int(t) { return n }
        if let n = Self.deNumbers[t] { return n }
        // Compound: "einundzwanzig" = 21
        for (tensStr, tensVal) in Self.compoundTens {
            let suffix = "und" + tensStr
            if t.hasSuffix(suffix) {
                let prefix = String(t.dropLast(suffix.count))
                if let oneVal = Self.deNumbers[prefix], oneVal < 10 {
                    return tensVal + oneVal
                }
            }
        }
        return nil
    }

    // MARK: - Block Splitting

    private func splitIntoBlocks(_ text: String) -> [String] {
        // Split by sentence-ending punctuation first
        var sentences: [String] = []
        for raw in text.components(separatedBy: CharacterSet(charactersIn: ".!")) {
            let s = raw.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { continue }
            // Further split by connector words
            var currentWords: [String] = []
            for word in s.components(separatedBy: .whitespaces) {
                let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if Self.blockSplitters.contains(lower), !currentWords.isEmpty {
                    sentences.append(currentWords.joined(separator: " "))
                    currentWords = []
                } else {
                    currentWords.append(word)
                }
            }
            if !currentWords.isEmpty {
                sentences.append(currentWords.joined(separator: " "))
            }
        }
        return sentences.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Single Block Parsing

    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "()")))
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(.init(charactersIn: ".,"))) }
            .filter { !$0.isEmpty }
    }

    private func parseOneBlock(_ text: String, previousWeight: Double?) -> [VoiceDraftSet] {
        // Handle comma-separated number lists before tokenizing
        // Replace ", " between numbers with " , " so commas become tokens
        let prepared = text.replacingOccurrences(of: ",", with: " , ")
        let toks = tokenize(prepared)
        let normalized = toks.map { $0.lowercased() }
        var consumed = IndexSet()

        var setCount: Int? = nil
        var weightKg: Double? = nil
        var reps: [Int] = []
        var durationSec: Int? = nil
        // Check for "previous weight" reference
        let refPrev = normalized.contains(where: { ["gleiche", "gleichen", "dieselbe", "demselben", "selbe", "selben"].contains($0) })
        if refPrev { weightKg = previousWeight }

        // Pass 1: Find rep list by scanning backward from the first rep unit
        if let repUnitIdx = normalized.firstIndex(where: { Self.repUnits.contains($0) }) {
            var listReps: [Int] = []
            var j = repUnitIdx - 1
            // Skip "und" immediately before rep unit
            while j >= 0 && (normalized[j] == "und" || normalized[j] == "oder" || normalized[j] == ",") {
                j -= 1
            }
            // Collect numbers going backward, separated by connectors
            while j >= 0 {
                if let num = parseNumber(toks[j]) {
                    listReps.insert(num, at: 0)
                    consumed.insert(j)
                    j -= 1
                    // Skip connectors between list items
                    while j >= 0 && (normalized[j] == "und" || normalized[j] == "oder" || normalized[j] == ",") {
                        consumed.insert(j)
                        j -= 1
                    }
                } else {
                    break
                }
            }
            if !listReps.isEmpty {
                reps = listReps
                consumed.insert(repUnitIdx)
            }
        }

        // Pass 2: Find (number, unit) pairs for weight, sets, duration
        var i = 0
        while i < toks.count {
            if consumed.contains(i) { i += 1; continue }
            let t = normalized[i]

            if Self.jeweilsWords.contains(t) {
                consumed.insert(i)
                i += 1; continue
            }
            if Self.fillers.contains(t) || Self.blockSplitters.contains(t) || t == "," {
                consumed.insert(i)
                i += 1; continue
            }

            if let num = parseNumber(toks[i]) {
                let nextRaw = (i + 1 < toks.count && !consumed.contains(i + 1)) ? normalized[i + 1] : ""
                // Check for decimal: "60.5" or "60,5" already split to "60" + "," + "5"
                // But if next is "," and after that is a digit, treat as decimal weight
                var numDouble = Double(num)
                if nextRaw == "," || nextRaw.contains(".") {
                    if let d = Double(toks[i].replacingOccurrences(of: ",", with: ".")) {
                        numDouble = d
                    }
                }

                // Check two tokens ahead for decimal weight like "60 , 5 kilo"
                var peekOffset = 1
                if nextRaw == "," || nextRaw == "." {
                    let afterComma = (i + 2 < toks.count && !consumed.contains(i + 2)) ? normalized[i + 2] : ""
                    if let frac = Int(afterComma) {
                        numDouble = Double(num) + Double(frac) / pow(10.0, Double(String(frac).count))
                        peekOffset = 3  // unit token is at i+3; read via normalized[unitIdx] below
                    }
                }

                let unitIdx = i + peekOffset
                if unitIdx < toks.count && !consumed.contains(unitIdx) {
                    let unitStr = normalized[unitIdx]
                    if let mult = Self.weightUnits[unitStr] {
                        if weightKg == nil { weightKg = numDouble * mult }
                        consumed.insert(i)
                        if peekOffset > 1 { consumed.insert(i+1); consumed.insert(i+2) }
                        consumed.insert(unitIdx)
                        i = unitIdx + 1; continue
                    } else if Self.setWords.contains(unitStr) {
                        setCount = num
                        consumed.insert(i); consumed.insert(unitIdx)
                        i = unitIdx + 1; continue
                    } else if let spu = Self.timeUnits[unitStr] {
                        durationSec = num * spu
                        consumed.insert(i); consumed.insert(unitIdx)
                        i = unitIdx + 1; continue
                    }
                }
                // Standalone number — consume (already handled as reps in pass 1 or noise)
                consumed.insert(i)
            } else if Self.setWords.contains(t) || Self.repUnits.contains(t) {
                consumed.insert(i)
            } else if Self.weightUnits[t] != nil || Self.timeUnits[t] != nil {
                consumed.insert(i)
            }

            i += 1
        }

        // Collect exercise name from non-consumed tokens
        let exerciseTokens = toks.enumerated()
            .filter { !consumed.contains($0.offset) && !Self.fillers.contains($0.element.lowercased()) }
            .map { $0.element }
        let exerciseName = exerciseTokens.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let (matched, matches, isAmbig) = matchExercise(exerciseName)
        let spec = matched.flatMap { ExerciseLibraryData.byName[$0] }
        let isTimeBased = spec?.isTimeBased ?? false

        // Build result sets
        let count = setCount ?? (reps.count > 1 ? reps.count : 1)
        let contradicting = reps.count > 1 && setCount != nil && setCount != reps.count

        if reps.count > 1 && !contradicting {
            // Varied reps ("10, 9 und 8 Wiederholungen")
            return reps.map { r in
                VoiceDraftSet(
                    exerciseName: matched,
                    exerciseMatches: matches,
                    weightKg: weightKg,
                    reps: r,
                    isTimeBased: false,
                    isExerciseAmbiguous: isAmbig,
                    rawText: text
                )
            }
        }

        // Uniform sets (with optional jeweils)
        return (0..<count).map { _ in
            VoiceDraftSet(
                exerciseName: matched,
                exerciseMatches: matches,
                weightKg: weightKg,
                reps: isTimeBased ? nil : reps.first,
                durationSeconds: isTimeBased ? durationSec : nil,
                isTimeBased: isTimeBased,
                isExerciseAmbiguous: isAmbig || contradicting,
                rawText: text
            )
        }
    }

    // MARK: - Exercise Matching

    private func matchExercise(_ name: String) -> (matched: String?, candidates: [String], isAmbiguous: Bool) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return (nil, [], false) }
        let normalized = cleaned.lowercased()

        // 1. Exact match (case-insensitive)
        for key in ExerciseLibraryData.byName.keys {
            if key.lowercased() == normalized { return (key, [key], false) }
        }

        // 2. Substring containment
        var candidates: [String] = []
        for key in ExerciseLibraryData.byName.keys {
            let kl = key.lowercased()
            if kl.contains(normalized) || normalized.contains(kl) {
                candidates.append(key)
            }
        }
        if candidates.count == 1 { return (candidates[0], candidates, false) }
        if candidates.count > 1 { return (nil, candidates, true) }

        // 3. Word-overlap (majority of words match)
        let nameWords = Set(normalized.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        guard nameWords.count > 0 else { return (nil, [], false) }
        for key in ExerciseLibraryData.byName.keys {
            let keyWords = Set(key.lowercased().components(separatedBy: .whitespaces))
            let overlap = nameWords.intersection(keyWords)
            if Double(overlap.count) / Double(nameWords.count) >= 0.5 {
                candidates.append(key)
            }
        }
        if candidates.count == 1 { return (candidates[0], candidates, false) }
        if candidates.count > 1 { return (nil, candidates, true) }
        return (nil, [], false)
    }
}
