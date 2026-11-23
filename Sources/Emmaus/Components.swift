import SwiftUI
import AppKit

// MARK: - Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth.isFinite ? maxWidth : widest), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Surfaces

struct CardSurface: ViewModifier {
    var theme: Theme
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.border.opacity(0.8), lineWidth: 0.7)
                    )
            )
    }
}

extension View {
    func cardSurface(_ theme: Theme, padding: CGFloat = 14) -> some View {
        modifier(CardSurface(theme: theme, padding: padding))
    }
}

struct SectionLabel: View {
    var text: String
    var theme: Theme

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.1)
            .foregroundColor(theme.secondary)
    }
}

struct Pill: View {
    var text: String
    var theme: Theme
    var tint: Color? = nil
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(filled ? theme.card : (tint ?? theme.accent))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(filled ? (tint ?? theme.accent) : (tint ?? theme.accent).opacity(0.10))
            )
    }
}

struct IconButton: View {
    var systemName: String
    var theme: Theme
    var help: String = ""
    var active: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(active ? theme.accent : (hovering ? theme.ink : theme.secondary))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering || active ? theme.accent.opacity(0.10) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var theme: Theme
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(theme.isDark ? theme.bg : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((tint ?? theme.accent).opacity(configuration.isPressed ? 0.8 : 1))
            )
            .contentShape(Rectangle())
    }
}

struct SoftButtonStyle: ButtonStyle {
    var theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.accent.opacity(configuration.isPressed ? 0.18 : 0.09))
            )
            .contentShape(Rectangle())
    }
}

struct EmptyState: View {
    var icon: String
    var title: String
    var message: String
    var theme: Theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(theme.accent.opacity(0.8))
            Text(title)
                .font(Typography.ui(15, weight: .semibold))
                .foregroundColor(theme.ink)
            Text(message)
                .font(Typography.ui(12.5))
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

struct RefChip: View {
    var label: String
    var theme: Theme
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(theme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme.accent.opacity(hovering ? 0.16 : 0.08))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct EmmausToggleStyle: ToggleStyle {
    var theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? theme.accent : theme.border.opacity(0.75))
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .padding(2)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    configuration.isOn.toggle()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                configuration.isOn.toggle()
            }
        }
    }
}

// MARK: - Decorative

struct BrandMark: View {
    var theme: Theme
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(colors: [theme.accent.opacity(0.95), theme.accent.opacity(0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(theme.isDark ? theme.bg : .white)
        }
        .frame(width: size, height: size)
        .shadow(color: theme.accent.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

struct ToastView: View {
    var message: String
    var theme: Theme

    var body: some View {
        Text(message)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(theme.isDark ? theme.bg : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(theme.isDark ? theme.ink.opacity(0.95) : theme.ink.opacity(0.92))
            )
            .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
            .padding(.bottom, 26)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Text helpers

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

enum TextUtil {
    static func splitWords(_ text: String) -> [(String, Bool)] {
        // Returns word chunks with a flag indicating whether a space followed.
        var out: [(String, Bool)] = []
        var current = ""
        for ch in text {
            if ch == " " {
                if !current.isEmpty {
                    out.append((current, true))
                    current = ""
                } else if let last = out.last {
                    out[out.count - 1] = (last.0 + " ", last.1)
                } else {
                    current = " "
                }
            } else if ch == "\n" {
                if !current.isEmpty {
                    out.append((current, true))
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { out.append((current, false)) }
        return out
    }

    static func initials(_ s: String) -> String {
        s.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Morphology

enum Morph {
    static func short(_ code: String) -> String {
        guard !code.isEmpty else { return "" }
        if code.uppercased().hasPrefix("H") {
            return code.replacingOccurrences(of: "TH", with: "H")
        }
        return code.uppercased()
    }

    static func label(_ code: String) -> String? {
        guard !code.isEmpty else { return nil }
        let upper = code.uppercased()
        // Greek Robinson-style codes
        if upper.contains("-") && !upper.hasPrefix("H") {
            let parts = upper.split(separator: "-").map(String.init)
            guard let first = parts.first else { return nil }
            var words: [String] = []
            switch first {
            case "V": words.append("Verb")
            case "N": words.append("Noun")
            case "A": words.append("Adjective")
            case "T": words.append("Article")
            case "P": words.append("Pronoun")
            case "PREP": words.append("Preposition")
            case "CONJ": words.append("Conjunction")
            case "ADV": words.append("Adverb")
            case "PRT": words.append("Particle")
            case "INJ": words.append("Interjection")
            default: words.append(first)
            }
            if parts.count > 1 {
                let t = parts[1]
                let tenseMap: [Character: String] = ["P": "Present", "A": "Aorist", "I": "Imperfect", "F": "Future", "X": "Perfect", "Y": "Pluperfect"]
                let voiceMap: [Character: String] = ["A": "Active", "M": "Middle", "P": "Passive", "E": "Middle/Passive", "D": "Deponent"]
                let moodMap: [Character: String] = ["I": "Indicative", "S": "Subjunctive", "O": "Optative", "M": "Imperative", "P": "Participle", "N": "Infinitive"]
                if t.count >= 1, let tense = tenseMap[t.first!] { words.append(tense) }
                if t.count >= 2, let voice = voiceMap[Array(t)[1]] { words.append(voice) }
                if t.count >= 3, let mood = moodMap[Array(t)[2]] { words.append(mood) }
            }
            if parts.count > 2 {
                let p = parts[2]
                if p.count >= 2 {
                    let personMap: [Character: String] = ["1": "1st", "2": "2nd", "3": "3rd"]
                    if let person = personMap[p.first!] { words.append(person + " person") }
                    let numMap: [Character: String] = ["S": "singular", "P": "plural"]
                    if let num = numMap[Array(p)[1]] { words.append(num) }
                    if p.count >= 3 {
                        let gMap: [Character: String] = ["M": "masculine", "F": "feminine", "N": "neuter"]
                        if let g = gMap[Array(p)[2]] { words.append(g) }
                    }
                }
                let caseMap: [Character: String] = ["N": "nominative", "G": "genitive", "D": "dative", "A": "accusative", "V": "vocative"]
                if let c = parts[2].first, let k = caseMap[c], parts[1].count >= 3 {
                    words.append(k)
                }
            }
            return words.joined(separator: " ")
        }
        return nil
    }
}

// MARK: - External links

struct InlineRefText: View {
    var text: String
    var theme: Theme
    var size: CGFloat = 12.5
    var color: Color? = nil
    var onOpen: (Location) -> Void

    var body: some View {
        Text(attributed)
            .font(Typography.reading(size: size, serif: true))
            .foregroundColor(color ?? theme.secondary)
            .tint(theme.accent)
            .lineSpacing(3.5)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "emmaus-ref" {
                    if let loc = Self.location(from: url) { onOpen(loc) }
                    return .handled
                }
                return .systemAction
            })
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let pattern = try! NSRegularExpression(
            pattern: #"\b((?:[1-3]\s*)?(?:Gen|Ex|Lev|Num|Deut|Josh|Judg|Ruth|1\s*Sam|2\s*Sam|1\s*Kgs?|2\s*Kgs?|1\s*Chr|2\s*Chr|Ezra|Neh|Esth?|Job|Ps|Pss|Prov|Eccl|Song|Isa|Jer|Lam|Ezek|Dan|Hos|Joel|Amos|Obad|Jonah|Mic|Nah|Hab|Zeph|Hag|Zech|Mal|Matt|Mark|Luke|John|Acts|Rom|1\s*Cor|2\s*Cor|Gal|Eph|Phil|Col|1\s*Thess|2\s*Thess|1\s*Tim|2\s*Tim|Titus|Phlm|Heb|Jas|1\s*Pet|2\s*Pet|1\s*John|2\s*John|3\s*John|Jude|Rev)\.?\s*\d+:\d+(?:[-–]\d+)?)\b"#
        )
        let ns = text as NSString
        for m in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let r = Range(m.range, in: text) else { continue }
            let label = String(text[r])
            if let ar = result.range(of: label), let loc = ReferenceParser.parse(label) {
                result[ar].link = URL(string: "emmaus-ref://\(loc.book)/\(loc.chapter)/\(loc.verse ?? 1)")
                result[ar].foregroundColor = theme.accent
            }
        }
        return result
    }

    static func location(from url: URL) -> Location? {
        let parts = url.path.split(separator: "/").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Location(book: parts[0], chapter: parts[1], verse: parts.count > 2 ? parts[2] : nil)
    }
}
