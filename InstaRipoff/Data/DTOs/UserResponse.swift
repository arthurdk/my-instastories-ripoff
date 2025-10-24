//
//  UserResponse.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

struct UserResponse: Codable {
    let pages: [UserPage]
}

struct UserPage: Codable {
    let users: [User]
}
