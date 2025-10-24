//
//  ReactionPicker.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct ReactionPicker: View {
    let onSelect: (ReactionType) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button(action: {
                    onSelect(reaction)
                }) {
                    Text(reaction.emoji)
                        .font(.system(size: 40))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(40)
        .shadow(radius: 20)
        .transition(.scale.combined(with: .opacity))
    }
}
