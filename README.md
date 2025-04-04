# WebRTC Audio Call App (POC)

A **proof-of-concept iOS app** built with **SwiftUI**, **WebRTC**, and **Firebase Firestore** for **one-to-one audio calling** using Firestore as the signaling server.

This project demonstrates how to set up peer-to-peer audio calls with minimal setup using Apple's SwiftUI framework and Google's Firebase services.

---

## Features

- 🔁 One-to-one audio calling
- 🔧 Firestore used as signaling mechanism
- 🧠 No need to manually create collections
- ⚙️ Fully functional WebRTC connection flow
- 👤 Simulated "UserA" and "UserB" calling interface

---

## Getting Started

To run this project on your system:

### 1. Firebase Setup

1. Create a **free Firebase project** at [console.firebase.google.com](https://console.firebase.google.com/).
2. Register an iOS app inside Firebase:
   - **Bundle Identifier**: `com.shivansh.AudioCallApp` (or your own)
3. Download the `GoogleService-Info.plist` and add it to your Xcode project.
4. Enable **Cloud Firestore** in test mode with your preferred region (recommended: one close to your location).
   > ✅ You do **not** need to manually create any Firestore collections. The app handles that automatically when initiating or receiving calls.

---

### 2. 📦 Dependencies (via Swift Package Manager)

Add the following packages in **Xcode > File > Add Packages**:

- **Firebase Firestore**

``` swift
https://github.com/firebase/firebase-ios-sdk
```

- **WebRTC for iOS**
``` swift
https://github.com/stasel/WebRTC.git
```

---

### 3. 🧪 Running the App

You need **two devices** to test the calling flow:

- A **physical iOS device**
- A **simulator**

Steps:

1. On **Device 1** (e.g., iPhone), launch the app and choose **UserA** from the dropdown.
2. On **Device 2** (e.g., Simulator), launch the app and choose **UserB**.
3. On the home screen, each user will see only the opposite user listed.
4. Tap the visible user to initiate a call.
5. Grant microphone access when prompted.

> ℹ️ **Note:** If you select "UserA" on one device, select "UserB" on the other. The call will only connect if the users are different.

---

## 🧰 Project Structure

- `UsernameEntryView`: Dropdown to choose between `UserA` and `UserB`.
- `UserListView`: Displays the list of available users (only one in test mode).
- `CallManager`: Handles signaling via Firestore and also manages peer connection, media, ICE candidates, and audio stream.

---

## 📌 Limitations

- Only supports **1:1 audio calling** (no group calling yet)
- No video call integration
- No production-level call state management

---

## 🛠️ Future Improvements

- ✅ Add support for call rejection and timeout
- 🎥 Enable video calling
- 🧪 Add unit and integration tests
- 🔐 Secure signaling flow with Firestore security rules
- 📲 Push Notifications for background call alerts

---

## 👨‍💻 Author

**Shivansh Gaur**  
iOS Developer  
📧 [shivanshgaur96@gmail.com](mailto:shivanshgaur96@gmail.com)

---

## 📄 License

This project is provided for **educational and testing purposes only**. Not intended for production use.

---
