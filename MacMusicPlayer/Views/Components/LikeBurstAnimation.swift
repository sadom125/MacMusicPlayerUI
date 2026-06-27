import SwiftUI

/// A bigger, flashy particle burst — pure visual delight, no data state.
/// Trigger it and particles erupt upward in a fan shape with stars + circles.
/// Use `.id(counter)` on this view to force a fresh instance per burst.
struct LikeBurstAnimation: View {
    @State private var particles: [BurstParticle] = []
    @State private var showLikeText: Bool = false

    var body: some View {
        ZStack {
            // "赞！" text that pops up briefly
            if showLikeText {
                Text("赞！")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .yellow.opacity(0.8), radius: 12, x: 0, y: 0)
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }

            // Particles
            ForEach(particles) { particle in
                Group {
                    if particle.isStar {
                        Image(systemName: "star.fill")
                            .font(.system(size: particle.size * 1.8))
                            .foregroundColor(particle.color.opacity(particle.opacity))
                    } else {
                        Circle()
                            .fill(particle.color.opacity(particle.opacity))
                            .frame(width: particle.size, height: particle.size)
                    }
                }
                .offset(x: particle.x, y: particle.y)
                .scaleEffect(particle.scale)
                .rotationEffect(.degrees(particle.rotation))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            triggerBurst()
        }
    }

    private func triggerBurst() {
        let count = 20
        var newParticles: [BurstParticle] = []

        for i in 0..<count {
            let baseAngle = -(.pi / 3) + (CGFloat(i) / CGFloat(count - 1)) * (.pi * 2 / 3)
            let angle = baseAngle + CGFloat.random(in: -0.15...0.15)

            let burstColors: [Color] = [
                .yellow,
                .orange,
                Color(red: 1, green: 0.85, blue: 0.3),
                .white,
                Color(red: 1, green: 0.7, blue: 0.2),
                .yellow.opacity(0.9),
                Color(red: 1, green: 0.9, blue: 0.5),
            ]

            newParticles.append(BurstParticle(
                id: UUID(),
                color: burstColors.randomElement() ?? .yellow,
                size: CGFloat.random(in: 4...12),
                isStar: i % 3 == 0,
                x: 0, y: 0,
                targetX: cos(angle) * CGFloat.random(in: 50...140),
                targetY: sin(angle) * CGFloat.random(in: 50...140) - CGFloat.random(in: 10...30),
                opacity: 1.0,
                scale: CGFloat.random(in: 0.8...1.5),
                rotation: CGFloat.random(in: 0...360)
            ))
        }

        particles = newParticles

        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            showLikeText = true
        }

        withAnimation(.easeOut(duration: 0.7)) {
            for i in particles.indices {
                particles[i].x = particles[i].targetX
                particles[i].y = particles[i].targetY
                particles[i].opacity = 0
                particles[i].scale = CGFloat.random(in: 0.1...0.4)
                particles[i].rotation += CGFloat.random(in: 180...540)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            particles = []
            withAnimation(.easeOut(duration: 0.15)) {
                showLikeText = false
            }
        }
    }
}

private struct BurstParticle: Identifiable {
    let id: UUID
    let color: Color
    let size: CGFloat
    let isStar: Bool
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    var opacity: Double
    var scale: CGFloat
    var rotation: CGFloat
}
