//
//  CallView.swift
//  AudioCallApp
//
//  Created by Shivansh Gaur on 03/04/25.
//

import SwiftUI
import AVFoundation

// MARK: - Call View
struct CallView: View {
    @EnvironmentObject var callManager: CallManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            statusView
        }
        .padding()
        .onAppear {
            // Force speaker mode for outgoing calls
            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        }
        .onChange(of: callManager.callStatus) { newStatus in
            if newStatus == .ended {
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch callManager.callStatus {
        case .outgoing:
            Text("Calling...")
            Button("Cancel") { callManager.endCall() }
        case .incoming(let caller):
            VStack {
                Text("Incoming call from \(caller)")
                Button("Answer") { callManager.answerCall() }
                Button("Decline") { callManager.endCall() }
            }
        case .active:
            Text("Connected")
            HStack(spacing: 40) {
                Button(action: callManager.toggleMute) {
                    Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.largeTitle)
                }
                Button(action: callManager.endCall) {
                    Image(systemName: "phone.down.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                }
            }
        case .ended:
            Text("Call Ended")
        default:
            Text("")
        }
    }
}

#Preview {
    CallView()
}
