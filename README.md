# ForceGraphKit

ForceGraphKit is a native Swift 6 toolkit for deterministic 1D, 2D, and 3D force-directed graphs.
Its Linux core has no UI, renderer, third-party runtime, or Apple-framework dependency.

## Installation and quick start

Add this package with Swift Package Manager and link `ForceGraphCore`; add `ForceGraphScene` and
`ForceGraphRealityKit` only when their higher-level responsibilities are needed.

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

Stable IDs are the ownership boundary. Keep mutable simulations or controllers with one actor/task
and transfer immutable, `Sendable` snapshots between concurrency domains.

## Products

- **ForceGraphCore** — deterministic simulation, direct/Barnes–Hut charge, collision and link
  forces, spatial queries, graph deltas, async frames, bounds, and volume fitting.
- **ForceGraphScene** — UI-neutral visuals, labels, filtering, selection/highlighting, interaction
  intents, synchronized endpoints, reversible coordinates, drag lifecycle, and scheduling.
- **ForceGraphRealityKit** — optional, conditionally compiled Apple entity synchronization with
  stable typed identity, shared meshes, bounded pools, and host-controlled labels.
- **force-graph-demo / force-graph-benchmark** — Linux-compatible JSON smoke output and diagnostic
  timing, still run from the repository root with `swift run -c release <product>`.

## Capability and validation status

Linux release builds and tests cover Core and Scene behavior, deterministic initialization and
cooling, stable endpoint resolution, spatial algorithms, coordinate mapping, and scheduler
lifecycle. D3 compatibility is semantic and scoped rather than JavaScript source compatibility or
complete numerical parity. Benchmark results are diagnostics, not unit-test thresholds.

RealityKit source and conditional tests are isolated behind platform/import guards. This repository
state does not claim Xcode, Apple SDK, visionOS simulator, gesture, compositor, Instruments, or
device validation. See the acceptance guide before making Apple-platform claims.

The Scene scheduler uses newest-frame backpressure and one tick loop. Cooling stops only that loop;
the stream stays dormant until resume, restart, or a mechanical scene update. Stop the scheduler or
cancel consumption when its host lifecycle ends.

## Development

```sh
swift build -c release
swift test -c release
swift run -c release force-graph-demo
swift run -c release force-graph-benchmark 100 1000 5000
python3 Scripts/validate-markdown-links.py --self-test
```

The Markdown check verifies supported local link targets exist. It ignores external URLs and does
not validate heading anchors.

## Documentation

Start with the [documentation index](Documentation/README.md), then consult
[getting started](Documentation/GettingStarted.md), [architecture](Documentation/Architecture.md),
[D3 compatibility](Documentation/D3Compatibility.md), the [feature matrix](Documentation/FeatureMatrix.md),
[RealityKit integration](Documentation/RealityKitIntegration.md), [performance](Documentation/Performance.md),
and [visionOS acceptance](Documentation/VisionOSAcceptance.md). See [examples](Examples/README.md),
[repository layout](Documentation/RepositoryLayout.md), and the [Chinese README](README.zh-CN.md).
