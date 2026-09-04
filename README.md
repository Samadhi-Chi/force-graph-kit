# ForceGraphKit

ForceGraphKit is a native Swift 6 package for deterministic 1D, 2D, and 3D force-directed layouts. `ForceGraphCore` has no UI or runtime dependencies and builds on Linux.

```swift
import ForceGraphCore

var simulation = ForceSimulation(
  nodes: [ForceNode(id: "a"), ForceNode(id: "b")],
  dimensions: .three,
  seed: 42
)
simulation.replaceLinks([ForceLink(source: "a", target: "b", distance: 40)])
simulation.force("charge", .manyBody(strength: -20))
simulation.tick(iterations: 60)
let frame = simulation.snapshots()
```

## Scope and caveats

Tests cover d3-force-3d's deterministic initial coordinates, default LCG sequence,
alpha cooling, velocity integration, fixed-axis behavior, insertion-ordered forces, and
degree-biased links. See [D3_COMPATIBILITY.md](D3_COMPATIBILITY.md) for precise limits.
Many-body and collision are correctness-first O(n²) implementations, so large graphs
require future spatial indexing.

Linux validates the algorithm only. No RealityKit, visionOS, Xcode, compositor, gesture, or device validation has occurred. A future Apple-only adapter should consume snapshots and own entities, edge meshes, labels, selection, and hit testing.

## Dragging

On drag start, set the node's `fx`/`fy`/`fz`, set `alphaTarget` (for example `0.3`), and call `restart()`. Update fixed coordinates as the gesture moves and tick continuously so neighboring nodes respond. On end, set the desired fixed axes to `nil`, set `alphaTarget = 0`, and continue ticking to cool; retain them to pin the node.

## Safety

Non-finite initial positions are initialized deterministically and non-finite velocities are zeroed. Coincident pairs receive seeded microscopic jiggle. Invalid force parameters disable the affected force; simulation decay parameters are clamped. Non-finite integration output is reset to zero rather than contaminating the graph.

## Milestone roadmap

1. **Core parity:** extend scalar force APIs with tested per-node accessors and a broader
   upstream reference corpus.
2. **Spatial performance:** add tested quadtree/octree acceleration and benchmarks while
   retaining a direct calculation reference path.
3. **RealityKit adapter:** implement an Apple-only entity, edge, label, hit-test, and drag
   integration target.
4. **visionOS acceptance:** validate Xcode builds, simulator behavior, frame pacing,
   gestures, and final interaction quality on real hardware.

## Development

```sh
swift build -c release
swift test -c release
```
