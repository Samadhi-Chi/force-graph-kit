# RealityKit Integration

`ForceGraphRealityKit` is conditionally compiled when RealityKit and either UIKit or AppKit can be
imported. Platform color/font aliases keep the synchronization surface shared across Apple targets.
`RealityKitGraphSynchronizer` has one explicit availability boundary—macOS 15, iOS 18, and
visionOS 2—because its input-target and generated-cylinder APIs require that SDK generation. The
lower package platform declarations continue to support ForceGraphCore and ForceGraphScene.
Its synchronizer maintains stable-ID node roots and link entities, pools removals, parents generated
labels to node roots, installs collision/input components, and updates every edge from both endpoint
positions in the same `ForceGraphRenderFrame` used for nodes.

Use a volumetric `WindowGroup` by default. Add the package to an Xcode visionOS target, retain one
`ForceGraphController` and one `RealityKitGraphSynchronizer`, add the synchronizer root to a
`RealityView`, and feed frames on the main actor. Convert targeted gesture positions into the graph's
coordinate space before calling `beginDrag`, `updateDrag`, and `endDrag`. Handle intent events for
selection, details, focus, and fitting in application UI. ImmersiveSpace is optional and outside the
package's ownership.

The synchronizer source is implemented but unverified in this Linux milestone. Availability
signatures, materials, text meshes, collision/input behavior, gesture coordinate conversion, edge
orientation, accessibility, and entity-pool lifecycle require Xcode validation before release.
The example deliberately exposes host-controller callback points instead of speculative gesture
code. No Apple compilation or execution is claimed.

`Examples/visionOS/HostInteractionCallbacks.swift` provides compile-oriented tap, details,
drag-begin/change/end, and fit forwarding to `ForceGraphController`. The host app supplies only the
Apple-SDK-specific targeted gesture and coordinate conversion after validating those APIs in Xcode.
