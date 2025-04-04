//
//  UserListView.swift
//  AudioCallApp
//
//  Created by Shivansh Gaur on 03/04/25.
//

import SwiftUI


// MARK: - User List View
struct UserListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var callManager = CallManager()
    @State private var users = ["UserA", "UserB"] // Replace with actual user fetching
    @State private var showCallView = false
    
    var body: some View {
        VStack {
            List(users.filter { $0 != authService.userName }, id: \.self) { user in
                HStack {
                    Text(user)
                    Spacer()
                    Button(action: {
                        callManager.startCall(callee: user, caller: authService.userName)
                        showCallView = true
                    }) {
                        Image(systemName: "phone")
                    }
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { callManager.callStatus != .idle },
                set: { _ in }
            )) {
                CallView()
                    .environmentObject(callManager)
            }
        }
        .navigationTitle("Users")
        .onAppear {
            callManager.listenForIncomingCalls(userId: authService.userName)
        }
    }
}

#Preview {
    UserListView()
}
