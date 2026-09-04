# D3 Compatibility

| Area | Status | Notes |
|---|---|---|
| Alpha schedule, velocity decay, fixed axes | Reference-tested | Same update ordering and retention convention. |
| Center, axis, radial formulas | Compatible in scope | Constant parameters rather than per-node accessors. |
| Link distance/strength/iterations/bias | Compatible in scope | Stable-ID endpoints; unresolved links are ignored rather than throwing. |
| Default RNG and jiggle | Reference-tested | D3's default-seed 32-bit LCG and `1e-6` jiggle scale. |
| 1D/2D/3D initialization | Reference-tested | Linear, golden-angle phyllotaxis, and irrational-angle spherical placement. |
| Many-body | Intentionally different | Exact pairwise O(n²), not quadtree/octree approximation. |
| Collision | Intentionally different | Exact equal-radius O(n²); no per-node radius accessor. |
| Dynamic accessor callbacks | Deferred | Scalar parameters only in milestone one. |
| Barnes-Hut theta/distance approximation | Deferred | No claim of Barnes-Hut support. |
| Browser timer/event API | Intentionally different | Synchronous ticks and explicit running state suit Swift ownership. |
| Force insertion order/manual tick | Reference-tested | Replacement retains order; remove/re-add appends. |
| Missing links, duplicate IDs, self-links | Intentionally different | Invalid/missing/self links are ignored; duplicate lookup uses the first node rather than throwing. |
| Full numerical parity with d3-force-3d | Unverified | Focused fixtures are tested; a broad cross-runtime corpus remains future work. |
