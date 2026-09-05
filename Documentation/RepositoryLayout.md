# Repository Layout

## Directory responsibilities

- `Sources/ForceGraphCore/` contains the dependency-free Linux-compatible model, forces,
  simulation, spatial index, utilities, and the Core DocC catalog.
- `Sources/ForceGraphScene/` contains UI-neutral scene models, coordinates, controller, and
  scheduling runtime.
- `Sources/ForceGraphRealityKit/` contains the optional, availability-guarded Apple adapter.
- `Tests/` mirrors the three library modules. Apple-only tests remain conditionally compiled.
- `Examples/CLI/` is the source of the `force-graph-demo` executable. `Examples/visionOS/` is a
  standalone visionOS sample package; `Examples/Data/` and `Examples/WikiAdapter/` are integration
  fixtures and adapter examples.
- `Benchmarks/ForceGraphBenchmark/` is the source of the `force-graph-benchmark` executable.
- `Documentation/` contains topic guides; `.github/` contains community policy and CI files;
  `Scripts/` contains dependency-free repository validation entry points.

The module grouping is deliberately shallow. Moving files did not split declarations or change
Swift module boundaries; SwiftPM target paths preserve the existing product and command names.

## Legacy path mapping

| Previous path | Current path |
|---|---|
| `GETTING_STARTED.md` | `Documentation/GettingStarted.md` |
| `ARCHITECTURE.md` | `Documentation/Architecture.md` |
| `D3_COMPATIBILITY.md` | `Documentation/D3Compatibility.md` |
| `FEATURE_MATRIX.md` | `Documentation/FeatureMatrix.md` |
| `REALITYKIT_INTEGRATION.md` | `Documentation/RealityKitIntegration.md` |
| `PERFORMANCE.md` | `Documentation/Performance.md` |
| `VISIONOS_ACCEPTANCE.md` | `Documentation/VisionOSAcceptance.md` |
| `CONTRIBUTING.md` | `.github/CONTRIBUTING.md` |
| `CODE_OF_CONDUCT.md` | `.github/CODE_OF_CONDUCT.md` |
| `SECURITY.md` | `.github/SECURITY.md` |
| `Sources/ForceGraphDemo/` | `Examples/CLI/` |
| `Sources/ForceGraphBenchmark/` | `Benchmarks/ForceGraphBenchmark/` |

See the [documentation index](README.md) for topic navigation.
