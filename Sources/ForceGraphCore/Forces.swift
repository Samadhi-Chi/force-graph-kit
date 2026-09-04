import Foundation

/// A type-erased force whose checked `Sendable` closure operates on simulation values.
public struct AnyForce<ID: Hashable & Sendable>: Sendable {
  /// Force implementation signature.
  public typealias Body =
    @Sendable (
      inout [ForceNode<ID>], Double, SimulationDimensions, inout D3Random
    ) -> Void
  private let body: Body

  /// Creates a force from a sendable implementation closure.
  /// - Parameter body: Closure receiving nodes, alpha, dimensions, and seeded random source.
  public init(_ body: @escaping Body) { self.body = body }

  /// Applies this force to nodes.
  /// - Parameters:
  ///   - nodes: Nodes to mutate.
  ///   - alpha: Current simulation temperature.
  ///   - dimensions: Active dimensions.
  ///   - random: Deterministic random stream used for jiggle.
  public func apply(
    to nodes: inout [ForceNode<ID>], alpha: Double,
    dimensions: SimulationDimensions, random: inout D3Random
  ) { body(&nodes, alpha, dimensions, &random) }
}

extension AnyForce {
  /// Creates a velocity-independent centroid translation.
  public static func center(x: Double = 0, y: Double = 0, z: Double = 0, strength: Double = 1)
    -> Self
  {
    Self { nodes, _, dimensions, _ in
      guard !nodes.isEmpty, x.isFinite, y.isFinite, z.isFinite,
        strength.isFinite, strength >= 0
      else { return }
      let sums = nodes.reduce((x: 0.0, y: 0.0, z: 0.0)) {
        ($0.x + $1.x, $0.y + $1.y, $0.z + $1.z)
      }
      let count = Double(nodes.count)
      for index in nodes.indices {
        nodes[index].x -= (sums.x / count - x) * strength
        if dimensions.rawValue > 1 { nodes[index].y -= (sums.y / count - y) * strength }
        if dimensions.rawValue > 2 { nodes[index].z -= (sums.z / count - z) * strength }
      }
    }
  }

  /// Creates an x-position force. Invalid or negative strength disables it.
  public static func x(_ target: Double = 0, strength: Double = 0.1) -> Self {
    axis(target, strength: strength, axis: 0)
  }
  /// Creates a y-position force, inactive in 1D.
  public static func y(_ target: Double = 0, strength: Double = 0.1) -> Self {
    axis(target, strength: strength, axis: 1)
  }
  /// Creates a z-position force, active only in 3D.
  public static func z(_ target: Double = 0, strength: Double = 0.1) -> Self {
    axis(target, strength: strength, axis: 2)
  }

  /// Creates the source-compatible default many-body force using Barnes-Hut above 32 nodes.
  public static func manyBody(
    strength: Double = -30, minimumDistance: Double = 1,
    maximumDistance: Double = .infinity
  ) -> Self {
    manyBody(
      strength: strength, minimumDistance: minimumDistance, maximumDistance: maximumDistance,
      algorithm: .barnesHut())
  }

  /// Creates a many-body force with an explicit execution algorithm.
  /// Negative strength repels; positive strength attracts.
  /// Distances below `minimumDistance` use D3's softened denominator; pairs at or beyond
  /// `maximumDistance` are ignored. Invalid or negative distances disable the force. Direct mode
  /// is exact. Barnes-Hut requires finite positive theta; negative thresholds clamp to zero.
  public static func manyBody(
    strength: Double = -30, minimumDistance: Double = 1,
    maximumDistance: Double = .infinity, algorithm: ManyBodyAlgorithm
  ) -> Self {
    Self { nodes, alpha, dimensions, random in
      guard strength.isFinite, minimumDistance.isFinite, minimumDistance >= 0,
        maximumDistance >= 0, !maximumDistance.isNaN,
        maximumDistance >= minimumDistance
      else { return }
      let minimumSquared = minimumDistance * minimumDistance
      let maximumSquared = maximumDistance * maximumDistance
      switch algorithm {
      case .direct:
        applyDirectManyBody(
          to: &nodes, alpha: alpha, dimensions: dimensions,
          strength: strength, minimumSquared: minimumSquared,
          maximumSquared: maximumSquared, random: &random)
      case .barnesHut(let theta, let directThreshold):
        guard theta.isFinite, theta > 0 else { return }
        if nodes.count <= max(0, directThreshold) {
          applyDirectManyBody(
            to: &nodes, alpha: alpha, dimensions: dimensions,
            strength: strength, minimumSquared: minimumSquared,
            maximumSquared: maximumSquared, random: &random)
        } else {
          applyBarnesHut(
            to: &nodes, alpha: alpha, dimensions: dimensions,
            strength: strength, theta: theta,
            minimumSquared: minimumSquared,
            maximumSquared: maximumSquared, random: &random)
        }
      }
    }
  }

  /// Creates an equal-radius direct collision force. Invalid radius/strength disables it;
  /// nonpositive iteration counts perform no work.
  public static func collision(radius: Double = 1, strength: Double = 1, iterations: Int = 1)
    -> Self
  {
    Self { nodes, _, dimensions, random in
      guard radius.isFinite, radius >= 0, strength.isFinite, strength >= 0 else { return }
      for _ in 0..<max(0, iterations) {
        for first in nodes.indices {
          for second in nodes.indices where second > first {
            var delta = predictedDisplacement(nodes[first], nodes[second], dimensions)
            jiggleIfZero(&delta, dimensions: dimensions, random: &random)
            let length = sqrt(lengthSquared(delta))
            let desired = radius * 2
            guard length < desired, length > 0 else { continue }
            let scale = (desired - length) / length * strength * 0.5
            applyVelocity(delta, scale: scale, to: &nodes[first], sign: -1, dimensions: dimensions)
            applyVelocity(delta, scale: scale, to: &nodes[second], sign: 1, dimensions: dimensions)
          }
        }
      }
    }
  }

  /// Creates a force toward a circle or sphere around the supplied center.
  public static func radial(
    radius: Double, x: Double = 0, y: Double = 0, z: Double = 0,
    strength: Double = 0.1
  ) -> Self {
    Self { nodes, alpha, dimensions, random in
      guard radius.isFinite, radius >= 0, x.isFinite, y.isFinite, z.isFinite,
        strength.isFinite, strength >= 0
      else { return }
      for index in nodes.indices {
        var delta = (
          x: nodes[index].x - x,
          y: dimensions.rawValue > 1 ? nodes[index].y - y : 0,
          z: dimensions.rawValue > 2 ? nodes[index].z - z : 0
        )
        jiggleIfZero(&delta, dimensions: dimensions, random: &random)
        let length = sqrt(lengthSquared(delta))
        let scale = (radius - length) * strength * alpha / length
        applyVelocity(delta, scale: scale, to: &nodes[index], sign: 1, dimensions: dimensions)
      }
    }
  }

  /// Creates D3's degree-biased spring force. Missing endpoints, self-links, invalid
  /// distances, and invalid strengths are ignored; nonpositive iterations do no work.
  public static func link(_ links: [ForceLink<ID>], iterations: Int = 1) -> Self {
    Self { nodes, alpha, dimensions, random in
      var indexByID: [ID: Int] = [:]
      for index in nodes.indices where indexByID[nodes[index].id] == nil {
        indexByID[nodes[index].id] = index
      }
      var degree: [ID: Int] = [:]
      for link in links
      where indexByID[link.source] != nil && indexByID[link.target] != nil
        && link.source != link.target
      {
        degree[link.source, default: 0] += 1
        degree[link.target, default: 0] += 1
      }
      for _ in 0..<max(0, iterations) {
        for link in links {
          guard let source = indexByID[link.source], let target = indexByID[link.target],
            source != target, link.distance.isFinite, link.distance >= 0,
            link.strength?.isFinite != false, (link.strength ?? 0) >= 0
          else { continue }
          var delta = predictedDisplacement(nodes[source], nodes[target], dimensions)
          jiggleIfZero(&delta, dimensions: dimensions, random: &random)
          let length = sqrt(lengthSquared(delta))
          let sourceDegree = degree[link.source, default: 1]
          let targetDegree = degree[link.target, default: 1]
          let bias = Double(sourceDegree) / Double(sourceDegree + targetDegree)
          let strength = link.strength ?? 1 / Double(min(sourceDegree, targetDegree))
          let scale = (length - link.distance) / length * alpha * strength
          applyVelocity(
            delta, scale: scale * (1 - bias), to: &nodes[source], sign: 1, dimensions: dimensions)
          applyVelocity(
            delta, scale: scale * bias, to: &nodes[target], sign: -1, dimensions: dimensions)
        }
      }
    }
  }

  private static func axis(_ target: Double, strength: Double, axis: Int) -> Self {
    Self { nodes, alpha, dimensions, _ in
      guard axis < dimensions.rawValue, target.isFinite,
        strength.isFinite, strength >= 0
      else { return }
      for index in nodes.indices {
        if axis == 0 { nodes[index].vx += (target - nodes[index].x) * strength * alpha }
        if axis == 1 { nodes[index].vy += (target - nodes[index].y) * strength * alpha }
        if axis == 2 { nodes[index].vz += (target - nodes[index].z) * strength * alpha }
      }
    }
  }
}

private func applyDirectManyBody<ID>(
  to nodes: inout [ForceNode<ID>], alpha: Double, dimensions: SimulationDimensions,
  strength: Double, minimumSquared: Double, maximumSquared: Double,
  random: inout D3Random
) {
  for first in nodes.indices {
    for second in nodes.indices where second > first {
      var delta = displacement(nodes[first], nodes[second], dimensions)
      jiggleIfZero(&delta, dimensions: dimensions, random: &random)
      var squared = lengthSquared(delta)
      if squared >= maximumSquared { continue }
      if squared < minimumSquared { squared = sqrt(minimumSquared * squared) }
      guard squared > 0, squared.isFinite else { continue }
      let scale = strength * alpha / squared
      applyVelocity(delta, scale: scale, to: &nodes[first], sign: 1, dimensions: dimensions)
      applyVelocity(delta, scale: scale, to: &nodes[second], sign: -1, dimensions: dimensions)
    }
  }
}

struct BarnesHutAggregate: Sendable {
  let count: Int
  let x: Double
  let y: Double
  let z: Double
}

func barnesHutAggregates<ID>(tree: SpatialIndex<ID>) -> [BarnesHutAggregate] {
  var result = Array(
    repeating: BarnesHutAggregate(count: 0, x: 0, y: 0, z: 0), count: tree.cells.count)
  for cellIndex in tree.cells.indices.reversed() {
    let cell = tree.cells[cellIndex]
    var count = 0
    var sumX = 0.0
    var sumY = 0.0
    var sumZ = 0.0
    if cell.children.isEmpty {
      count = cell.indices.count
      for pointIndex in cell.indices {
        sumX += tree.points[pointIndex].x
        sumY += tree.points[pointIndex].y
        sumZ += tree.points[pointIndex].z
      }
    } else {
      for child in cell.children {
        let aggregate = result[child]
        count += aggregate.count
        sumX += aggregate.x * Double(aggregate.count)
        sumY += aggregate.y * Double(aggregate.count)
        sumZ += aggregate.z * Double(aggregate.count)
      }
    }
    if count > 0 {
      let divisor = Double(count)
      result[cellIndex] = BarnesHutAggregate(
        count: count, x: sumX / divisor, y: sumY / divisor, z: sumZ / divisor)
    }
  }
  return result
}

private func applyBarnesHut<ID>(
  to nodes: inout [ForceNode<ID>], alpha: Double, dimensions: SimulationDimensions,
  strength: Double, theta: Double, minimumSquared: Double, maximumSquared: Double,
  random: inout D3Random
) {
  let points = nodes.map { SpatialPoint(id: $0.id, x: $0.x, y: $0.y, z: $0.z) }
  let tree = SpatialIndex(points: points, dimensions: dimensions, leafCapacity: 4)
  guard !tree.cells.isEmpty else { return }
  let aggregates = barnesHutAggregates(tree: tree)
  let counts = aggregates.map(\.count)
  let centers = aggregates.map { (x: $0.x, y: $0.y, z: $0.z) }
  for target in nodes.indices {
    var stack = [0]
    while let cellIndex = stack.popLast() {
      let cell = tree.cells[cellIndex]
      guard counts[cellIndex] > 0 else { continue }
      let containsTarget =
        abs(nodes[target].x - cell.center.0) <= cell.half
        && (dimensions == .one || abs(nodes[target].y - cell.center.1) <= cell.half)
        && (dimensions != .three || abs(nodes[target].z - cell.center.2) <= cell.half)
      var delta = (
        x: centers[cellIndex].x - nodes[target].x,
        y: dimensions.rawValue > 1 ? centers[cellIndex].y - nodes[target].y : 0,
        z: dimensions.rawValue > 2 ? centers[cellIndex].z - nodes[target].z : 0
      )
      var squared = lengthSquared(delta)
      let width = cell.half * 2
      if !containsTarget && cell.children.count > 0 && width * width < theta * theta * squared {
        if squared >= maximumSquared { continue }
        jiggleIfZero(&delta, dimensions: dimensions, random: &random)
        squared = lengthSquared(delta)
        if squared < minimumSquared { squared = sqrt(minimumSquared * squared) }
        guard squared > 0 else { continue }
        let scale = strength * alpha * Double(counts[cellIndex]) / squared
        applyVelocity(delta, scale: scale, to: &nodes[target], sign: 1, dimensions: dimensions)
      } else if cell.children.isEmpty {
        for other in cell.indices where other != target {
          var direct = displacement(nodes[target], nodes[other], dimensions)
          jiggleIfZero(&direct, dimensions: dimensions, random: &random)
          var directSquared = lengthSquared(direct)
          if directSquared >= maximumSquared { continue }
          if directSquared < minimumSquared { directSquared = sqrt(minimumSquared * directSquared) }
          guard directSquared > 0 else { continue }
          applyVelocity(
            direct, scale: strength * alpha / directSquared,
            to: &nodes[target], sign: 1, dimensions: dimensions)
        }
      } else {
        stack.append(contentsOf: cell.children.reversed())
      }
    }
  }
}

private typealias Vector3 = (x: Double, y: Double, z: Double)
private func displacement<ID>(_ a: ForceNode<ID>, _ b: ForceNode<ID>, _ d: SimulationDimensions)
  -> Vector3
{
  (b.x - a.x, d.rawValue > 1 ? b.y - a.y : 0, d.rawValue > 2 ? b.z - a.z : 0)
}
private func predictedDisplacement<ID>(
  _ a: ForceNode<ID>, _ b: ForceNode<ID>, _ d: SimulationDimensions
) -> Vector3 {
  (
    b.x + b.vx - a.x - a.vx,
    d.rawValue > 1 ? b.y + b.vy - a.y - a.vy : 0,
    d.rawValue > 2 ? b.z + b.vz - a.z - a.vz : 0
  )
}
private func lengthSquared(_ v: Vector3) -> Double { v.x * v.x + v.y * v.y + v.z * v.z }
private func jiggleIfZero(
  _ v: inout Vector3, dimensions: SimulationDimensions, random: inout D3Random
) {
  if v.x == 0 { v.x = random.jiggle() }
  if dimensions.rawValue > 1, v.y == 0 { v.y = random.jiggle() }
  if dimensions.rawValue > 2, v.z == 0 { v.z = random.jiggle() }
}
private func applyVelocity<ID>(
  _ v: Vector3, scale: Double, to node: inout ForceNode<ID>, sign: Double,
  dimensions: SimulationDimensions
) {
  node.vx += v.x * scale * sign
  if dimensions.rawValue > 1 { node.vy += v.y * scale * sign }
  if dimensions.rawValue > 2 { node.vz += v.z * scale * sign }
}
