import SwiftUI

/// Button style with press-to-scale animation and spring feedback.
struct PressableButtonStyle: ButtonStyle {
    var scaleDown: CGFloat = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleDown : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
