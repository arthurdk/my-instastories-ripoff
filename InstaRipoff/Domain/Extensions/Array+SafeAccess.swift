//
//  Array+SafeAccess.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
