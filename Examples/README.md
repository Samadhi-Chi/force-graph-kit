# Examples

- `CLI/` supplies the root-package `force-graph-demo` product. Run it from the repository root with
  `swift run -c release force-graph-demo`; it emits deterministic JSON.
- `Data/knowledge-graph.json` is a small test fixture resolved from test source location rather than
  the process working directory.
- `WikiAdapter/` demonstrates converting generic linked records into a `ForceGraphScene`.
- `visionOS/` is a standalone SwiftPM sample; see its [README](visionOS/README.md).

The CLI, data, and adapter examples are Linux-compatible. The visionOS source requires Xcode with a
visionOS 2 SDK. Its presence and manifest validation do not claim simulator or device acceptance.
