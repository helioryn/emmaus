package com.btaylor.emmaus.data

import java.text.Normalizer

/**
 * Turns typed text into a safe FTS4 MATCH expression.
 *
 * Mirrors `Sources/Emmaus/SearchQuery.swift` so both platforms interpret a
 * query the same way. Every term is quoted, so punctuation can never be read
 * as FTS syntax; `AND`, `OR` and `NOT` survive as operators.
 */
object SearchQuery {
    const val MAX_LENGTH = 200

    sealed class Token {
        data class Word(val text: String, val prefix: Boolean = false) : Token()
        data class Phrase(val text: String) : Token()
        data class Op(val name: String) : Token()
    }

    fun ftsExpression(raw: String): String? {
        val tokens = tokenize(raw).toMutableList()
        if (tokens.isEmpty()) return null

        val last = tokens.lastOrNull()
        if (last is Token.Word && !last.prefix && last.text.length >= 2) {
            tokens[tokens.size - 1] = Token.Word(last.text, prefix = true)
        }

        val pieces = mutableListOf<String>()
        for (token in tokens) {
            when (token) {
                is Token.Op -> {
                    if (pieces.isEmpty() || isOperator(pieces.last())) continue
                    pieces += token.name
                }
                is Token.Word -> {
                    val word = sanitize(token.text, allowSpaces = false) ?: continue
                    if (word.none { it.isLetterOrDigit() }) continue
                    pieces += "\"$word\"" + if (token.prefix) "*" else ""
                }
                is Token.Phrase -> {
                    val phrase = sanitize(token.text, allowSpaces = true) ?: continue
                    pieces += "\"$phrase\""
                }
            }
        }
        while (pieces.isNotEmpty() && isOperator(pieces.last())) {
            pieces.removeAt(pieces.size - 1)
        }
        return join(pieces).ifEmpty { null }
    }

    fun tokenize(raw: String): List<Token> {
        val chars = raw.take(MAX_LENGTH)
        val tokens = mutableListOf<Token>()
        var i = 0
        while (i < chars.length) {
            val c = chars[i]
            if (c.isWhitespace()) { i++; continue }
            if (c == '"') {
                var j = i + 1
                val body = StringBuilder()
                var closed = false
                while (j < chars.length) {
                    if (chars[j] == '"') { closed = true; break }
                    body.append(chars[j])
                    j++
                }
                if (closed) {
                    if (body.isNotBlank()) tokens += Token.Phrase(body.toString())
                    i = j + 1
                } else {
                    i++
                }
                continue
            }
            var j = i
            val body = StringBuilder()
            while (j < chars.length && !chars[j].isWhitespace() && chars[j] != '"') {
                body.append(chars[j])
                j++
            }
            tokens += bareWords(body.toString())
            i = j
        }
        return tokens
    }

    private fun bareWords(raw: String): List<Token> {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return emptyList()
        val upper = trimmed.uppercase()
        if (upper == "AND" || upper == "OR" || upper == "NOT") return listOf(Token.Op(upper))
        var text = trimmed
        var prefix = false
        while (text.endsWith("*")) {
            text = text.dropLast(1)
            prefix = true
        }
        if (text.isEmpty()) return emptyList()
        return listOf(Token.Word(text, prefix))
    }

    private fun isOperator(piece: String): Boolean =
        piece == "AND" || piece == "OR" || piece == "NOT"

    private fun join(pieces: List<String>): String {
        val out = StringBuilder()
        var lastWasOperator = false
        for (piece in pieces) {
            when {
                isOperator(piece) -> {
                    out.append(' ').append(piece)
                    lastWasOperator = true
                }
                out.isEmpty() -> {
                    out.append(piece)
                    lastWasOperator = false
                }
                lastWasOperator -> {
                    out.append(' ').append(piece)
                    lastWasOperator = false
                }
                else -> {
                    out.append(" AND ").append(piece)
                    lastWasOperator = false
                }
            }
        }
        return out.toString()
    }

    fun sanitize(raw: String, allowSpaces: Boolean): String? {
        val out = StringBuilder()
        for (ch in raw) {
            val type = Character.getType(ch)
            val keep = ch.isLetterOrDigit() ||
                ch == '\'' || ch == '’' || ch == '-' ||
                type == Character.NON_SPACING_MARK.toInt() ||
                type == Character.COMBINING_SPACING_MARK.toInt() ||
                type == Character.ENCLOSING_MARK.toInt() ||
                (allowSpaces && ch.isWhitespace())
            if (keep) out.append(if (allowSpaces && ch.isWhitespace()) ' ' else ch)
        }
        val collapsed = out.toString().replace(Regex(" {2,}"), " ").trim()
        return collapsed.ifEmpty { null }
    }

    /** Words a literal (LIKE) fallback should all require. */
    fun literalTerms(raw: String): List<String> = tokenize(raw).mapNotNull { token ->
        when (token) {
            is Token.Word -> sanitize(token.text, allowSpaces = false)
            is Token.Phrase -> null
            is Token.Op -> null
        }
    }

    /**
     * Letters only, lowercased, with marks and punctuation removed.
     *
     * The original-language texts carry points and accents, so a query typed
     * without them is matched against this folded form instead.
     */
    fun plain(raw: String): String {
        val decomposed = Normalizer.normalize(raw, Normalizer.Form.NFD).lowercase()
        val out = StringBuilder(decomposed.length)
        for (ch in decomposed) {
            when (Character.getType(ch)) {
                Character.NON_SPACING_MARK.toInt(),
                Character.COMBINING_SPACING_MARK.toInt(),
                Character.ENCLOSING_MARK.toInt(),
                Character.FORMAT.toInt() -> Unit
                Character.SPACE_SEPARATOR.toInt() -> out.append(' ')
                Character.DECIMAL_DIGIT_NUMBER.toInt(),
                Character.LETTER_NUMBER.toInt(),
                Character.OTHER_NUMBER.toInt(),
                Character.UPPERCASE_LETTER.toInt(),
                Character.LOWERCASE_LETTER.toInt(),
                Character.TITLECASE_LETTER.toInt(),
                Character.MODIFIER_LETTER.toInt(),
                Character.OTHER_LETTER.toInt() ->
                    out.append(if (ch == '\u03C2') '\u03C3' else ch)
                else -> Unit
            }
        }
        return out.toString()
    }
}
