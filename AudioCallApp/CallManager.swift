//
//  CallManager.swift
//  AudioCallApp
//
//  Created by Shivansh Gaur on 03/04/25.
//

import Foundation
import WebRTC
import FirebaseFirestore
import Combine

// MARK: - Call Status
enum CallStatus: Equatable {
    case idle
    case outgoing
    case incoming(caller: String)
    case active
    case ended
}

class CallManager: NSObject, ObservableObject {
    @Published var callStatus: CallStatus = .idle
    @Published var isMuted = false
    @Published var localCandidateCount = 0
    @Published var remoteCandidateCount = 0
    
    private var peerConnection: RTCPeerConnection?
    private var peerConnectionFactory: RTCPeerConnectionFactory
    private var localAudioTrack: RTCAudioTrack?
    private var listener: ListenerRegistration?
    private var currentCallId: String?
    private var iceCandidateHandlers: [(RTCIceCandidate) -> Void] = []
    private var isCaller = false
    
    private let db = Firestore.firestore()
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
    ]
    
    override init() {
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        super.init()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setCategory(.playAndRecord, with: [.duckOthers, .defaultToSpeaker])
            try session.setMode(AVAudioSession.Mode(rawValue: AVAudioSession.Mode.voiceChat.rawValue))
            try session.setActive(true)
        } catch {
            print("Audio session configuration error: \(error)")
        }
        session.unlockForConfiguration()
    }
    
    // MARK: - Outgoing Call
    func startCall(callee: String, caller: String) {
        self.isCaller = true
        print("Started New Outgoing Call")
        self.currentCallId = UUID().uuidString
        print("Setting up peer connection for incoming call...")
        self.setupPeerConnection()
        print("Creating offer for outgoing call")
        self.createOffer(callee: callee, caller: caller)
    }
    
    private func setupPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [:],
            optionalConstraints: nil
        )
        
        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        
        // Add ICE candidate handler
        iceCandidateHandlers.append { [weak self] candidate in
            self?.sendIceCandidate(candidate: candidate)
        }
        
        createLocalAudioTrack()
    }
    
    private func sendIceCandidate(candidate: RTCIceCandidate) {
        guard let callId = currentCallId else { return }
        let candidateType = isCaller ? "localCandidates" : "remoteCandidates"
        print("Sending ICE Candidate to firestore as: \(candidateType)")
        db.collection("calls")
            .document(callId)
            .collection(candidateType)
            .addDocument(data: [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid ?? ""
            ])
    }
    
    private func createLocalAudioTrack() {
        print("Creating local audio track")
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = peerConnectionFactory.audioSource(with: audioConstrains)
        localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        
        if let audioTrack = localAudioTrack {
            peerConnection?.add(audioTrack, streamIds: ["stream0"])
        }
    }
    
    private func createOffer(callee: String, caller: String) {
        print("Creating offer for call")
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else { return }
            
            let modifiedSdp = sdp.sdp.replacingOccurrences(
                of: "a=setup:passive",
                with: "a=setup:actpass"
            )
            
            print("Offer Created for call with change in 'passive' -> 'actpass'")
            
            let offerSdp = RTCSessionDescription(type: .offer, sdp: modifiedSdp)
            
            self.peerConnection?.setLocalDescription(offerSdp) { error in
                if let error = error {
                    print("Error setting local description: \(error)")
                    return
                }
                print("Offer Set Successfully for call with change in 'passive' -> 'actpass'")
                // Save to Firestore
                self.db.collection("calls").document(self.currentCallId!).setData([
                    "offer": modifiedSdp,
                    "status": "ringing",
                    "caller_id": caller,
                    "receiver_id": callee,
                    "timestamp": FieldValue.serverTimestamp()
                ])
                print("Offer Sent Successfully for call To firestore 'passive' -> 'actpass'")
                self.listenForAnswer()
                self.listenForRemoteIceCandidates()
            }
        }
    }
    
    private func listenForAnswer() {
        print("Started Listening for answer")
        guard let callId = currentCallId else { return }
        print("Found answer for current callID")
        db.collection("calls").document(callId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self,
                      let data = snapshot?.data(),
                      let answerSdp = data["answer"] as? String else { return }
                
                let answer = RTCSessionDescription(type: .answer, sdp: answerSdp)
                self.peerConnection?.setRemoteDescription(answer) { error in
                    if let error = error {
                        print("Error setting remote description: \(error)")
                    }
                    print("Call Answer Set successfully")
                    print("Hopefully Call is Connected")
                }
            }
    }
    
    // MARK: - Incoming Call Handling
    func listenForIncomingCalls(userId: String) {
        print("Started Listening for incoming call...")
        listener = db.collection("calls")
            .whereField("receiver_id", isEqualTo: userId)
            .whereField("status", isEqualTo: "ringing")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let document = snapshot?.documents.first,
                      document.exists else { return }
                
                self.currentCallId = document.documentID
                let data = document.data()
                self.handleIncomingCall(data: data)
            }
    }
    
    private func handleIncomingCall(data: [String: Any]) {
        self.isCaller = false
        guard let offerSdp = data["offer"] as? String,
              let callerId = data["caller_id"] as? String else { return }
        print("Found incoming call")
        callStatus = .incoming(caller: callerId)
        print("Setting up peer connection for incoming call...")
        setupPeerConnection()
        
        let offer = RTCSessionDescription(type: .offer, sdp: offerSdp)
        peerConnection?.setRemoteDescription(offer) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("Error setting remote description: \(error)")
                return
            }
            print("Offer Set for incoming call...")
            self.createAnswer()
            print("Listening For Remote ICE Candidate")
            self.listenForRemoteIceCandidates()
        }
    }
    
    private func createAnswer() {
        print("Creating answer for incoming call...")
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else { return }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                // This completion handler is called on WebRTC's background thread
                if let error = error {
                    print("Error setting local description: \(error)")
                    return
                }
                
                // Firestore operations can stay on background thread,
                // but UI updates must move to main thread
                DispatchQueue.main.async {
                    // Update Firestore with answer
                    print("Answer Created for incoming call... sending to Firestore")
                    self.db.collection("calls").document(self.currentCallId!).updateData([
                        "answer": sdp.sdp,
                        "status": "accepted"
                    ])
                    
                    self.listenForLocalIceCandidates()
                    print("Call Status set to active")
                    self.callStatus = .active // UI update
                }
            }
        }
    }
    
    // MARK: - ICE Candidate Handling
    private func listenForLocalIceCandidates() {
        print("Listening for Local ICE Candidate")
        iceCandidateHandlers.append { [weak self] (candidate: RTCIceCandidate) in
            self?.sendIceCandidate(candidate: candidate)
        }
    }
    
    private func listenForRemoteIceCandidates() {
        print("Listening for Remote ICE Candidate")
        guard let callId = currentCallId else { return }
        let candidateType = isCaller ? "remoteCandidates" : "localCandidates"
        print("Remote ICE Candidate for call found as: \(candidateType)")
        db.collection("calls")
            .document(callId)
            .collection(candidateType)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let changes = snapshot?.documentChanges else { return }
                
                for change in changes {
                    if change.type == .added {
                        let data = change.document.data()
                        guard let candidate = self.parseIceCandidate(data: data) else { continue }
                        
                        self.peerConnection?.add(candidate) { error in
                            if let error = error {
                                print("Error adding ICE candidate: \(error)")
                            } else {
                                print("Remote ICE Candidate Added for call")
                                DispatchQueue.main.async {
                                    self.remoteCandidateCount += 1
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func parseIceCandidate(data: [String: Any]) -> RTCIceCandidate? {
        print("Started Parsing Remote ICE Candidate One by one...")
        guard let sdp = data["candidate"] as? String,
              let sdpMLineIndex = data["sdpMLineIndex"] as? Int32,
              let sdpMid = data["sdpMid"] as? String else { return nil }
        print("Parsing Remote ICE Candidate One by one...")
        return RTCIceCandidate(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
    }
    
    // MARK: - Call Controls
    func answerCall() {
        print("Call 'ANSWERED'")
        callStatus = .active
    }
    
    func toggleMute() {
        isMuted.toggle()
        print("Call 'MUTED?' - \(isMuted)")
        localAudioTrack?.isEnabled = !isMuted
    }
    
    func endCall() {
        print("Call 'ENDED'")
        DispatchQueue.main.async {
            self.callStatus = .ended
        }
        
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setActive(false)
        } catch {
            print("Audio session deactivation error: \(error)")
        }
        session.unlockForConfiguration()
        
        peerConnection?.close()
        peerConnection = nil
        listener?.remove()
        
        if let callId = currentCallId {
            db.collection("calls").document(callId).delete()
            deleteCallWithCandidates(callId: callId) { error in
                if let error = error {
                    print("Error deleting call and candidates: \(error)")
                } else {
                    print("Call and all candidates deleted successfully.")
                    DispatchQueue.main.async {
                        self.callStatus = .idle
                    }
                }
            }
        }
    }
    
    func deleteCallWithCandidates(callId: String, completion: @escaping (Error?) -> Void) {
        let callDoc = db.collection("calls").document(callId)

        let localCandidatesRef = callDoc.collection("localCandidates")
        let remoteCandidatesRef = callDoc.collection("remoteCandidates")

        let dispatchGroup = DispatchGroup()

        func deleteCollection(_ collection: CollectionReference) {
            dispatchGroup.enter()
            collection.getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for doc in documents {
                        doc.reference.delete()
                    }
                }
                dispatchGroup.leave()
            }
        }

        deleteCollection(localCandidatesRef)
        deleteCollection(remoteCandidatesRef)

        dispatchGroup.notify(queue: .main) {
            callDoc.delete(completion: completion)
        }
    }

}

// MARK: - RTCPeerConnectionDelegate
extension CallManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DispatchQueue.main.async {
            switch newState {
            case .connected:
                self.callStatus = .active
                self.configureAudioSession()
            case .disconnected, .failed, .closed:
                self.endCall()
            default: break
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        for handler in iceCandidateHandlers {
            print("-----TO FIND OUT-----")
            print("What is going on?")
            handler(candidate)
            print("----- END -----")
        }
        DispatchQueue.main.async { [weak self] in
            print("Ice Candidate found: \((self?.localCandidateCount ?? 0) + 1)")
            self?.localCandidateCount += 1
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

