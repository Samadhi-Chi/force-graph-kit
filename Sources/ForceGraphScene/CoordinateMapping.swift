import ForceGraphCore

/// A renderer-neutral three-component position used at coordinate-system boundaries.
public struct GraphPosition3D: Sendable, Equatable {
  /// First coordinate.
  public var x: Double
  /// Second coordinate.
  public var y: Double
  /// Third coordinate.
  public var z: Double
  /// Creates a position, replacing non-finite components with zero.
  public init(x: Double, y: Double = 0, z: Double = 0) {
    self.x = x.isFinite ? x : 0
    self.y = y.isFinite ? y : 0
    self.z = z.isFinite ? z : 0
  }
}

/// Maps graph axes into a renderer's three-dimensional coordinates.
public enum GraphAxisMapping: Sendable, Equatable {
  /// Graph `(x,y,z)` maps directly to renderer `(x,y,z)`.
  case xyz
  /// A 2D graph occupies the renderer XY plane.
  case xy
  /// A 2D graph occupies the renderer XZ plane: graph y maps to renderer z.
  case xz
  /// A 2D graph occupies the renderer YZ plane: graph x/y map to renderer y/z.
  case yz
}

/// Reversible uniform graph-to-renderer transform with an explicit axis convention.
public struct GraphCoordinateSpace: Sendable, Equatable {
  /// Axis convention applied after graph-space scale and translation.
  public var axes: GraphAxisMapping
  /// Positive uniform scale.
  public var scale: Double
  /// Translation in renderer coordinates.
  public var translation: GraphPosition3D

  /// Creates a reversible coordinate transform.
  public init(
    axes: GraphAxisMapping = .xyz, scale: Double = 1,
    translation: GraphPosition3D = GraphPosition3D(x: 0)
  ) {
    self.axes = axes
    self.scale = scale.isFinite && scale > 0 ? scale : 1
    self.translation = translation
  }

  /// Converts graph coordinates to renderer coordinates.
  public func rendererPosition(forGraph position: GraphPosition3D) -> GraphPosition3D {
    let position = Self.sanitized(position)
    let scale = validScale
    let translation = Self.sanitized(translation)
    let mapped: GraphPosition3D
    switch axes {
    case .xyz, .xy: mapped = position
    case .xz: mapped = GraphPosition3D(x: position.x, y: position.z, z: position.y)
    case .yz: mapped = GraphPosition3D(x: position.z, y: position.x, z: position.y)
    }
    return GraphPosition3D(
      x: mapped.x * scale + translation.x,
      y: mapped.y * scale + translation.y,
      z: mapped.z * scale + translation.z)
  }

  /// Converts a renderer coordinate back into graph coordinates for dragging and picking.
  public func graphPosition(forRenderer position: GraphPosition3D) -> GraphPosition3D {
    let position = Self.sanitized(position)
    let scale = validScale
    let translation = Self.sanitized(translation)
    let mapped = GraphPosition3D(
      x: (position.x - translation.x) / scale,
      y: (position.y - translation.y) / scale,
      z: (position.z - translation.z) / scale)
    switch axes {
    case .xyz, .xy: return mapped
    case .xz: return GraphPosition3D(x: mapped.x, y: mapped.z, z: mapped.y)
    case .yz: return GraphPosition3D(x: mapped.y, y: mapped.z, z: mapped.x)
    }
  }

  private var validScale: Double { scale.isFinite && scale > 0 ? scale : 1 }

  private static func sanitized(_ position: GraphPosition3D) -> GraphPosition3D {
    GraphPosition3D(x: position.x, y: position.y, z: position.z)
  }

  /// Fits graph bounds uniformly inside a renderer volume by reusing Core's fit algorithm.
  public static func fitting(
    bounds: LayoutBounds, dimensions: SimulationDimensions, axes: GraphAxisMapping = .xyz,
    volume: GraphPosition3D, padding: Double = 0.05
  ) -> Self {
    let activeBounds = LayoutBounds(
      minimumX: bounds.minimumX,
      minimumY: dimensions == .one ? 0 : bounds.minimumY,
      minimumZ: dimensions == .three ? bounds.minimumZ : 0,
      maximumX: bounds.maximumX,
      maximumY: dimensions == .one ? 0 : bounds.maximumY,
      maximumZ: dimensions == .three ? bounds.maximumZ : 0)
    let graphVolume: GraphPosition3D
    switch axes {
    case .xyz, .xy: graphVolume = volume
    case .xz: graphVolume = GraphPosition3D(x: volume.x, y: volume.z, z: volume.y)
    case .yz: graphVolume = GraphPosition3D(x: volume.y, y: volume.z, z: volume.x)
    }
    let fit = fitTransform(
      bounds: activeBounds, width: graphVolume.x, height: graphVolume.y,
      depth: graphVolume.z, padding: padding)
    let origin = GraphCoordinateSpace(axes: axes, scale: fit.scale)
      .rendererPosition(
        forGraph: GraphPosition3D(
          x: fit.translateX / fit.scale, y: fit.translateY / fit.scale,
          z: dimensions == .three ? fit.translateZ / fit.scale : 0))
    return Self(axes: axes, scale: fit.scale, translation: origin)
  }
}
