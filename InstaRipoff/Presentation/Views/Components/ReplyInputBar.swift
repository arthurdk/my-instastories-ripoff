//
//  ReplyInputBar.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct ReplyInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input
            HStack {
                TextField("Send message", text: $text)
                    .foregroundColor(.white)
                    .tint(.white)
                    .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(25)
            
            // Send button (only visible when text is not empty)
            if !text.isEmpty {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0)) // #007AFF
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
