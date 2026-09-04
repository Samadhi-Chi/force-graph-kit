/// A simulation node identified by an application-defined stable identifier.
public struct ForceNode<ID: Hashable & Sendable>: Sendable {
  /// The stable identifier used by links, snapshots, and hit testing.
  public let id: ID
  /// Position on the x axis.
  public var x: Double
  /// Position on the y axis.
  public var y: Double
  /// Position on the z axis.
  public var z: Double
  /// Velocity on the x axis.
  public var vx: Double
  /// Velocity on the y axis.
  public var vy: Double
  /// Velocity on the z axis.
  public var vz: Double
  /// Optional fixed x coordinate. A finite value overrides position and clears velocity.
  public var fx: Double?
  /// Optional fixed y coordinate. A finite value overrides position and clears velocity.
  public var fy: Double?
  /// Optional fixed z coordinate. A finite value overrides position and clears velocity.
  public var fz: Double?

  /// Creates a node. Non-finite positions are initialized when inserted into a simulation.
  public init(
    id: ID, x: Double = .nan, y: Double = .nan, z: Double = .nan,
    vx: Double = 0, vy: Double = 0, vz: Double = 0,
    fx: Double? = nil, fy: Double? = nil, fz: Double? = nil
  ) {
    self.id = id
    self.x = x
    self.y = y
    self.z = z
    self.vx = vx
    self.vy = vy
    self.vz = vz
    self.fx = fx
    self.fy = fy
    self.fz = fz
  }
}

/// A link described by stable endpoint identifiers.
public struct ForceLink<ID: Hashable & Sendable>: Sendable {
  /// Source node identifier.
  public let source: ID
  /// Target node identifier.
  public let target: ID
  /// Desired nonnegative distance. Invalid values disable this link.
  public var distance: Double
  /// Optional spring strength. `nil` selects D3's degree-based default.
  public var strength: Double?

  /// Creates a link.
  public init(source: ID, target: ID, distance: Double = 30, strength: Double? = nil) {
    self.source = source
    self.target = target
    self.distance = distance
    self.strength = strength
  }
}

/// Immutable renderer-facing node state.
public struct NodeSnapshot<ID: Hashable & Sendable>: Sendable {
  /// Stable node identifier.
  public let id: ID
  /// Current position.
  public let x: Double
  public let y: Double
  public let z: Double
  /// Current velocity.
  public let vx: Double
  public let vy: Double
  public let vz: Double
  /// Current drag/pinning coordinates.
  public let fx: Double?
  public let fy: Double?
  public let fz: Double?
}

/// Number of axes affected by forces, initialization, integration, and search.
public enum SimulationDimensions: Int, Sendable {
  /// Only x is active.
  case one = 1
  /// x and y are active.
  case two = 2
  /// x, y, and z are active.
  case three = 3
}

/// D3's default 32-bit linear-congruential random source.
public struct D3Random: Sendable {
  private var state: UInt32

  /// Creates a stream. D3's simulation default seed is `1`.
  public init(seed: UInt32 = 1) { state = seed }

  /// Returns the next value in `[0, 1)`.
  public mutating func next() -> Double {
    state = 1_664_525 &* state &+ 1_013_904_223
    return Double(state) / 4_294_967_296
  }

  /// Returns D3's microscopic nonzero perturbation in approximately `[-5e-7, 5e-7)`.
  public mutating func jiggle() -> Double { (next() - 0.5) * 1e-6 }
}
