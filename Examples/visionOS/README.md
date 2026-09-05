# visionOS Volumetric Sample

This directory is a standalone SwiftPM executable package depending on the repository root. Open
`Package.swift` in an Xcode version with the visionOS 2 SDK, then build the
`ForceGraphVisionSample` scheme. The single maintained rendering view is
`Sources/ForceGraphVisionSample/ForceGraphVolumeExample.swift`; `ForceGraphVisionSampleApp.swift` only supplies sample
data and the volumetric app entry point. `HostInteractionCallbacks.swift` retains the host gesture
forwarding hooks without claiming unverified targeted-gesture APIs. Those callbacks wake the scene
scheduler after selection or drag changes so a cooled layout publishes the resulting frame.

Manifest-only validation from the repository root:

```sh
(cd Examples/visionOS && swift package dump-package)
```

The macOS CI compile gate uses:

```sh
xcodebuild -scheme ForceGraphVisionSample -configuration Release -sdk xrsimulator \
  -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Linux cannot compile or run the guarded SwiftUI/RealityKit implementation. Simulator launch,
targeted gestures, accessibility, profiling, and device behavior remain the gates in
[visionOS acceptance](../../Documentation/VisionOSAcceptance.md).
