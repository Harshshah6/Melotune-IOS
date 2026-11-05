import Foundation

/// A single lyrics line. `time` is seconds; a negative value marks unsynced (plain) lyrics.
struct LrcLine: Identifiable, Hashable {
    let time: Double
    let text: String

    var id: String { "\(time)-\(text)" }
    var isSynced: Bool { time >= 0 }
}

/// Parser for LRC ("[mm:ss.xx] line") and plain lyrics, mirroring the Android
/// `LrcLib.Lyrics.sentences` behaviour but tolerant of the usual format variants.
enum LrcParser {
    private static let tagRegex = try? NSRegularExpression(
        pattern: "\\[(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,3}))?\\]",
        options: []
    )

    static func parse(_ text: String) -> [LrcLine] {
        guard let tagRegex else { return plain(text) }
        var lines: [LrcLine] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let fullRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = tagRegex.matches(in: rawLine, options: [], range: fullRange)
            guard !matches.isEmpty else { continue }

            let content = tagRegex
                .stringByReplacingMatches(in: rawLine, options: [], range: fullRange, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)

            for match in matches {
                guard let minutes = intGroup(rawLine, match, 1),
                      let seconds = intGroup(rawLine, match, 2) else { continue }
                let fraction: Double = {
                    guard let fractionString = stringGroup(rawLine, match, 3), !fractionString.isEmpty else { return 0 }
                    return Double("0.\(fractionString)") ?? 0
                }()
                let time = Double(minutes * 60 + seconds) + fraction
                lines.append(LrcLine(time: time, text: content))
            }
        }

        if lines.isEmpty {
            return plain(text)
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// Splits plain (unsynced) lyrics into lines tagged with `time = -1`.
    private static func plain(_ text: String) -> [LrcLine] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { LrcLine(time: -1, text: $0) }
    }

    private static func stringGroup(_ string: String, _ match: NSTextCheckingResult, _ index: Int) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: string) else { return nil }
        return String(string[range])
    }

    private static func intGroup(_ string: String, _ match: NSTextCheckingResult, _ index: Int) -> Int? {
        stringGroup(string, match, index).flatMap(Int.init)
    }
}
