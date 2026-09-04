# Contributing

Use Swift 6, preserve renderer independence and deterministic tests, document public APIs, and avoid runtime dependencies. Run `swift package dump-package`, `swift build -c release`, and `swift test -c release`. Changes claiming D3 parity need a compact, attributable reference fixture; Apple integration claims need the relevant SDK/device validation. Benchmark changes with representative sizes, but never use unstable wall-clock thresholds in unit tests. Keep `Sendable` correctness and stable identity explicit.
