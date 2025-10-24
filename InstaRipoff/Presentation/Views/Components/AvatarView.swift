//
//  AvatarView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct AvatarView: View {
    let user: User
    let hasUnseenStories: Bool
    
    private let unseenGradient = LinearGradient(
        colors: [
            Color(red: 0.51, green: 0.20, blue: 0.89), // Purple
            Color(red: 0.89, green: 0.20, blue: 0.51), // Pink
            Color(red: 0.89, green: 0.51, blue: 0.20)  // Orange
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Ring (gradient for unseen, gray for seen)
                if hasUnseenStories {
                    Circle()
                        .strokeBorder(unseenGradient, lineWidth: 3)
                        .frame(width: 80, height: 80)
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
    }
}
