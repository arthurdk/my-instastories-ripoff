//
//  User.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let profilePictureUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profilePictureUrl = "profile_picture_url"
    }
}
