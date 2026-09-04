# Changelog

## Unreleased

### Added
- Dimension-generic spatial indexing and Barnes-Hut many-body mode with direct fallback.
- Cached per-element force providers, graph diagnostics/deltas, async runner, bounds, and fitting.
- Renderer-neutral ForceGraphScene product and conditionally compiled RealityKit synchronizer source.
- JSON demo, benchmark executable, example data, wiki adapter, documentation, and CI.

### Hardened
- Preserved the baseline many-body source API while adding explicit algorithm selection.
- Added bounded orthant and aggregate invariants, per-dimension approximation fixtures, and
  distance/parameter validation coverage.
- Normalized duplicate scene identities, removed dangling render edges, sanitized visual inputs,
  and made missing interactions safe no-ops.
- Made async runner generations and intent-stream termination deterministic and leak-resistant.
- Added explicit stable-ID node state patches and hardened provider caches for duplicate IDs.
