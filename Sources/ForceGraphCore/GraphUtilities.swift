import Foundation

/// Diagnostics produced while validating stable graph identity and endpoints.
public struct GraphDiagnostics<ID: Hashable & Sendable>: Sendable {
  /// Duplicate node identifiers, in first repeated occurrence order.
  public let duplicateNodeIDs: [ID]
  /// Links whose source or target cannot be resolved.
  public let unresolvedLinks: [ForceLink<ID>]
  /// Self-referential links.
  public let selfLinks: [ForceLink<ID>]
  /// Whether no diagnostic issue was found.
  public var isValid: Bool {
    duplicateNodeIDs.isEmpty && unresolvedLinks.isEmpty && selfLinks.isEmpty
  }
}

/// Validates graph identity without mutating it.
public func validateGraph<ID>(nodes: [ForceNode<ID>], links: [ForceLink<ID>]) -> GraphDiagnostics<
  ID
> {
  var seen = Set<ID>()
  var duplicates: [ID] = []
  for node in nodes where !seen.insert(node.id).inserted && !duplicates.contains(node.id) {
    duplicates.append(node.id)
  }
  let unresolved = links.filter { !seen.contains($0.source) || !seen.contains($0.target) }
  let selfLinks = links.filter { $0.source == $0.target }
  return GraphDiagnostics(
    duplicateNodeIDs: duplicates, unresolvedLinks: unresolved, selfLinks: selfLinks)
}

/// An incremental node change keyed by stable identity.
public enum NodeDelta<ID: Hashable & Sendable>: Sendable {
  /// Inserts a node if its ID does not exist.
  case insert(ForceNode<ID>)
  /// Inserts a missing node or preserves all state of an existing node with the same ID.
  case upsert(ForceNode<ID>)
  /// Applies an explicit state update to an existing node; missing IDs are ignored.
  case update(id: ID, state: NodeStateUpdate)
  /// Removes a node by ID.
  case remove(ID)
}

/// Explicit stable-ID node state changes. `nil` scalar fields preserve current values.
public struct NodeStateUpdate: Sendable {
  /// Optional replacement positions.
  public var x: Double?
  public var y: Double?
  public var z: Double?
  /// Optional replacement velocities.
  public var vx: Double?
  public var vy: Double?
  public var vz: Double?
  /// Fixed-coordinate operations.
  public var fx: FixedCoordinateUpdate
  public var fy: FixedCoordinateUpdate
  public var fz: FixedCoordinateUpdate

  /// Creates an explicit update. Non-finite scalar/set values are ignored when applied.
  public init(
    x: Double? = nil, y: Double? = nil, z: Double? = nil,
    vx: Double? = nil, vy: Double? = nil, vz: Double? = nil,
    fx: FixedCoordinateUpdate = .preserve,
    fy: FixedCoordinateUpdate = .preserve,
    fz: FixedCoordinateUpdate = .preserve
  ) {
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

/// An explicit operation for a node's optional fixed coordinate.
public enum FixedCoordinateUpdate: Sendable {
  /// Leaves the fixed coordinate unchanged.
  case preserve
  /// Removes the fixed coordinate.
  case clear
  /// Sets a finite fixed coordinate; non-finite values are ignored.
  case set(Double)
}

/// An incremental link change keyed by an application-defined stable link identifier.
public enum LinkDelta<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable {
  /// Inserts or replaces a link and retains its existing order when replacing.
  case upsert(id: LinkID, link: ForceLink<ID>)
  /// Removes a link by stable link ID.
  case remove(LinkID)
}

/// Applies stable-ID link deltas while retaining unaffected order.
public func applying<ID, LinkID>(
  _ deltas: [LinkDelta<ID, LinkID>],
  to links: [(id: LinkID, link: ForceLink<ID>)]
) -> [(id: LinkID, link: ForceLink<ID>)] {
  var result = links
  for delta in deltas {
    switch delta {
    case .upsert(let id, let link):
      if let index = result.firstIndex(where: { $0.id == id }) {
        result[index].link = link
      } else {
        result.append((id, link))
      }
    case .remove(let id):
      result.removeAll { $0.id == id }
    }
  }
  return result
}

extension ForceSimulation {
  /// Applies stable-ID node deltas. Existing dynamics survive upserts; inserted nodes are
  /// initialized together once. Duplicate inserts are reported and ignored.
  /// - Returns: IDs that conflicted with existing nodes.
  @discardableResult
  public mutating func apply(_ deltas: [NodeDelta<ID>]) -> [ID] {
    var result = nodes
    var conflicts: [ID] = []
    for delta in deltas {
      switch delta {
      case .insert(let node):
        if result.contains(where: { $0.id == node.id }) {
          conflicts.append(node.id)
        } else {
          result.append(node)
        }
      case .upsert(let node):
        if !result.contains(where: { $0.id == node.id }) { result.append(node) }
      case .update(let id, let state):
        guard let index = result.firstIndex(where: { $0.id == id }) else { continue }
        apply(state, to: &result[index])
      case .remove(let id):
        result.removeAll { $0.id == id }
      }
    }
    replaceNodes(result)
    return conflicts
  }

  private func apply(_ state: NodeStateUpdate, to node: inout ForceNode<ID>) {
    if let value = state.x, value.isFinite { node.x = value }
    if let value = state.y, value.isFinite { node.y = value }
    if let value = state.z, value.isFinite { node.z = value }
    if let value = state.vx, value.isFinite { node.vx = value }
    if let value = state.vy, value.isFinite { node.vy = value }
    if let value = state.vz, value.isFinite { node.vz = value }
    updateFixed(state.fx, value: &node.fx)
    updateFixed(state.fy, value: &node.fy)
    updateFixed(state.fz, value: &node.fz)
  }

  private func updateFixed(_ update: FixedCoordinateUpdate, value: inout Double?) {
    switch update {
    case .preserve: break
    case .clear: value = nil
    case .set(let replacement) where replacement.isFinite: value = replacement
    case .set: break
    }
  }
}

/// Axis-aligned bounds over active dimensions.
public struct LayoutBounds: Sendable, Equatable {
  /// Minimum x coordinate.
  public let minimumX: Double
  /// Minimum y coordinate.
  public let minimumY: Double
  /// Minimum z coordinate.
  public let minimumZ: Double
  /// Maximum x coordinate.
  public let maximumX: Double
  /// Maximum y coordinate.
  public let maximumY: Double
  /// Maximum z coordinate.
  public let maximumZ: Double
  /// Width on x.
  public var width: Double { maximumX - minimumX }
  /// Height on y.
  public var height: Double { maximumY - minimumY }
  /// Depth on z.
  public var depth: Double { maximumZ - minimumZ }
  /// Creates explicit finite or diagnostic bounds.
  public init(
    minimumX: Double, minimumY: Double, minimumZ: Double,
    maximumX: Double, maximumY: Double, maximumZ: Double
  ) {
    self.minimumX = minimumX
    self.minimumY = minimumY
    self.minimumZ = minimumZ
    self.maximumX = maximumX
    self.maximumY = maximumY
    self.maximumZ = maximumZ
  }
}

/// Uniform translation and scale for fitting a layout into a renderer-owned volume.
public struct FitTransform: Sendable, Equatable {
  /// Uniform scale.
  public let scale: Double
  /// X translation applied after scaling.
  public let translateX: Double
  /// Y translation applied after scaling.
  public let translateY: Double
  /// Z translation applied after scaling.
  public let translateZ: Double
  /// Applies the transform to a position.
  public func apply(x: Double, y: Double, z: Double) -> (x: Double, y: Double, z: Double) {
    (x * scale + translateX, y * scale + translateY, z * scale + translateZ)
  }
}

/// Computes finite bounds, or `nil` for no finite positions.
public func layoutBounds<ID>(of nodes: [ForceNode<ID>], dimensions: SimulationDimensions)
  -> LayoutBounds?
{
  let valid = nodes.filter {
    $0.x.isFinite && (dimensions == .one || $0.y.isFinite)
      && (dimensions != .three || $0.z.isFinite)
  }
  guard let first = valid.first else { return nil }
  var minX = first.x
  var maxX = first.x
  var minY = first.y
  var maxY = first.y
  var minZ = first.z
  var maxZ = first.z
  for node in valid.dropFirst() {
    minX = min(minX, node.x)
    maxX = max(maxX, node.x)
    if dimensions.rawValue > 1 {
      minY = min(minY, node.y)
      maxY = max(maxY, node.y)
    }
    if dimensions.rawValue > 2 {
      minZ = min(minZ, node.z)
      maxZ = max(maxZ, node.z)
    }
  }
  return LayoutBounds(
    minimumX: minX, minimumY: minY, minimumZ: minZ,
    maximumX: maxX, maximumY: maxY, maximumZ: maxZ)
}

/// Computes a centered, uniform fit transform. Invalid/nonpositive volume dimensions return identity.
public func fitTransform(
  bounds: LayoutBounds, width: Double, height: Double, depth: Double, padding: Double = 0.1
) -> FitTransform {
  guard width.isFinite, height.isFinite, depth.isFinite, width > 0, height > 0, depth > 0,
    padding.isFinite, padding >= 0, padding < 1
  else {
    return FitTransform(scale: 1, translateX: 0, translateY: 0, translateZ: 0)
  }
  let available = 1 - padding * 2
  let candidates = [(bounds.width, width), (bounds.height, height), (bounds.depth, depth)]
    .compactMap { $0.0 > 0 ? $0.1 * available / $0.0 : nil }
  let scale = candidates.min() ?? 1
  let cx = (bounds.minimumX + bounds.maximumX) / 2
  let cy = (bounds.minimumY + bounds.maximumY) / 2
  let cz = (bounds.minimumZ + bounds.maximumZ) / 2
  return FitTransform(
    scale: scale, translateX: -cx * scale,
    translateY: -cy * scale, translateZ: -cz * scale)
}
