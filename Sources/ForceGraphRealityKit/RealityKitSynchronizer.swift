#if canImport(RealityKit) && (canImport(UIKit) || canImport(AppKit))
  import ForceGraphScene
  import RealityKit
  import simd
  #if canImport(UIKit)
    import UIKit
    private typealias PlatformColor = UIColor
  #elseif canImport(AppKit)
    import AppKit
    private typealias PlatformColor = NSColor
  #endif

  /// The stable graph identity represented by a RealityKit entity.
  public enum RealityKitGraphElement<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable
  {
    /// A node identity.
    case node(ID)
    /// A link identity.
    case link(LinkID)
  }

  /// Main-actor incremental RealityKit entity synchronizer.
  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor
  public final class RealityKitGraphSynchronizer<
    ID: Hashable & Sendable, LinkID: Hashable & Sendable
  > {
    /// Factory for application-owned label entities or attachment proxies.
    public typealias LabelEntityFactory = @MainActor (_ id: ID, _ text: String) -> Entity?

    /// Root containing every graph entity.
    public let root = Entity()
    /// Reversible coordinate policy used by rendering and drag conversion.
    public var coordinateSpace: GraphCoordinateSpace {
      didSet {
        guard coordinateSpace != oldValue else { return }
        invalidateVisualState()
        configurationNeedsReapply = true
      }
    }
    /// Maximum retained node and edge entities per pool.
    public var poolCapacity: Int {
      didSet {
        poolCapacity = max(0, poolCapacity)
        if pooledNodes.count > poolCapacity {
          pooledNodes.removeFirst(pooledNodes.count - poolCapacity)
        }
        if pooledEdges.count > poolCapacity {
          pooledEdges.removeFirst(pooledEdges.count - poolCapacity)
        }
      }
    }
    /// Optional factory invoked only when a visible label needs creation.
    public var labelEntityFactory: LabelEntityFactory? {
      didSet { discardLabels() }
    }

    private struct NodeRecord {
      let root: Entity
      let model: ModelEntity
      var label: Entity?
      var visual: NodeVisual?
      var highlight: HighlightState?
    }
    private struct EdgeRecord {
      let root: Entity
      let shaft: ModelEntity
      let arrow: ModelEntity
      var visual: LinkVisual?
      var highlight: HighlightState?
    }
    private var nodes: [ID: NodeRecord] = [:]
    private var edges: [LinkID: EdgeRecord] = [:]
    private var reverse: [ObjectIdentifier: RealityKitGraphElement<ID, LinkID>] = [:]
    private var pooledNodes: [(Entity, ModelEntity)] = []
    private var pooledEdges: [(Entity, ModelEntity, ModelEntity)] = []
    private var lastSequence: UInt64?
    private var lastTopologyRevision: UInt64?
    private var configurationNeedsReapply = false
    private let sphereMesh = MeshResource.generateSphere(radius: 1)
    private let cylinderMesh = MeshResource.generateCylinder(height: 1, radius: 1)
    private let arrowMesh = MeshResource.generateCone(height: 1, radius: 0.5)

    /// Creates an empty synchronizer with bounded pooling.
    public init(
      coordinateSpace: GraphCoordinateSpace = GraphCoordinateSpace(), poolCapacity: Int = 256,
      labelEntityFactory: LabelEntityFactory? = nil
    ) {
      self.coordinateSpace = coordinateSpace
      self.poolCapacity = max(0, poolCapacity)
      self.labelEntityFactory = labelEntityFactory
      root.name = "ForceGraphKit.Root"
    }

    /// Returns the stable node entity, when currently active.
    public func entity(forNode id: ID) -> Entity? { nodes[id]?.root }
    /// Returns the stable link entity, when currently active.
    public func entity(forLink id: LinkID) -> Entity? { edges[id]?.root }
    /// Resolves an entity or any descendant without encoding IDs into names.
    public func element(for entity: Entity) -> RealityKitGraphElement<ID, LinkID>? {
      var candidate: Entity? = entity
      while let current = candidate {
        if let value = reverse[ObjectIdentifier(current)] { return value }
        candidate = current.parent
      }
      return nil
    }
    /// Converts a RealityKit-space drag point back to graph coordinates.
    public func graphPosition(for realityPosition: SIMD3<Float>) -> GraphPosition3D {
      coordinateSpace.graphPosition(
        forRenderer: GraphPosition3D(
          x: Double(realityPosition.x), y: Double(realityPosition.y), z: Double(realityPosition.z)))
    }

    /// Starts a producer session whose sequence may begin at zero while retaining reusable entities.
    /// Call this before consuming frames from a different controller or restarted sequence domain.
    public func beginSession() {
      lastSequence = nil
      lastTopologyRevision = nil
      configurationNeedsReapply = false
    }

    /// Clears sequence state, active identity mappings, entities, and bounded pools.
    public func reset() {
      for id in Array(nodes.keys) { recycleNode(id) }
      for id in Array(edges.keys) { recycleEdge(id) }
      pooledNodes.removeAll(keepingCapacity: false)
      pooledEdges.removeAll(keepingCapacity: false)
      reverse.removeAll(keepingCapacity: false)
      lastSequence = nil
      lastTopologyRevision = nil
      configurationNeedsReapply = false
    }

    /// Applies one authoritative frame. Duplicate or older sequence numbers are ignored.
    public func synchronize(frame: ForceGraphRenderFrame<ID, LinkID>) {
      if let lastSequence {
        if frame.sequence < lastSequence { return }
        if frame.sequence == lastSequence, !configurationNeedsReapply { return }
      }
      lastSequence = frame.sequence
      configurationNeedsReapply = false
      if lastTopologyRevision != frame.topologyRevision {
        reconcileTopology(frame)
        lastTopologyRevision = frame.topologyRevision
      }
      for node in frame.nodes { updateNode(node) }
      for link in frame.links { updateEdge(link) }
    }

    private func reconcileTopology(_ frame: ForceGraphRenderFrame<ID, LinkID>) {
      let nodeIDs = Set(frame.nodes.map(\.snapshot.id))
      for id in nodes.keys where !nodeIDs.contains(id) { recycleNode(id) }
      let linkIDs = Set(frame.links.map(\.id))
      for id in edges.keys where !linkIDs.contains(id) { recycleEdge(id) }
      for node in frame.nodes where nodes[node.snapshot.id] == nil {
        makeNode(id: node.snapshot.id)
      }
      for link in frame.links where edges[link.id] == nil { makeEdge(id: link.id) }
    }

    private func makeNode(id: ID) {
      let pair = pooledNodes.popLast() ?? (Entity(), ModelEntity(mesh: sphereMesh, materials: []))
      pair.0.isEnabled = true
      if pair.1.parent == nil { pair.0.addChild(pair.1) }
      root.addChild(pair.0)
      nodes[id] = NodeRecord(root: pair.0, model: pair.1)
      reverse[ObjectIdentifier(pair.0)] = .node(id)
      reverse[ObjectIdentifier(pair.1)] = .node(id)
    }

    private func updateNode(_ node: RenderNode<ID>) {
      guard var record = nodes[node.snapshot.id] else { return }
      let priorLabel = record.visual?.label
      let position = coordinateSpace.rendererPosition(
        forGraph: GraphPosition3D(
          x: node.snapshot.x, y: node.snapshot.y, z: node.snapshot.z))
      record.root.position = [finite(position.x), finite(position.y), finite(position.z)]
      let radius = renderSize(node.visual.radius, minimum: 0.001)
      record.model.scale = [radius, radius, radius]
      if record.visual != node.visual || record.highlight != node.highlight {
        record.model.model?.materials = [material(node.visual.color, highlight: node.highlight)]
        // The model carries radius as scale. Collision lives on the unscaled root to avoid
        // applying radius twice through shape size and entity scale.
        record.root.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
        record.root.components.set(InputTargetComponent())
        record.visual = node.visual
        record.highlight = node.highlight
      }
      if priorLabel != nil, priorLabel != node.visual.label, let label = record.label {
        reverse[ObjectIdentifier(label)] = nil
        label.removeFromParent()
        record.label = nil
      }
      if node.isLabelVisible, record.label == nil {
        record.label = labelEntityFactory?(node.snapshot.id, node.visual.label)
        if let label = record.label {
          record.root.addChild(label)
          reverse[ObjectIdentifier(label)] = .node(node.snapshot.id)
        }
      }
      record.label?.isEnabled = node.isLabelVisible
      nodes[node.snapshot.id] = record
    }

    private func makeEdge(id: LinkID) {
      let triple =
        pooledEdges.popLast() ?? (
          Entity(), ModelEntity(mesh: cylinderMesh, materials: []),
          ModelEntity(mesh: arrowMesh, materials: [])
        )
      triple.0.isEnabled = true
      if triple.1.parent == nil { triple.0.addChild(triple.1) }
      if triple.2.parent == nil { triple.0.addChild(triple.2) }
      root.addChild(triple.0)
      edges[id] = EdgeRecord(root: triple.0, shaft: triple.1, arrow: triple.2)
      reverse[ObjectIdentifier(triple.0)] = .link(id)
      reverse[ObjectIdentifier(triple.1)] = .link(id)
      reverse[ObjectIdentifier(triple.2)] = .link(id)
    }

    private func updateEdge(_ link: RenderLink<ID, LinkID>) {
      guard var record = edges[link.id] else { return }
      let a = coordinateSpace.rendererPosition(
        forGraph: GraphPosition3D(
          x: link.sourcePosition.x, y: link.sourcePosition.y, z: link.sourcePosition.z))
      let b = coordinateSpace.rendererPosition(
        forGraph: GraphPosition3D(
          x: link.targetPosition.x, y: link.targetPosition.y, z: link.targetPosition.z))
      let source = SIMD3<Float>(finite(a.x), finite(a.y), finite(a.z))
      let target = SIMD3<Float>(finite(b.x), finite(b.y), finite(b.z))
      let length = simd_distance(source, target)
      guard length.isFinite, length > 1e-7 else {
        record.root.isEnabled = false
        return
      }
      record.root.isEnabled = true
      record.root.position = (source + target) / 2
      record.root.orientation = orientationAligningYAxis(to: (target - source) / length)
      let width = renderSize(link.visual.width, minimum: 0.0005)
      record.shaft.scale = [width, length, width]
      record.arrow.isEnabled = link.visual.isDirectional
      record.arrow.position = [0, length / 2, 0]
      record.arrow.scale = [width * 2.5, width * 4, width * 2.5]
      if record.visual != link.visual || record.highlight != link.highlight {
        let value = material(link.visual.color, highlight: link.highlight)
        record.shaft.model?.materials = [value]
        record.arrow.model?.materials = [value]
        record.visual = link.visual
        record.highlight = link.highlight
      }
      edges[link.id] = record
    }

    private func recycleNode(_ id: ID) {
      guard let value = nodes.removeValue(forKey: id) else { return }
      reverse[ObjectIdentifier(value.root)] = nil
      reverse[ObjectIdentifier(value.model)] = nil
      if let label = value.label { reverse[ObjectIdentifier(label)] = nil }
      value.label?.removeFromParent()
      value.root.removeFromParent()
      value.root.isEnabled = false
      if pooledNodes.count < poolCapacity { pooledNodes.append((value.root, value.model)) }
    }
    private func recycleEdge(_ id: LinkID) {
      guard let value = edges.removeValue(forKey: id) else { return }
      reverse[ObjectIdentifier(value.root)] = nil
      reverse[ObjectIdentifier(value.shaft)] = nil
      reverse[ObjectIdentifier(value.arrow)] = nil
      value.root.removeFromParent()
      value.root.isEnabled = false
      if pooledEdges.count < poolCapacity {
        pooledEdges.append((value.root, value.shaft, value.arrow))
      }
    }
    private func material(_ color: GraphColor, highlight: HighlightState) -> SimpleMaterial {
      let multiplier: Double
      switch highlight {
      case .dimmed: multiplier = 0.22
      case .selected, .hovered: multiplier = 1
      default: multiplier = 0.72
      }
      return SimpleMaterial(
        color: PlatformColor(
          red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue),
          alpha: CGFloat(color.alpha * multiplier)),
        roughness: highlight == .selected ? 0.25 : 0.65,
        isMetallic: highlight == .hovered)
    }
    private func finite(_ value: Double) -> Float {
      guard value.isFinite else { return 0 }
      return Float(max(-1_000_000, min(1_000_000, value)))
    }
    private func renderSize(_ value: Double, minimum: Double) -> Float {
      let scale =
        coordinateSpace.scale.isFinite && coordinateSpace.scale > 0
        ? coordinateSpace.scale : 1
      let graphSize = max(minimum, value.isFinite ? value : minimum)
      let scaled = graphSize * scale
      guard scaled.isFinite else { return 1_000_000 }
      return Float(min(1_000_000, max(Double(Float.leastNormalMagnitude), scaled)))
    }
    private func orientationAligningYAxis(to direction: SIMD3<Float>) -> simd_quatf {
      let axis = SIMD3<Float>(0, 1, 0)
      let cosine = max(-1, min(1, simd_dot(axis, direction)))
      if cosine > 1 - 1e-6 { return simd_quatf(angle: 0, axis: axis) }
      if cosine < -1 + 1e-6 { return simd_quatf(angle: .pi, axis: [1, 0, 0]) }
      return simd_quatf(from: axis, to: direction)
    }

    private func invalidateVisualState() {
      for id in Array(nodes.keys) {
        nodes[id]?.visual = nil
        nodes[id]?.highlight = nil
      }
      for id in Array(edges.keys) {
        edges[id]?.visual = nil
        edges[id]?.highlight = nil
      }
    }

    private func discardLabels() {
      for id in Array(nodes.keys) {
        guard var record = nodes[id], let label = record.label else { continue }
        reverse[ObjectIdentifier(label)] = nil
        label.removeFromParent()
        record.label = nil
        nodes[id] = record
      }
      configurationNeedsReapply = true
    }
  }
#endif
