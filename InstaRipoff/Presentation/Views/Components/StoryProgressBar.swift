//
//  StoryProgressBar.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct StoryProgressBar: View {
    let segmentCount: Int
    let currentIndex: Int
    let progress: Double
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                        
                        // Progress
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progressForSegment(index))
                    }
                }
                .frame(height: 2)
                .cornerRadius(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private func progressForSegment(_ index: Int) -> Double {
        if index < currentIndex { return 1.0 }
        if index == currentIndex { return progress }
        return 0.0
    }
}
