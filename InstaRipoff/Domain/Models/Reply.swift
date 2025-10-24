//
//  Reply.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

struct Reply: Identifiable, Equatable {
    let id: UUID
    let userId: Int
    let text: String
    let timestamp: Date
}
