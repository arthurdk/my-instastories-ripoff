//
//  StoryDataSource.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

protocol StoryDataSource {
    func fetchUsers() async throws -> [User]
    func fetchStories(for userId: Int) async throws -> [Story]
}
