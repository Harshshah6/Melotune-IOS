import Foundation

/// Port of the Android `TextParserUtil.parseHtmlText`, which runs the string through
/// `HtmlCompat.fromHtml`. The API returns HTML-escaped values (e.g. `&quot;`, `&#039;`),
/// so we strip tags and decode the entities the API actually emits.
enum HtmlText {
    private static let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: [])

    private static let entities: [String: String] = [
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&#39;": "'",
        "&#039;": "'",
        "&apos;": "'",
        "&nbsp;": " ",
        "&rsquo;": "\u{2019}",
        "&lsquo;": "\u{2018}",
        "&ldquo;": "\u{201C}",
        "&rdquo;": "\u{201D}",
        "&hellip;": "\u{2026}",
        "&mdash;": "\u{2014}",
        "&ndash;": "\u{2013}"
    ]

    static func parse(_ html: String?) -> String {
        guard let html, !html.isEmpty else { return "" }
        var text = html
        if let regex = tagRegex {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        text = decodeNumericEntities(text)
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves `&#123;` / `&#x1F600;` style entities.
    private static let numericRegex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);", options: [])

    private static func decodeNumericEntities(_ text: String) -> String {
        guard let numericRegex else { return text }
        let ns = text as NSString
        let matches = numericRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges == 2 else { continue }
            let token = ns.substring(with: match.range(at: 1))
            let scalarValue: UInt32?
            if token.hasPrefix("x") || token.hasPrefix("X") {
                scalarValue = UInt32(token.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(token, radix: 10)
            }
            guard let value = scalarValue, let scalar = Unicode.Scalar(value) else { continue }
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            }
        }
        return result
    }
}
