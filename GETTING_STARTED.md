# Getting Started

In Xcode choose **File > Add Package Dependencies**, enter this repository URL, select a tagged
version when releases exist (or an authorized branch during development), and add
`ForceGraphCore` and optionally `ForceGraphScene`. `ForceGraphRealityKit` is only meaningful in
an Apple app target with RealityKit.

```swift
import ForceGraphCore

var layout = ForceSimulation(nodes: (0..<100).map { ForceNode(id: $0) }, dimensions: .three)
layout.force("charge", .manyBody(strength: -20,
    algorithm: .barnesHut(theta: 0.9, directThreshold: 32)))
layout.tick(iterations: 100)
let frame = layout.snapshots()
```

Stable IDs are the ownership boundary. Use graph deltas or scene updates rather than rebuilding
IDs. Own mutable simulations/controllers in one actor. Set fixed coordinates and reheat alpha
while dragging. See `Examples/WikiAdapter` and `Examples/visionOS` for integration shapes.

Cached force providers are revision-based: construct them with the nodes or links whose metadata
they read, and recreate that force when the relevant metadata changes. Use `validateGraph` or
`ForceGraphScene.diagnostics()` before applying external graph data; controllers deterministically
retain the first duplicate identity and omit unresolved and self-referential links.
