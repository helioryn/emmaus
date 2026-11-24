import Foundation

/// Turns whatever a person types into a safe FTS4 MATCH expression.
///
/// Every term is quoted, so punctuation can never be read as FTS syntax.
/// `AND`, `OR` and `NOT` survive as operators, a trailing `*` asks for a prefix
/// match, and an empty result means "do not query".
enum SearchQuery {
    /// Anything past this is ignored. Keeps pathological input cheap.
    static let maxLength = 200

    enum Token: Equatable {
        case word(String, prefix: Bool)
        case phrase(String)
        case op(String)
    }

    static func ftsExpression(_ raw: String) -> String {
        var tokens = tokenize(raw)
        guard !tokens.isEmpty else { return "" }

        // A bare final word is treated as a prefix, so "lov" finds "love",
        // "loved" and "lovingly". An explicit `*` does the same anywhere.
        if let last = tokens.last, case .word(let text, false) = last, text.count >= 2 {
            tokens[tokens.count - 1] = .word(text, prefix: true)
        }

        var pieces: [String] = []
        for token in tokens {
            switch token {
            case .op(let op):
                guard !pieces.isEmpty, !isOperator(pieces[pieces.count - 1]) else { continue }
                pieces.append(op)
            case .word(let text, let prefix):
                guard let word = sanitize(text, allowSpaces: false),
                      word.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) })
                else { continue }
                pieces.append("\"\(word)\"" + (prefix ? "*" : ""))
            case .phrase(let text):
                guard let phrase = sanitize(text, allowSpaces: true) else { continue }
                pieces.append("\"\(phrase)\"")
            }
        }
        while let last = pieces.last, isOperator(last) { pieces.removeLast() }
        return join(pieces)
    }

    // MARK: - Parsing

    static func tokenize(_ raw: String) -> [Token] {
        let chars = Array(raw.prefix(maxLength))
        var tokens: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c == "\"" {
                var j = i + 1
                var body = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == "\"" { closed = true; break }
                    body.append(chars[j])
                    j += 1
                }
                if closed {
                    if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        tokens.append(.phrase(body))
                    }
                    i = j + 1
                } else {
                    // Unbalanced quote: ignore it and keep reading words.
                    i += 1
                    continue
                }
                continue
            }
            var j = i
            var body = ""
            while j < chars.count, !chars[j].isWhitespace, chars[j] != "\"" {
                body.append(chars[j])
                j += 1
            }
            tokens.append(contentsOf: bareWords(body))
            i = j
        }
        return tokens
    }

    private static func bareWords(_ raw: String) -> [Token] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let upper = trimmed.uppercased()
        if upper == "AND" || upper == "OR" || upper == "NOT" { return [.op(upper)] }
        var text = trimmed
        var prefix = false
        while text.hasSuffix("*") {
            text.removeLast()
            prefix = true
        }
        guard !text.isEmpty else { return [] }
        return [.word(text, prefix: prefix)]
    }

    // MARK: - Helpers

    private static func isOperator(_ piece: String) -> Bool {
        piece == "AND" || piece == "OR" || piece == "NOT"
    }

    /// Joins terms with an explicit AND so mixed AND/OR queries keep the
    /// meaning people expect.
    private static func join(_ pieces: [String]) -> String {
        var out = ""
        var lastWasOperator = false
        for piece in pieces {
            if isOperator(piece) {
                out += " \(piece)"
                lastWasOperator = true
            } else if out.isEmpty {
                out = piece
                lastWasOperator = false
            } else if lastWasOperator {
                out += " \(piece)"
                lastWasOperator = false
            } else {
                out += " AND \(piece)"
                lastWasOperator = false
            }
        }
        return out
    }

    /// Keeps letters, digits, apostrophes, hyphens and marks; drops everything
    /// that FTS could mistake for syntax.
    static func sanitize(_ raw: String, allowSpaces: Bool) -> String? {
        var out = ""
        for scalar in raw.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar) {
                out.unicodeScalars.append(scalar)
            } else if CharacterSet(charactersIn: "'’-").contains(scalar) {
                out.unicodeScalars.append(scalar)
            } else if allowSpaces, CharacterSet.whitespaces.contains(scalar) {
                out.append(" ")
            }
        }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        let trimmed = out.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Splits a query into the words a literal (LIKE) search should require.
    static func literalTerms(_ raw: String) -> [String] {
        tokenize(raw).compactMap { token in
            switch token {
            case .word(let text, _): return sanitize(text, allowSpaces: false)
            case .phrase: return nil
            case .op: return nil
            }
        }
    }
}
