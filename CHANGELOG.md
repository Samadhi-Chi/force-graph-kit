# Changelog

## Unreleased

### Changed
- Reorganized topic documentation, executable sources, library source groups, policies, and the
  visionOS sample without changing products, module APIs, platform minimums, or runtime behavior.
- Added offline Markdown-link validation to the existing Linux/macOS CI matrix.
- Added generation checks after scheduler suspension points, repaired Apple-only test type
  inference, and configured unsigned visionOS sample compilation in macOS CI.
- Made the visionOS sample declare its direct Core dependency and route host interactions through
  scheduler wake-up before rendering subsequent frames.

### Added
- Dimension-generic spatial indexing and Barnes-Hut many-body mode with direct fallback.
- Cached per-element force providers, graph diagnostics/deltas, async runner, bounds, and fitting.
- Renderer-neutral ForceGraphScene product and conditionally compiled RealityKit synchronizer source.
- JSON demo, benchmark executable, example data, wiki adapter, documentation, and CI.

### Hardened
- Detect same-revision scene membership and mechanical changes, retain stale-frame rejection across
  renderer configuration updates, normalize mutable renderer inputs, and guard fit padding/bounds.
- Preserve original node offsets when Barnes–Hut filters invalid active-axis positions.
- Preserve proportional node and edge sizes when a valid coordinate scale shrinks graph geometry;
  graph-unit minimums are applied once before scaling.
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
