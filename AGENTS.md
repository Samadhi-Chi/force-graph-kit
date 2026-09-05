# Repository Agent Guide

- Preserve a dependency-free, renderer-independent Linux core.
- Use Swift 6 and add doc comments to public APIs.
- Keep deterministic behavior and stable-ID endpoint resolution covered by tests.
- Do not claim Apple SDK, RealityKit, device, or D3 numerical validation unless it was run.
- Run release build and tests before proposing changes.
- Keep ForceGraphScene UI-neutral and all Apple code behind platform/import guards.
- Benchmark spatial changes without adding timing assertions to unit tests.
- Keep topic guides under `Documentation/`, community policy under `.github/`, CLI examples under
  `Examples/`, and benchmark sources under `Benchmarks/`; preserve root SwiftPM product commands.
- Run `python3 Scripts/validate-markdown-links.py --self-test` after moving Markdown files.
