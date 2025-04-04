//
//  AudioCallAppApp.swift
//  AudioCallApp
//
//  Created by Shivansh Gaur on 03/04/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct AudioCallAppApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if authService.userName.isEmpty {
                    UsernameEntryView()
                } else {
                    UserListView()
                }
            }
            .environmentObject(authService)
        }
    }
}

// MARK: - Auth Service
class AuthService: ObservableObject {
    @Published var userName: String = ""
    private let userDefaults = UserDefaults.standard
    private let userNameKey = "userName"
    
    init() {
        userName = userDefaults.string(forKey: userNameKey) ?? ""
    }
    
    func setUserName(_ name: String) {
        userName = name
        userDefaults.set(name, forKey: userNameKey)
    }
}

// MARK: - Username Entry View
struct UsernameEntryView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedUsername = "UserA"
    private let availableUsers = ["UserA", "UserB"]
    
    var body: some View {
        VStack(spacing: 30) {
            VStack {
                Text("Select Your User")
                    .font(.headline)
                    .padding(.bottom, 10)
                
                Picker("Choose a user", selection: $selectedUsername) {
                    ForEach(availableUsers, id: \.self) { user in
                        Text(user).tag(user)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            
            Button(action: saveUsername) {
                Text("Confirm Selection")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            Spacer()
            
            Text("Note: If this is the first device and you have selected 'UserA', then on the second device or simulator, make sure to select 'UserB' to initiate and receive the call connection properly. The call will only work when the two users are different.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

        }
        .navigationTitle("User Selection")
        .padding()
    }
    
    private func saveUsername() {
        authService.setUserName(selectedUsername)
    }
}
