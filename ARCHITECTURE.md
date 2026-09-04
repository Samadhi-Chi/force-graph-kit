# Architecture

## Boundaries

`ForceGraphCore` owns generic node/link models, seeded randomness, forces, simulation, and immutable snapshots. It imports no renderer. A future `ForceGraphRealityKit` target can be guarded to Apple platforms and map stable IDs to entities without changing the core.

## Tick flow

Each tick moves alpha toward `alphaTarget`, applies named forces in insertion order,
multiplies velocity by `1 - velocityDecay`, integrates active axes, applies fixed
coordinates exactly, and stops the scheduling state below `alphaMin`. Replacing a force
retains its position; removing and re-adding appends. `tick` always advances when called,
like D3's manual tick, even if scheduling state is stopped. Inactive axes remain untouched.

## Ownership and concurrency

Models and snapshots are `Sendable`. A simulation is mutable state and should be owned by one actor/task; it deliberately has no internal locks. Transfer snapshots across isolation boundaries. Renderer animation timing does not belong in the core.

## RealityKit direction

An adapter should maintain ID-to-entity and ID-to-edge maps, consume one snapshot per rendered frame, update node transforms and edge midpoint/orientation/length, and separately own labels and hit-test components. Gesture code changes fixed coordinates through the simulation owner and reheats/cools alpha as documented in the README.

For a 2D graph, map core `(x, y)` to a chosen RealityKit plane such as `(x, 0, y)`; for 3D map `(x, y, z)` directly after applying an adapter-owned scale. This coordinate policy must remain outside the solver.
