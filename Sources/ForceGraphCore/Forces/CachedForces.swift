import Foundation

extension AnyForce {
  /// Creates a direct many-body force with strengths cached from the supplied node revision.
  /// Positive source strengths attract and negative strengths repel. Recreate the force to
  /// invalidate cached values; duplicate IDs use the first value.
  public static func manyBody(
    nodes: [ForceNode<ID>], strengths: CachedValueProvider<ForceNode<ID>>,
    minimumDistance: Double = 1, maximumDistance: Double = .infinity
  ) -> Self {
    let cached = cacheFirst(ids: nodes.map(\.id), values: strengths.values(for: nodes))
    return Self { values, alpha, dimensions, random in
      guard minimumDistance.isFinite, minimumDistance >= 0,
        !maximumDistance.isNaN, maximumDistance >= minimumDistance
      else { return }
      let minSquared = minimumDistance * minimumDistance
      let maxSquared = maximumDistance * maximumDistance
      for target in values.indices {
        for source in values.indices where source != target {
          guard let strength = cached[values[source].id], strength.isFinite else { continue }
          var dx = values[source].x - values[target].x
          var dy = dimensions.rawValue > 1 ? values[source].y - values[target].y : 0
          var dz = dimensions.rawValue > 2 ? values[source].z - values[target].z : 0
          if dx == 0 { dx = random.jiggle() }
          if dimensions.rawValue > 1, dy == 0 { dy = random.jiggle() }
          if dimensions.rawValue > 2, dz == 0 { dz = random.jiggle() }
          var squared = dx * dx + dy * dy + dz * dz
          if squared >= maxSquared { continue }
          if squared < minSquared { squared = sqrt(minSquared * squared) }
          guard squared > 0 else { continue }
          let scale = strength * alpha / squared
          values[target].vx += dx * scale
          if dimensions.rawValue > 1 { values[target].vy += dy * scale }
          if dimensions.rawValue > 2 { values[target].vz += dz * scale }
        }
      }
    }
  }

  /// Creates an indexed collision force with radii cached from the supplied node revision.
  /// Invalid/negative radii disable their nodes. Recreate the force to invalidate its cache.
  public static func collision(
    nodes: [ForceNode<ID>], radii: CachedValueProvider<ForceNode<ID>>,
    strength: Double = 1, iterations: Int = 1
  ) -> Self {
    let cached = cacheFirst(ids: nodes.map(\.id), values: radii.values(for: nodes))
    return Self { values, _, dimensions, random in
      guard strength.isFinite, strength >= 0 else { return }
      let maximumRadius = cached.values.filter { $0.isFinite && $0 >= 0 }.max() ?? 0
      for _ in 0..<max(0, iterations) {
        let predicted = values.indices.map {
          SpatialPoint(
            id: $0, x: values[$0].x + values[$0].vx,
            y: values[$0].y + values[$0].vy,
            z: values[$0].z + values[$0].vz)
        }
        let index = SpatialIndex(points: predicted, dimensions: dimensions)
        for first in values.indices {
          guard let firstRadius = cached[values[first].id], firstRadius.isFinite,
            firstRadius >= 0
          else { continue }
          let nearby = index.points(
            x: predicted[first].x, y: predicted[first].y,
            z: predicted[first].z,
            within: firstRadius + maximumRadius)
          for candidate in nearby where candidate.id > first {
            let second = candidate.id
            guard let secondRadius = cached[values[second].id],
              secondRadius.isFinite, secondRadius >= 0
            else { continue }
            var dx = values[second].x + values[second].vx - values[first].x - values[first].vx
            var dy =
              dimensions.rawValue > 1
              ? values[second].y + values[second].vy - values[first].y - values[first].vy : 0
            var dz =
              dimensions.rawValue > 2
              ? values[second].z + values[second].vz - values[first].z - values[first].vz : 0
            if dx == 0 { dx = random.jiggle() }
            if dimensions.rawValue > 1, dy == 0 { dy = random.jiggle() }
            if dimensions.rawValue > 2, dz == 0 { dz = random.jiggle() }
            let length = sqrt(dx * dx + dy * dy + dz * dz)
            let desired = firstRadius + secondRadius
            guard length < desired, length > 0 else { continue }
            let scale = (desired - length) / length * strength
            let total = firstRadius * firstRadius + secondRadius * secondRadius
            let firstShare = total > 0 ? secondRadius * secondRadius / total : 0.5
            let secondShare = 1 - firstShare
            values[first].vx -= dx * scale * firstShare
            values[second].vx += dx * scale * secondShare
            if dimensions.rawValue > 1 {
              values[first].vy -= dy * scale * firstShare
              values[second].vy += dy * scale * secondShare
            }
            if dimensions.rawValue > 2 {
              values[first].vz -= dz * scale * firstShare
              values[second].vz += dz * scale * secondShare
            }
          }
        }
      }
    }
  }

  /// Creates a link force after caching per-link distance and strength providers. Recreate the
  /// force after the link revision or accessor inputs change.
  public static func link(
    _ links: [ForceLink<ID>], distances: CachedValueProvider<ForceLink<ID>>,
    strengths: CachedValueProvider<ForceLink<ID>>, iterations: Int = 1
  ) -> Self {
    let distanceValues = distances.values(for: links)
    let strengthValues = strengths.values(for: links)
    let cached = links.indices.map {
      ForceLink(
        source: links[$0].source, target: links[$0].target,
        distance: distanceValues[$0], strength: strengthValues[$0])
    }
    return .link(cached, iterations: iterations)
  }

  /// Creates an x force with targets and strengths cached by stable ID.
  public static func x(
    nodes: [ForceNode<ID>], targets: CachedValueProvider<ForceNode<ID>>,
    strengths: CachedValueProvider<ForceNode<ID>>
  ) -> Self { cachedAxis(nodes: nodes, targets: targets, strengths: strengths, axis: 0) }

  /// Creates a y force with targets and strengths cached by stable ID.
  public static func y(
    nodes: [ForceNode<ID>], targets: CachedValueProvider<ForceNode<ID>>,
    strengths: CachedValueProvider<ForceNode<ID>>
  ) -> Self { cachedAxis(nodes: nodes, targets: targets, strengths: strengths, axis: 1) }

  /// Creates a z force with targets and strengths cached by stable ID.
  public static func z(
    nodes: [ForceNode<ID>], targets: CachedValueProvider<ForceNode<ID>>,
    strengths: CachedValueProvider<ForceNode<ID>>
  ) -> Self { cachedAxis(nodes: nodes, targets: targets, strengths: strengths, axis: 2) }

  /// Creates a radial force with radii and strengths cached by stable node ID.
  public static func radial(
    nodes: [ForceNode<ID>], radii: CachedValueProvider<ForceNode<ID>>,
    strengths: CachedValueProvider<ForceNode<ID>>, x: Double = 0, y: Double = 0, z: Double = 0
  ) -> Self {
    let radius = cacheFirst(ids: nodes.map(\.id), values: radii.values(for: nodes))
    let strength = cacheFirst(ids: nodes.map(\.id), values: strengths.values(for: nodes))
    return Self { values, alpha, dimensions, random in
      guard x.isFinite, y.isFinite, z.isFinite else { return }
      for index in values.indices {
        guard let radius = radius[values[index].id], let strength = strength[values[index].id],
          radius.isFinite, radius >= 0, strength.isFinite, strength >= 0
        else { continue }
        var dx = values[index].x - x
        var dy = dimensions.rawValue > 1 ? values[index].y - y : 0
        var dz = dimensions.rawValue > 2 ? values[index].z - z : 0
        if dx == 0 { dx = random.jiggle() }
        if dimensions.rawValue > 1, dy == 0 { dy = random.jiggle() }
        if dimensions.rawValue > 2, dz == 0 { dz = random.jiggle() }
        let length = sqrt(dx * dx + dy * dy + dz * dz)
        let scale = (radius - length) * strength * alpha / length
        values[index].vx += dx * scale
        if dimensions.rawValue > 1 { values[index].vy += dy * scale }
        if dimensions.rawValue > 2 { values[index].vz += dz * scale }
      }
    }
  }

  private static func cachedAxis(
    nodes: [ForceNode<ID>], targets: CachedValueProvider<ForceNode<ID>>,
    strengths: CachedValueProvider<ForceNode<ID>>, axis: Int
  ) -> Self {
    let target = cacheFirst(ids: nodes.map(\.id), values: targets.values(for: nodes))
    let strength = cacheFirst(ids: nodes.map(\.id), values: strengths.values(for: nodes))
    return Self { values, alpha, dimensions, _ in
      guard axis < dimensions.rawValue else { return }
      for index in values.indices {
        guard let target = target[values[index].id], let strength = strength[values[index].id],
          target.isFinite, strength.isFinite, strength >= 0
        else { continue }
        if axis == 0 { values[index].vx += (target - values[index].x) * strength * alpha }
        if axis == 1 { values[index].vy += (target - values[index].y) * strength * alpha }
        if axis == 2 { values[index].vz += (target - values[index].z) * strength * alpha }
      }
    }
  }
}

private func cacheFirst<ID: Hashable>(ids: [ID], values: [Double]) -> [ID: Double] {
  var result: [ID: Double] = [:]
  for (id, value) in zip(ids, values) where result[id] == nil { result[id] = value }
  return result
}
