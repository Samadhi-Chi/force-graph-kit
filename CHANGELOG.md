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

### v0.2 scene / RealityKit baseline
- Added reversible axis mapping and Core-backed volume fit, revisioned frames, update reheating policies, and a cooling-aware newest-frame scheduler.
- Added configurable label visibility and host label factories, complete node/link highlight styling, and reusable directional cones.
- Reworked RealityKit synchronization around stable typed lookup, shared unit meshes, transform-only edge updates, stale-frame rejection, and bounded pools.
- Added conditional RealityKit tests and a standalone visionOS 2 volumetric sample package.

### Fixed after adversarial v0.2 review
- Kept cooled scheduler streams installed and resumable without polling; added explicit scheduler scene updates, lifecycle state, cancellation cleanup, and single-loop restart behavior.
- Clarified that only stop, consumer termination, or subscription replacement tears down the stream, and documented host lifecycle cleanup.
- Added explicit RealityKit producer-session reset, immediate pool trimming, configuration invalidation, label descendant identity cleanup, and root-space collision shapes that avoid radius double scaling.
