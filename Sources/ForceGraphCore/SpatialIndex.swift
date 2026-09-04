import Foundation

/// A position stored in a ``SpatialIndex``.
public struct SpatialPoint<ID: Hashable & Sendable>: Sendable {
  /// Stable application identity.
  public let id: ID
  /// Coordinates. Inactive coordinates are ignored by queries.
  public let x: Double
  public let y: Double
  public let z: Double
  /// Creates a spatial point.
  public init(id: ID, x: Double, y: Double = 0, z: Double = 0) {
    self.id = id
    self.x = x
    self.y = y
    self.z = z
  }
}

/// A deterministic, bounded-depth orthant tree for 1D, 2D, and 3D queries.
///
/// Coincident points remain in a leaf bucket after `maximumDepth`, avoiding unbounded
/// recursive subdivision. Results retain input order when distances tie.
public struct SpatialIndex<ID: Hashable & Sendable>: Sendable {
  struct Cell: Sendable {
    var center: (Double, Double, Double)
    var half: Double
    var indices: [Int]
    var children: [Int] = []
  }
  /// Active dimensions used by the index.
  public let dimensions: SimulationDimensions
  /// Indexed points in deterministic input order.
  public let points: [SpatialPoint<ID>]
  var cells: [Cell] = []
  let leafCapacity: Int
  let maximumDepth: Int

  /// Builds an index, dropping points with non-finite active coordinates.
  public init(
    points: [SpatialPoint<ID>], dimensions: SimulationDimensions,
    leafCapacity: Int = 8, maximumDepth: Int = 32
  ) {
    self.dimensions = dimensions
    self.points = points.filter {
      $0.x.isFinite && (dimensions == .one || $0.y.isFinite)
        && (dimensions != .three || $0.z.isFinite)
    }
    self.leafCapacity = max(1, leafCapacity)
    self.maximumDepth = max(1, maximumDepth)
    build()
  }

  /// Returns the nearest point using a deterministic linear scan over validated indexed points,
  /// optionally within a nonnegative finite radius. Input order breaks ties.
  public func nearest(x: Double, y: Double = 0, z: Double = 0, radius: Double? = nil)
    -> SpatialPoint<ID>?
  {
    guard validQuery(x, y, z), radius.map({ $0.isFinite && $0 >= 0 }) ?? true else { return nil }
    var best: Int?
    var bestSquared = radius.map { $0 * $0 } ?? .infinity
    for index in points.indices {
      let distance = squaredDistance(points[index], x, y, z)
      if distance < bestSquared || (distance == bestSquared && best == nil) {
        best = index
        bestSquared = distance
      }
    }
    return best.map { points[$0] }
  }

  /// Returns all points within a nonnegative finite radius in input order.
  public func points(x: Double, y: Double = 0, z: Double = 0, within radius: Double)
    -> [SpatialPoint<ID>]
  {
    guard validQuery(x, y, z), radius.isFinite, radius >= 0 else { return [] }
    let squared = radius * radius
    guard !cells.isEmpty else { return [] }
    var matching = Set<Int>()
    var pending = [0]
    while let cellIndex = pending.popLast() {
      let cell = cells[cellIndex]
      guard minimumSquaredDistance(to: cell, x: x, y: y, z: z) <= squared else { continue }
      if cell.children.isEmpty {
        for pointIndex in cell.indices where squaredDistance(points[pointIndex], x, y, z) <= squared
        {
          matching.insert(pointIndex)
        }
      } else {
        pending.append(contentsOf: cell.children.reversed())
      }
    }
    return points.indices.compactMap { matching.contains($0) ? points[$0] : nil }
  }

  private mutating func build() {
    guard !points.isEmpty else { return }
    let xs = points.map(\.x)
    let ys = dimensions.rawValue > 1 ? points.map(\.y) : [0]
    let zs = dimensions.rawValue > 2 ? points.map(\.z) : [0]
    let minX = xs.min()!
    let maxX = xs.max()!
    let minY = ys.min()!
    let maxY = ys.max()!
    let minZ = zs.min()!
    let maxZ = zs.max()!
    let half = max(1e-9, max(maxX - minX, max(maxY - minY, maxZ - minZ)) / 2)
    cells.append(
      Cell(
        center: ((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2),
        half: half, indices: Array(points.indices)))
    var pending: [(Int, Int)] = [(0, 0)]
    while let (cellIndex, depth) = pending.popLast() {
      let members = cells[cellIndex].indices
      guard members.count > leafCapacity, depth < maximumDepth else { continue }
      let center = cells[cellIndex].center
      let childHalf = cells[cellIndex].half / 2
      var groups: [Int: [Int]] = [:]
      for pointIndex in members {
        let point = points[pointIndex]
        var orthant = point.x >= center.0 ? 1 : 0
        if dimensions.rawValue > 1, point.y >= center.1 { orthant |= 2 }
        if dimensions.rawValue > 2, point.z >= center.2 { orthant |= 4 }
        groups[orthant, default: []].append(pointIndex)
      }
      guard groups.count > 1 else { continue }
      cells[cellIndex].indices = []
      for orthant in groups.keys.sorted() {
        let childCenter = (
          center.0 + ((orthant & 1) == 0 ? -childHalf : childHalf),
          center.1 + ((orthant & 2) == 0 ? -childHalf : childHalf),
          center.2 + ((orthant & 4) == 0 ? -childHalf : childHalf)
        )
        let child = cells.count
        cells.append(Cell(center: childCenter, half: childHalf, indices: groups[orthant]!))
        cells[cellIndex].children.append(child)
        pending.append((child, depth + 1))
      }
    }
  }

  private func validQuery(_ x: Double, _ y: Double, _ z: Double) -> Bool {
    x.isFinite && (dimensions == .one || y.isFinite) && (dimensions != .three || z.isFinite)
  }
  private func squaredDistance(_ point: SpatialPoint<ID>, _ x: Double, _ y: Double, _ z: Double)
    -> Double
  {
    let dx = point.x - x
    let dy = dimensions.rawValue > 1 ? point.y - y : 0
    let dz = dimensions.rawValue > 2 ? point.z - z : 0
    return dx * dx + dy * dy + dz * dz
  }
  private func minimumSquaredDistance(to cell: Cell, x: Double, y: Double, z: Double) -> Double {
    let dx = max(0, abs(x - cell.center.0) - cell.half)
    let dy = dimensions.rawValue > 1 ? max(0, abs(y - cell.center.1) - cell.half) : 0
    let dz = dimensions.rawValue > 2 ? max(0, abs(z - cell.center.2) - cell.half) : 0
    return dx * dx + dy * dy + dz * dz
  }
}
