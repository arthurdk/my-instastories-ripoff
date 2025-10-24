//
//  LoginView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username: String = "sati"
    @State private var password: String = "matrix"
    @State private var isLoading: Bool = false
    @State private var previewUser: User?
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.77, blue: 0.36),
                    Color(red: 0.96, green: 0.40, blue: 0.58),
                    Color(red: 0.51, green: 0.32, blue: 0.86)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("InstaRipoff")
                        .font(.custom("SnellRoundhand-Bold", size: 48))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .padding(.bottom, 40)
                
                // Preview user
                if let user = previewUser {
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: user.profilePictureUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.white.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                        
                        Text("You'll log in as \(user.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Login Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Username", text: $username)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .tint(.blue)
                            .onChange(of: username) { _, _ in
                                updatePreviewUser()
                            }
                        
                        Text("Try: neo, trinity, morpheus, oracle")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 16)
                    }
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .tint(.blue)
                    
                    Button(action: {
                        Task {
                            isLoading = true
                            await authManager.login(username: username, password: password)
                            isLoading = false
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Log In")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(12)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .opacity((isLoading || username.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                }
                .padding(.horizontal, 40)
                
                // Info text
                VStack(spacing: 8) {
                    Text("🔐 Any password works!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Username determines your identity")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            updatePreviewUser()
        }
    }
    
    private func updatePreviewUser() {
        guard !username.isEmpty,
              let url = Bundle.main.url(forResource: "users", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            previewUser = nil
            return
        }
        
        let decoder = JSONDecoder()
        
        guard let response = try? decoder.decode(UserResponse.self, from: data) else {
            previewUser = nil
            return
        }
        
        let allUsers = response.pages.flatMap { $0.users }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // Check if username matches any user name (case-insensitive)
            if let matchedUser = allUsers.first(where: { $0.name.lowercased() == username.lowercased() }) {
                previewUser = matchedUser
            } else {
                // Use stable hash for random but consistent assignment
                let usernameHash = stableHash(for: username)
                let userIndex = usernameHash % allUsers.count
                previewUser = allUsers[userIndex]
            }
        }
    }
    
    private func stableHash(for string: String) -> Int {
        var hash = 5381
        for char in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .foregroundColor(.black)
            .background(Color.white.opacity(0.95))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
