# Call Disconnect Remediation

## Problem Description
On iOS devices, incoming VoIP calls answered via the CallKit interface would immediately disconnect. This was caused by a conflict between CallKit and WebRTC over ownership and control of the iOS `AVAudioSession`. 

Without manual coordination, both WebRTC and the native CallKit CXProvider tried to activate/configure the audio session independently. The iOS system detected this conflict as an unauthorized configuration attempt outside of the CallKit lifecycle, throwing `OSStatus` error `561017449` (`insufficientPriority`) and terminating the audio path, causing the WebRTC call to disconnect immediately.

## Remediation Strategy
We integrated WebRTC's audio session handling directly with CallKit's lifecycle callbacks inside `CallManager.swift` by:
1. Enabling manual audio handling: Configured `RTCAudioSession.sharedInstance().useManualAudio = true` and initialized `isAudioEnabled = false` in `CallManager.init()`.
2. Setting category and mode: Configured category `.playAndRecord` and mode `.voiceChat` via `RTCAudioSessionConfiguration` in `setupAudioSession()`, without manually activating the session.
3. Hooking into CallKit delegates:
   - In `provider(_:didActivate:)`, we forwarded the activation event to WebRTC (`rtcSession.audioSessionDidActivate(audioSession)`) and enabled the audio engine (`isAudioEnabled = true`).
   - In `provider(_:didDeactivate:)`, we forwarded the deactivation event to WebRTC (`rtcSession.audioSessionDidDeactivate(audioSession)`) and disabled the audio engine (`isAudioEnabled = false`).

This ensures WebRTC only attempts to capture the microphone and play audio when the iOS system has officially granted CallKit audio priority.

## File Changes

### [CallManager.swift](file:///Users/jatin-99pandit/Documents/projects/GetgabsApk/ios/Runner/CallManager.swift)
- Imported `WebRTC`.
- Initialized WebRTC manual audio options in `init()`.
- Implemented `provider(_:didDeactivate:)` to handle deactivation.
- Updated `provider(_:didActivate:)` to pass the active session to WebRTC.
- Refactored `setupAudioSession()` to configuration lock and setup configuration using `RTCAudioSessionConfiguration`.
