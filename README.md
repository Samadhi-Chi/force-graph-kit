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
Many-body defaults to a deterministic Barnes-Hut orthant tree and retains an explicit O(n²)
direct reference mode. Constant-radius collision remains O(n²); cached per-node-radius
collision uses the spatial index as a broad phase. Benchmark your actual graph and force mix.

Linux validates ForceGraphCore, ForceGraphScene, the demo, and benchmark. RealityKit entity
synchronization source is now isolated in an Apple-only conditional target, but no RealityKit,
visionOS, Xcode, compositor, gesture, simulator, or device validation has occurred.

## Dragging

On drag start, set the node's `fx`/`fy`/`fz`, set `alphaTarget` (for example `0.3`), and call `restart()`. Update fixed coordinates as the gesture moves and tick continuously so neighboring nodes respond. On end, set the desired fixed axes to `nil`, set `alphaTarget = 0`, and continue ticking to cool; retain them to pin the node.

## Safety

Non-finite initial positions are initialized deterministically and non-finite velocities are zeroed. Coincident pairs receive seeded microscopic jiggle. Invalid force parameters disable the affected force; simulation decay parameters are clamped. Non-finite integration output is reset to zero rather than contaminating the graph.

## Milestone roadmap

1. **Core parity:** broaden upstream reference fixtures and refine accessor cache lifecycle.
2. **Spatial performance:** optimize and benchmark tree construction, nearest search, and
   constant-radius collision while retaining direct reference paths.
3. **RealityKit adapter:** validate and harden the conditional entity synchronizer and add
   host-app gesture coordinate conversion.
4. **visionOS acceptance:** validate Xcode builds, simulator behavior, frame pacing,
   gestures, and final interaction quality on real hardware.

## Development

```sh
swift build -c release
swift test -c release
```

## Products

- **ForceGraphCore** — deterministic layout, direct/Barnes-Hut charge, cached providers,
  spatial queries, graph deltas, async frames, bounds, and volume fitting.
- **ForceGraphScene** — stable visual identity, labels, visibility, selection/highlighting,
  filtering, interaction intents, synchronized edge endpoints, and drag lifecycle.
- **ForceGraphRealityKit** — conditionally compiled Apple entity synchronization source;
  unverified on Linux and not yet accepted for Apple release.
- **force-graph-demo / force-graph-benchmark** — Linux-compatible JSON smoke output and
  timing diagnostics.

See [Getting Started](GETTING_STARTED.md), [Performance](PERFORMANCE.md),
[feature coverage](FEATURE_MATRIX.md), [RealityKit integration](REALITYKIT_INTEGRATION.md), and
[visionOS acceptance gates](VISIONOS_ACCEPTANCE.md). A Chinese overview is available in
[README.zh-CN.md](README.zh-CN.md).

## v0.2 Scene and RealityKit baseline

`GraphCoordinateSpace` maps 1D/2D/3D layouts through XYZ, XY, XZ, or YZ conventions, supports Core-backed volume fitting, and reverses renderer drag positions. Scene frames expose topology/visual revisions and scheduling state. `ForceGraphSceneScheduler` uses newest-frame backpressure and prevents duplicate loops. Cooling stops only its tick loop: the same stream remains dormant until `resume`, `restart`, or a mechanical scene update wakes it. `stop`, consumer termination, or replacement by `start` tears down the subscription. Stop the scheduler or cancel consumption when the owning view/task ends.

RealityKit synchronization uses stable entities and shared unit meshes, typed node/link lookup, stale-frame rejection, bounded pools, selective host-created labels, highlight materials, and optional straight-link direction cones. See the standalone `Examples/visionOS` package. These Apple-conditional APIs have not been compiled or run in this Linux environment.
