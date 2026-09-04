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
