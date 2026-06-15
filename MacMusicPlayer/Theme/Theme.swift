import SwiftUI

/// Simple solid color themes for the player.
enum PlayerTheme: String, CaseIterable {
    case blue
    case green
    case purple
    case pink
    case black

    var accent: Color {
        switch self {
        case .blue:   return Color(red: 0.376, green: 0.690, blue: 1.0)    // #60b0ff
        case .green:  return Color(red: 0.290, green: 0.878, blue: 0.502)  // #4ade80
        case .purple: return Color(red: 0.655, green: 0.545, blue: 0.980)  // #a78bfa
        case .pink:   return Color(red: 0.957, green: 0.447, blue: 0.714)  // #f472b6
        case .black:  return Color(red: 0.533, green: 0.533, blue: 0.533)  // #888888
        }
    }

    var displayName: String {
        switch self {
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .purple: return "Purple"
        case .pink:   return "Pink"
        case .black:  return "Black"
        }
    }

    /// Read current theme from UserDefaults
    static var current: PlayerTheme {
        let raw = UserDefaults.standard.string(forKey: "playerTheme") ?? "blue"
        return PlayerTheme(rawValue: raw) ?? .blue
    }
}

/// Observable theme manager — views observe `accent` to re-render on change.
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var accent: Color = PlayerTheme.current.accent
    @Published var themeName: String = PlayerTheme.current.displayName

    func cycle() {
        let all = PlayerTheme.allCases
        if let idx = all.firstIndex(of: PlayerTheme.current) {
            let next = all[(idx + 1) % all.count]
            UserDefaults.standard.set(next.rawValue, forKey: "playerTheme")
            accent = next.accent
            themeName = next.displayName
        }
    }
}
