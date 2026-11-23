import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case parchment, light, sepia, night, slate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .parchment: return "Parchment"
        case .light: return "Daylight"
        case .sepia: return "Sepia"
        case .night: return "Night"
        case .slate: return "Slate"
        }
    }

    var theme: Theme {
        switch self {
        case .parchment:
            return Theme(bg: Color(hex: "F4EFE5"), bg2: Color(hex: "EDE6D8"), panel: Color(hex: "F8F4EC"),
                         card: Color(hex: "FCF9F3"), ink: Color(hex: "2B241B"), secondary: Color(hex: "6E6252"),
                         accent: Color(hex: "8A5A2B"), red: Color(hex: "A22B2B"), border: Color(hex: "DCD1BF"),
                         selection: Color(hex: "EFE2CB"), highlight: Color(hex: "F7E7C8"), isDark: false)
        case .light:
            return Theme(bg: Color(hex: "FBFBFD"), bg2: Color(hex: "F3F3F7"), panel: Color(hex: "F7F7FA"),
                         card: Color(hex: "FFFFFF"), ink: Color(hex: "1C1C1E"), secondary: Color(hex: "6E6E73"),
                         accent: Color(hex: "3E5F8A"), red: Color(hex: "B3261E"), border: Color(hex: "E3E3E9"),
                         selection: Color(hex: "EAF0F9"), highlight: Color(hex: "FFF3C9"), isDark: false)
        case .sepia:
            return Theme(bg: Color(hex: "F0E5CC"), bg2: Color(hex: "E8DABB"), panel: Color(hex: "F5EBD7"),
                         card: Color(hex: "FAF2E1"), ink: Color(hex: "3B2E1B"), secondary: Color(hex: "7B6848"),
                         accent: Color(hex: "8A5A24"), red: Color(hex: "9C2B20"), border: Color(hex: "D9C6A3"),
                         selection: Color(hex: "EBD9B8"), highlight: Color(hex: "F3DFA9"), isDark: false)
        case .night:
            return Theme(bg: Color(hex: "14161A"), bg2: Color(hex: "191C21"), panel: Color(hex: "1B1E24"),
                         card: Color(hex: "22262E"), ink: Color(hex: "E9E3D7"), secondary: Color(hex: "9B958A"),
                         accent: Color(hex: "D4A85C"), red: Color(hex: "E07163"), border: Color(hex: "30353F"),
                         selection: Color(hex: "2B313B"), highlight: Color(hex: "4A3E24"), isDark: true)
        case .slate:
            return Theme(bg: Color(hex: "1D232B"), bg2: Color(hex: "222A34"), panel: Color(hex: "242C36"),
                         card: Color(hex: "2A333E"), ink: Color(hex: "E7ECF3"), secondary: Color(hex: "9AA8B8"),
                         accent: Color(hex: "7FA9D6"), red: Color(hex: "E08070"), border: Color(hex: "38434F"),
                         selection: Color(hex: "31404F"), highlight: Color(hex: "3D4A3A"), isDark: true)
        }
    }
}

struct Theme {
    var bg: Color
    var bg2: Color
    var panel: Color
    var card: Color
    var ink: Color
    var secondary: Color
    var accent: Color
    var red: Color
    var border: Color
    var selection: Color
    var highlight: Color
    var isDark: Bool

    var gradient: LinearGradient {
        LinearGradient(colors: [bg, bg2], startPoint: .top, endPoint: .bottom)
    }

    var accentSoft: Color { accent.opacity(isDark ? 0.18 : 0.10) }
    var subtleBorder: Color { border.opacity(0.7) }
}

struct Typography {
    static func reading(size: CGFloat, serif: Bool = true, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        var f = Font.system(size: size, weight: weight, design: serif ? .serif : .default)
        if italic { f = f.italic() }
        return f
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func smallCaps(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}

enum Palette {
    static let highlightNames = ["Amber", "Rose", "Sage", "Sky", "Lilac"]
    static func color(_ index: Int, dark: Bool) -> Color {
        switch index {
        case 0: return Color(hex: dark ? "6A5320" : "F5DF9B")
        case 1: return Color(hex: dark ? "6B3034" : "F4C9C9")
        case 2: return Color(hex: dark ? "2F5138" : "CFE6C9")
        case 3: return Color(hex: dark ? "26465C" : "C9E1F2")
        case 4: return Color(hex: dark ? "463A60" : "DED0F2")
        default: return Color.clear
        }
    }
}
