import SwiftUI

/// Tokyo Night color palette for the Dark Immersion design system.
extension Color {
    static let tnBackground = Color(red: 0.031, green: 0.031, blue: 0.055)   // #08080e
    static let tnSurface   = Color(red: 0.055, green: 0.055, blue: 0.086)   // #0e0e16
    static let tnAccent    = Color(red: 0.376, green: 0.690, blue: 1.0)     // #60b0ff
    static let tnPurple    = Color(red: 0.702, green: 0.533, blue: 1.0)     // #b388ff
    static let tnTextDim   = Color.white.opacity(0.35)
    static let tnText      = Color.white.opacity(0.7)
    static let tnTextBright = Color.white.opacity(0.95)
}
