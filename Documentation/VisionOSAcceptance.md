# visionOS Acceptance Gates

Linux CI does not satisfy these gates. Before claiming Apple support, maintainers must:

- Build all products with Xcode and a visionOS 2-or-newer SDK, including availability checks from
  an app whose deployment target is below the adapter boundary.
- Compile the example inside a volumetric WindowGroup and test a simulator smoke path.
- Verify node tap, selection, details, drag/release/pin, fit/recenter, pause/resume, and 2D/3D mode.
- Confirm labels remain parented and incident edges update during every drag frame.
- Validate collision/InputTarget behavior, Dynamic Type/accessibility strategy, and lifecycle cleanup.
- Profile 100/1,000/5,000-node physics plus entity synchronization on supported hardware.
- Test window/volume restoration and optionally an ImmersiveSpace integration on a real device.

## Current automation boundary

`ForceGraphRealityKitTests` is a real conditional SwiftPM test target. Linux compiles its empty guarded branch and exercises Scene contracts; that does **not** establish Apple compilation. On macOS CI, build/test the target with the configured SDK. Simulator launch, targeted gestures, billboard/attachment behavior, profiling, and device comfort remain explicit gates.

The macOS CI job prints the selected Xcode and visionOS Simulator SDK versions, runs the root
release build/tests, and invokes an unsigned `xcodebuild` of the standalone sample against
`xrsimulator`. A missing SDK or sample type error fails that job rather than being treated as a
pass. This compile gate still does not constitute a simulator launch or device validation.

The Linux suite now exercises scheduler dormancy/wake/cancellation deterministically. Acceptance must also confirm that view/task teardown stops the scheduler or cancels stream consumption; cooling alone intentionally retains a dormant, resumable subscription. Apple-only tests cover stale-frame rejection, explicit producer-session changes, and recycled identity cleanup when compiled with a supported SDK. Collision shape/model-scale parity and targeted hits on root/model/label/arrow descendants still require simulator/device inspection; conditional source presence is not an Apple compilation claim.
