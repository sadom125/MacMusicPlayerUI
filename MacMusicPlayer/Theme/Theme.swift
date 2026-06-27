import SwiftUI
import Combine

/// Theme mode: follow system or force dark/light
enum ThemeMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

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
    @Published var themeMode: ThemeMode = {
        let raw = UserDefaults.standard.string(forKey: "themeMode") ?? "System"
        return ThemeMode(rawValue: raw) ?? .system
    }()
    @Published var isDarkMode: Bool = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Start observing system appearance changes
        startObservingAppearance()

        // Listen for immediate system theme change notification
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Initial check
        checkSystemAppearance()
    }

    @objc private func systemThemeChanged() {
        // Immediate check when system theme changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.checkSystemAppearance()
        }
    }

    deinit {
    }

    /// Current effective color scheme based on theme mode
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil  // Follow system
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func startObservingAppearance() {
        // DistributedNotificationCenter handles AppleInterfaceThemeChangedNotification
    }

    private func checkSystemAppearance() {
        // Check via UserDefaults (updates instantly on theme change)
        let interfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? ""
        let systemIsDarkViaDefaults = interfaceStyle.lowercased() == "dark"

        // Also check via NSApp (may have slight delay)
        let systemIsDarkViaApp = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Use whichever says dark (prioritize the faster one)
        let systemIsDark = systemIsDarkViaDefaults || systemIsDarkViaApp

        let newIsDarkMode: Bool
        switch themeMode {
        case .system:
            newIsDarkMode = systemIsDark
        case .light:
            newIsDarkMode = false
        case .dark:
            newIsDarkMode = true
        }

        // Only update if changed — must dispatch to main for @Published to trigger UI
        if isDarkMode != newIsDarkMode {
            DispatchQueue.main.async { [weak self] in
                self?.isDarkMode = newIsDarkMode
                self?.updateWindowAppearance()
            }
        }
    }

    private func updateWindowAppearance() {
        // Update NSApp appearance for title bar text color
        switch themeMode {
        case .system:
            NSApp.appearance = nil  // Follow system
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func cycle() {
        let all = PlayerTheme.allCases
        if let idx = all.firstIndex(of: PlayerTheme.current) {
            let next = all[(idx + 1) % all.count]
            UserDefaults.standard.set(next.rawValue, forKey: "playerTheme")
            accent = next.accent
            themeName = next.displayName
        }
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
        checkSystemAppearance()
    }
}
