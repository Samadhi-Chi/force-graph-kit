# ``ForceGraphCore``

Build deterministic force-directed layouts without a renderer dependency.

## Overview

Create stable ``ForceNode`` values, configure a ``ForceSimulation``, add named ``AnyForce``
values, and advance it manually or through ``SimulationRunner``. Use ``NodeSnapshot`` values,
``SpatialIndex`` queries, and ``fitTransform(bounds:width:height:depth:padding:)`` at rendering
boundaries. A simulation is mutable single-owner state; snapshots are immutable and `Sendable`.

## Topics

### Simulation
- ``ForceSimulation``
- ``SimulationRunner``
- ``SimulationFrame``
- ``SimulationDimensions``

### Graph data
- ``ForceNode``
- ``ForceLink``
- ``NodeSnapshot``
- ``NodeDelta``
- ``NodeStateUpdate``
- ``LinkDelta``
- ``validateGraph(nodes:links:)``

### Forces and space
- ``AnyForce``
- ``CachedValueProvider``
- ``ManyBodyAlgorithm``
- ``SpatialIndex``
- ``LayoutBounds``
- ``FitTransform``

### Scene integration

`ForceGraphScene` builds on Core bounds and fitting with a reversible `GraphCoordinateSpace`, revisioned frames, update/reheat policy, selective labels, and cooling-aware scheduling. Cooling leaves its scene stream dormant and resumable without a tick loop; hosts stop the scheduler or cancel consumption at lifecycle teardown. Apple entities remain isolated in `ForceGraphRealityKit`.
