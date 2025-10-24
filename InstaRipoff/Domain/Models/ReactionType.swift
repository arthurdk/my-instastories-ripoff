//
//  ReactionType.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

enum ReactionType: String, CaseIterable, Codable {
    case fire
    case heart
    case laugh
    case wow
    case sad
    
    var systemImage: String {
        switch self {
        case .fire: return "flame.fill"
        case .heart: return "heart.fill"
        case .laugh: return "face.smiling"
        case .wow: return "eyes"
        case .sad: return "hand.thumbsdown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fire, .heart: return .red
        case .laugh: return .yellow
        case .wow, .sad: return .blue
        }
    }
}
