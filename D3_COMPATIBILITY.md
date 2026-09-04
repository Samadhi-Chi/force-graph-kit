# D3 Compatibility

| Area | Status | Notes |
|---|---|---|
| Alpha schedule, velocity decay, fixed axes | Reference-tested | Same update ordering and retention convention. |
| Center, axis, radial formulas | Compatible in scope | Constants plus cached per-node axis/radial providers. |
| Link distance/strength/iterations/bias | Compatible in scope | Constants and cached providers; unresolved links are ignored rather than throwing. |
| Default RNG and jiggle | Reference-tested | D3's default-seed 32-bit LCG and `1e-6` jiggle scale. |
| 1D/2D/3D initialization | Reference-tested | Linear, golden-angle phyllotaxis, and irrational-angle spherical placement. |
| Many-body | Implemented/tested | Deterministic Barnes-Hut default plus exact O(n²) reference mode; aggregate traversal is not bit-identical to upstream. |
| Collision | Implemented/tested | Constant-radius O(n²) compatibility path and cached per-node radii with indexed broad phase. |
| Dynamic accessor callbacks | Intentionally different | Strongly typed providers cache at force construction, rather than executing every tick. |
| Barnes-Hut theta/distance approximation | Implemented/tested | Dimension-generic bounded orthant tree; focused direct-vs-approximate tests. |
| Browser timer/event API | Intentionally different | Synchronous ticks and explicit running state suit Swift ownership. |
| Force insertion order/manual tick | Reference-tested | Replacement retains order; remove/re-add appends. |
| Missing links, duplicate IDs, self-links | Intentionally different | Invalid/missing/self links are ignored; duplicate lookup uses the first node rather than throwing. |
| Full numerical parity with d3-force-3d | Unverified | Focused fixtures are tested; a broad cross-runtime corpus remains future work. |

## Extended native scope

The default many-body mode uses a deterministic dimension-generic Barnes-Hut tree above a direct
threshold; `.direct` remains available for reference comparisons. Per-element Swift providers are
cached at force construction rather than invoked each tick. These APIs are semantically inspired by
D3 accessors but are not source compatible. ForceGraphScene implements the renderer/controller roles
of stable visuals, selection, neighborhood highlighting, labels, filtering, drag lifecycle, and
camera-neutral intents. WebGL materials, browser events, camera controls, particles, and JavaScript
accessor behavior are intentionally not reproduced.
