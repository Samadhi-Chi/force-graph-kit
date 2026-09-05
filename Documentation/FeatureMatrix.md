# Feature Matrix

| Capability | State | Scope |
|---|---|---|
| 1D/2D/3D simulation, cooling, fixed axes | Implemented/tested | D3-compatible focused fixtures |
| Center/link/charge/collision/axis/radial | Implemented/tested | Constants and cached providers |
| Barnes-Hut charge | Implemented/tested | Dimension-generic deterministic orthant tree; direct reference mode |
| Nearest/radius queries | Implemented/tested | Tree-pruned radius query; deterministic linear nearest scan |
| Graph deltas/diagnostics | Implemented/tested | Stable IDs; duplicate/unresolved reporting |
| Async simulation frames | Implemented/tested | Actor ownership, newest-frame buffering, cancellation |
| Node/link visuals, labels, selection/highlight | Implemented/tested | ForceGraphScene data/controller layer |
| Drag/reheat/release and synchronized edges | Implemented/tested | Renderer-neutral frames |
| Camera controls | Not applicable | Fit/focus intents only; renderer owns camera |
| Curved links, particles, sprites | Deferred | Straight edges and directional metadata now |
| D3 JS events/accessor source compatibility | Not applicable | Native Swift API, semantic compatibility only |
| RealityKit entity synchronization | Source implemented/unverified | Conditional target; API requires macOS 15, iOS 18, or visionOS 2 |
| SwiftUI RealityView application | Example source/unverified | Host application owns lifecycle and UI |
| visionOS simulator/device acceptance | Deferred | Explicit maintainer gates |

## v0.2 additions

| Capability | State | Scope |
|---|---|---|
| Reversible XY/XZ/YZ/XYZ mapping and volume fit | Linux tested | Scene contract using Core fit |
| Scene update reheat policy and revision metadata | Linux tested | Stable-ID dynamics retained |
| Cooling-aware newest-frame scheduler | Linux tested | UI-neutral actor |
| Typed RealityKit entity lookup, bounded pools, unit meshes | Apple-conditional source/tests | Requires Apple SDK execution |
| Label visibility policy and custom entity factory | Scene tested / adapter conditional | No built-in text allocation |
| Direction indicator | Adapter source implemented | Straight shaft plus optional cone |
