//
//  AnimatedAvatarView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct AnimatedAvatarView: View {
    let user: User
    let hasUnseenStories: Bool
    let isRecent: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    private let unseenGradient = LinearGradient(
        colors: [
            Color(red: 0.51, green: 0.20, blue: 0.89), // Purple
            Color(red: 0.89, green: 0.20, blue: 0.51), // Pink
            Color(red: 0.89, green: 0.51, blue: 0.20)  // Orange
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let recentGlow = RadialGradient(
        colors: [
            Color.purple.opacity(0.6),
            Color.pink.opacity(0.4),
            Color.clear
        ],
        center: .center,
        startRadius: 30,
        endRadius: 50
    )
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Glow effect for recent stories
                if isRecent && hasUnseenStories {
                    Circle()
                        .fill(recentGlow)
                        .frame(width: 100, height: 100)
                        .opacity(glowOpacity)
                }
                
                // Ring (gradient for unseen, gray for seen)
                if hasUnseenStories {
                    Circle()
                        .strokeBorder(unseenGradient, lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                } else {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }
                
                // Profile Image
                AsyncImage(url: URL(string: user.profilePictureUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 74, height: 74)
                .clipShape(Circle())
            }
            
            Text(user.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 80)
        }
        .onAppear {
            if hasUnseenStories {
                startPulseAnimation()
            }
            if isRecent {
                startGlowAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.05
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 1.0
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AnimatedAvatarView(
            user: User(id: 1, name: "Neo", profilePictureUrl: "https://i.pravatar.cc/300?u=1"),
            hasUnseenStories: true,
            isRecent: true
        )
        
        AnimatedAvatarView(
            user: User(id: 2, name: "Trinity", profilePictureUrl: "https://i.pravatar.cc/300?u=2"),
            hasUnseenStories: true,
            isRecent: false
        )
        
        AnimatedAvatarView(
            user: User(id: 3, name: "Morpheus", profilePictureUrl: "https://i.pravatar.cc/300?u=3"),
            hasUnseenStories: false,
            isRecent: false
        )
    }
    .padding()
}
