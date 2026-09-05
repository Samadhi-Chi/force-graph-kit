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

Consume `ForceGraphSceneScheduler.start()` for frame delivery. Cooling leaves that same stream
dormant without a polling task, and drag, restart, or a mechanical scene update wakes it. When the
owning view or task ends, call `stop()` or cancel the consuming task; consumer termination, explicit
stop, and replacement by a later `start()` are the subscription teardown paths.

The synchronizer source is implemented but unverified in this Linux milestone. Availability
signatures, materials, text meshes, collision/input behavior, gesture coordinate conversion, edge
orientation, accessibility, and entity-pool lifecycle require Xcode validation before release.
The example deliberately exposes host-controller callback points instead of speculative gesture
code. No Apple compilation or execution is claimed.

`../Examples/visionOS/Sources/ForceGraphVisionSample/HostInteractionCallbacks.swift` provides compile-oriented tap, details,
drag-begin/change/end, and fit forwarding to `ForceGraphController`. The host app supplies only the
Apple-SDK-specific targeted gesture and coordinate conversion after validating those APIs in Xcode.

## v0.2 contract

Construct the synchronizer with a `GraphCoordinateSpace`; use `graphPosition(for:)` before forwarding a drag to the controller. `entity(forNode:)`, `entity(forLink:)`, and `element(for:)` provide typed bidirectional lookup without string conversion. The adapter ignores stale sequences, reuses stable entities and unit meshes, bounds both pools with `poolCapacity`, and applies material/collision changes only when visual state changes. Directional links add a reusable cone.

Labels default to none at Scene level. Select `.all`, `.top(_:)`, or `.selectedAndNeighbors`, and provide `labelEntityFactory` for text, attachments, or application-specific accessibility. Host code owns billboard behavior; the adapter does not assume a camera. The standalone `Examples/visionOS` Swift package is the minimal volumetric Xcode build entry point.

## Sessions, scale, and invalidation

A synchronizer accepts monotonically increasing sequences from one producer session. Call `beginSession()` before switching controllers or any producer whose sequence restarts; call `reset()` to additionally discard all active entities, typed mappings, and pools. Older frames within a session remain rejected after configuration changes. Changing `coordinateSpace` invalidates transforms, materials, and collision sizing and permits only the same latest frame to be reapplied. Changing `labelEntityFactory` removes existing labels and likewise permits recreation from that latest frame. Lowering `poolCapacity` trims both pools immediately.

`topologyRevision` remains an optional caller hint. The controller independently advances the
effective render revision when visible node/link membership changes, including hide/show and
filtered scenes, so the adapter reconciles ordinary updates even when callers retain the default
revision value. Link endpoints and mechanical parameters are compared independently for automatic
reheating; color-only updates preserve cooling state.

Node models use a unit sphere scaled by `visual.radius * coordinateSpace.scale`. Their collision sphere is attached to the unscaled node root with that same final radius, so visual and hit radii match rather than applying radius twice. Zero or invalid radii use the documented minimum visible/hit radius. `element(for:)` walks ancestors and mappings include roots, models, labels, shafts, and arrowheads; recycling and reset remove those mappings.

Renderer-bound coordinates and sizes are normalized again when consumed. Invalid mutated scales use
the identity scale, non-finite components use zero, and values outside the finite RealityKit float
boundary are clamped before constructing transforms or collision geometry. The documented
`1,000,000` renderer-unit safety ceiling applies after scaling; the graph-unit minimum is applied
before scaling and is not reapplied to ordinary positive renderer sizes, preserving proportional
zoom for both visible and collision geometry.
