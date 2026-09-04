# Performance

Many-body defaults to deterministic Barnes-Hut above 32 nodes and exposes `.direct` as a reference.
Smaller theta values improve approximation at additional cost. `minimumDistance` softens close
interactions; `maximumDistance` prunes distant work. The orthant tree supports 1D/2D/3D and caps
subdivision depth for coincident points. Radius queries prune tree cells. Nearest lookup currently
performs a deterministic linear scan over validated point storage; no logarithmic nearest-search
claim is made.

Per-node providers are cached when their force is constructed. Recreate the force after relevant
node/link metadata changes. Cached-radius collision uses the spatial index as broad phase; the
constant-radius compatibility convenience remains a direct O(n²) implementation. Scene frame
streams use newest-only buffering to apply backpressure.

Run `swift run -c release force-graph-benchmark 100 1000 5000`. Results are diagnostics, not test
thresholds: hardware, thermal state, compiler, graph distribution, theta, and force mix matter.
No performance claim should be extrapolated to RealityKit rendering until profiled on Apple hardware.
