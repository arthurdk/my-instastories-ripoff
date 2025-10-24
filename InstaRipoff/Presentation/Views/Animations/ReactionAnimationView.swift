//
//  ReactionAnimationView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct ReactionParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let startX: CGFloat
    let endX: CGFloat
    let duration: Double
    let delay: Double
    let rotation: Double
    let scale: CGFloat
}

struct ReactionAnimationView: View {
    let reaction: ReactionType
    let startPoint: CGPoint
    @State private var particles: [ReactionParticle] = []
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(particle.emoji)
                    .font(.system(size: 40 * particle.scale))
                    .offset(
                        x: isAnimating ? particle.endX : particle.startX,
                        y: isAnimating ? -400 : 0
                    )
                    .rotationEffect(.degrees(isAnimating ? particle.rotation : 0))
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: particle.duration)
                        .delay(particle.delay),
                        value: isAnimating
                    )
            }
        }
        .position(startPoint)
        .onAppear {
            generateParticles()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = true
            }
        }
    }
    
    private func generateParticles() {
        let particleCount = Int.random(in: 6...8)
        
        for i in 0..<particleCount {
            let particle = ReactionParticle(
                emoji: reaction.emoji,
                startX: CGFloat.random(in: -10...10),
                endX: CGFloat.random(in: -50...50),
                duration: Double.random(in: 2.0...2.5),
                delay: Double(i) * 0.08,
                rotation: Double.random(in: -20...20),
                scale: CGFloat.random(in: 0.8...1.3)
            )
            particles.append(particle)
        }
    }
}

// Extension to ReactionType to get emoji
extension ReactionType {
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .heart: return "❤️"
        case .laugh: return "😂"
        case .wow: return "😮"
        case .sad: return "😢"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ReactionAnimationView(
            reaction: .fire,
            startPoint: CGPoint(x: 300, y: 600)
        )
    }
}
