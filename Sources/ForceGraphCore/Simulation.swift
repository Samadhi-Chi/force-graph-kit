import Foundation

/// A deterministic, synchronous, renderer-independent force simulation.
///
/// Own this mutable value from one actor or task. The type contains no locks; transfer
/// its `Sendable` snapshots to renderers instead of sharing mutable simulation state.
public struct ForceSimulation<ID: Hashable & Sendable>: Sendable {
  /// Current nodes. Use ``replaceNodes(_:)`` to reinitialize a graph explicitly.
  public private(set) var nodes: [ForceNode<ID>]
  /// Number of active dimensions. Changing it initializes newly active non-finite axes;
  /// inactive coordinates and velocities are preserved, matching d3-force-3d.
  public private(set) var dimensions: SimulationDimensions
  /// Current simulation temperature.
  public var alpha = 1.0
  /// Running state becomes false after a tick whose alpha is below this threshold.
  public var alphaMin = 0.001
  /// Fraction of the distance to `alphaTarget` traversed per tick.
  public var alphaDecay = 1 - pow(0.001, 1.0 / 300)
  /// Temperature approached by alpha.
  public var alphaTarget = 0.0
  /// Fraction of velocity removed during integration; retained velocity is `1 - velocityDecay`.
  public var velocityDecay = 0.4
  /// Explicit scheduling state. Manual ``tick(iterations:)`` works even when false.
  public private(set) var isRunning = true

  private struct NamedForce: Sendable {
    var name: String
    var force: AnyForce<ID>
  }
  private var forces: [NamedForce] = []
  private var random: D3Random

  /// Creates a simulation and initializes nodes using D3's deterministic placement.
  /// - Parameters:
  ///   - nodes: Initial nodes. Duplicate identifiers are allowed in storage, but link lookup
  ///     resolves to the first occurrence; prefer unique identifiers.
  ///   - dimensions: Active dimension count.
  ///   - seed: Seed for D3-compatible jiggle.
  public init(
    nodes: [ForceNode<ID>] = [], dimensions: SimulationDimensions = .two, seed: UInt32 = 1
  ) {
    self.nodes = nodes
    self.dimensions = dimensions
    self.random = D3Random(seed: seed)
    initializeNodes()
  }

  /// Adds, replaces, or removes a named force while preserving insertion order.
  /// Replacing retains its slot; removing and later adding appends.
  public mutating func force(_ name: String, _ value: AnyForce<ID>?) {
    if let index = forces.firstIndex(where: { $0.name == name }) {
      if let value { forces[index].force = value } else { forces.remove(at: index) }
    } else if let value {
      forces.append(NamedForce(name: name, force: value))
    }
  }

  /// Replaces and explicitly initializes all nodes without consuming random values.
  public mutating func replaceNodes(_ value: [ForceNode<ID>]) {
    nodes = value
    initializeNodes()
  }

  /// Changes active dimensions and initializes only non-finite coordinates newly required.
  public mutating func setDimensions(_ value: SimulationDimensions) {
    dimensions = value
    initializeNodes()
  }

  /// Replaces the named link force; endpoints are resolved on every tick.
  public mutating func replaceLinks(
    _ links: [ForceLink<ID>], name: String = "link", iterations: Int = 1
  ) {
    force(name, .link(links, iterations: iterations))
  }

  /// Mutates one uniquely selected node without implicit reinitialization or RNG changes.
  /// - Returns: `true` when a matching node was found.
  @discardableResult
  public mutating func updateNode(id: ID, _ update: (inout ForceNode<ID>) -> Void) -> Bool {
    guard let index = nodes.firstIndex(where: { $0.id == id }) else { return false }
    update(&nodes[index])
    return true
  }

  /// Advances the simulation synchronously. Negative iterations perform no work.
  /// Invalid simulation tuning values use documented safe defaults or clamps.
  public mutating func tick(iterations: Int = 1) {
    for _ in 0..<max(0, iterations) {
      let minimum = alphaMin.isFinite ? max(0, alphaMin) : 0.001
      let decay = alphaDecay.isFinite ? min(1, max(0, alphaDecay)) : 0
      let target = alphaTarget.isFinite ? alphaTarget : 0
      alpha = alpha.isFinite ? alpha + (target - alpha) * decay : 1

      for entry in forces {
        entry.force.apply(to: &nodes, alpha: alpha, dimensions: dimensions, random: &random)
      }

      let retention = velocityDecay.isFinite ? 1 - min(1, max(0, velocityDecay)) : 0.6
      for index in nodes.indices {
        Self.integrate(&nodes[index], dimensions: dimensions, retention: retention)
      }
      if alpha < minimum { isRunning = false }
    }
  }

  /// Marks the simulation as running without changing alpha.
  public mutating func restart() { isRunning = true }
  /// Marks the simulation as stopped without preventing manual ticks.
  public mutating func stop() { isRunning = false }

  /// Returns complete immutable node state for rendering and drag coordination.
  public func snapshots() -> [NodeSnapshot<ID>] {
    nodes.map {
      NodeSnapshot(
        id: $0.id, x: $0.x, y: $0.y, z: $0.z,
        vx: $0.vx, vy: $0.vy, vz: $0.vz,
        fx: $0.fx, fy: $0.fy, fz: $0.fz)
    }
  }

  /// Finds the nearest node in active dimensions, optionally within a radius.
  /// Invalid or negative radii produce no result; omitted radius is unbounded.
  public func find(x: Double, y: Double = 0, z: Double = 0, radius: Double? = nil) -> ForceNode<ID>?
  {
    let index = SpatialIndex(
      points: nodes.map {
        SpatialPoint(id: $0.id, x: $0.x, y: $0.y, z: $0.z)
      }, dimensions: dimensions)
    guard let nearest = index.nearest(x: x, y: y, z: z, radius: radius) else { return nil }
    return nodes.first { $0.id == nearest.id }
  }

  private mutating func initializeNodes() {
    let rollAngle = Double.pi * (3 - sqrt(5.0))
    let yawAngle = Double.pi * (20 - sqrt(391.0))
    for index in nodes.indices {
      if let fixed = nodes[index].fx, fixed.isFinite { nodes[index].x = fixed }
      if let fixed = nodes[index].fy, fixed.isFinite { nodes[index].y = fixed }
      if let fixed = nodes[index].fz, fixed.isFinite { nodes[index].z = fixed }
      let i = Double(index)
      if dimensions == .one, !nodes[index].x.isFinite { nodes[index].x = 10 * i }
      if dimensions == .two, !nodes[index].x.isFinite || !nodes[index].y.isFinite {
        let radius = 10 * sqrt(0.5 + i)
        let angle = i * rollAngle
        nodes[index].x = radius * cos(angle)
        nodes[index].y = radius * sin(angle)
      }
      if dimensions == .three,
        !nodes[index].x.isFinite || !nodes[index].y.isFinite || !nodes[index].z.isFinite
      {
        let radius = 10 * cbrt(0.5 + i)
        let roll = i * rollAngle
        let yaw = i * yawAngle
        nodes[index].x = radius * sin(roll) * cos(yaw)
        nodes[index].y = radius * cos(roll)
        nodes[index].z = radius * sin(roll) * sin(yaw)
      }
      if !nodes[index].vx.isFinite { nodes[index].vx = 0 }
      if !nodes[index].vy.isFinite { nodes[index].vy = 0 }
      if !nodes[index].vz.isFinite { nodes[index].vz = 0 }
    }
  }

  private static func integrate(
    _ node: inout ForceNode<ID>, dimensions: SimulationDimensions, retention: Double
  ) {
    integrateAxis(position: &node.x, velocity: &node.vx, fixed: node.fx)
    if dimensions.rawValue > 1 {
      integrateAxis(position: &node.y, velocity: &node.vy, fixed: node.fy)
    }
    if dimensions.rawValue > 2 {
      integrateAxis(position: &node.z, velocity: &node.vz, fixed: node.fz)
    }

    func integrateAxis(position: inout Double, velocity: inout Double, fixed: Double?) {
      if let fixed, fixed.isFinite {
        position = fixed
        velocity = 0
      } else {
        velocity *= retention
        position += velocity
      }
      if !position.isFinite {
        position = 0
        velocity = 0
      }
    }
  }
}
