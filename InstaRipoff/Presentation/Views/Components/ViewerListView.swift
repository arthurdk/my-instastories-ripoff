//
//  ViewerListView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct ViewerListView: View {
    let viewerIds: [Int]
    let users: [User]
    
    var viewers: [User] {
        users.filter { viewerIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewers) { user in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: user.profilePictureUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            Text(user.name)
                                .font(.system(size: 16))
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Viewers")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
