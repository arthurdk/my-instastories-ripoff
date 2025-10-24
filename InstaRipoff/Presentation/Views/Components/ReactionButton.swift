//
//  ReactionButton.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct ReactionButton: View {
    let currentReaction: ReactionType?
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 44, height: 44)
                
                if let reaction = currentReaction {
                    Text(reaction.emoji)
                        .font(.system(size: 32))
                } else {
                    // Empty heart outline
                    Image(systemName: "heart")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(isPressed ? 1.3 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    HapticManager.shared.impact(style: .medium)
                    onLongPress()
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPressed = false
                    }
                    onTap()
                }
        )
    }
}
