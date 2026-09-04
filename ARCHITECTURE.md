# Architecture

## Boundaries

`ForceGraphCore` owns generic node/link models, seeded randomness, forces, simulation, spatial
indexing, and immutable snapshots. It imports no renderer. `ForceGraphScene` owns UI-neutral visual
and interaction state. `ForceGraphRealityKit` contains a small conditionally compiled entity
synchronizer; it is source-reviewed but has not been compiled with an Apple SDK in this milestone.

## Tick flow

Each tick moves alpha toward `alphaTarget`, applies named forces in insertion order,
multiplies velocity by `1 - velocityDecay`, integrates active axes, applies fixed
coordinates exactly, and stops the scheduling state below `alphaMin`. Replacing a force
retains its position; removing and re-adding appends. `tick` always advances when called,
like D3's manual tick, even if scheduling state is stopped. Inactive axes remain untouched.

## Ownership and concurrency

Models and snapshots are `Sendable`. A simulation is mutable state and should be owned by one
actor/task; it deliberately has no internal locks. `SimulationRunner` and `ForceGraphController`
provide actor-owned scheduling and coordination. Their streams retain only bounded newest values,
replace prior consumers deterministically, and clear continuations on termination. Transfer
snapshots across isolation boundaries rather than sharing mutable simulation state.

## RealityKit direction

The conditional adapter maintains ID-to-entity and ID-to-edge maps, consumes one render frame,
updates node transforms and edge midpoint/orientation/length, parents labels to node roots, and owns
collision/input components. Host gesture code changes fixed coordinates through the controller and
reheats/cools alpha as documented in the README. Apple compilation and behavior remain acceptance
gates, not Linux-validated claims.

For a 2D graph, map core `(x, y)` to a chosen RealityKit plane such as `(x, 0, y)`; for 3D map `(x, y, z)` directly after applying an adapter-owned scale. This coordinate policy must remain outside the solver.

## Spatial execution and product layer

The core's bounded-depth orthant tree represents a binary tree, quadtree, or octree according
to active dimensions. Barnes-Hut cells are traversed iteratively, while direct mode remains a
reference. Radius collision candidates and public radius queries share the spatial index.
`ForceGraphScene` owns visual descriptors and interaction state but not UI objects. Its controller
produces one immutable frame containing node/label state and both endpoints of every edge, ensuring
all geometry derives from the same simulation revision.
