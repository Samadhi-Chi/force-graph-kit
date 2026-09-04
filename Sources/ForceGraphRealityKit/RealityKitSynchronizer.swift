#if canImport(RealityKit) && (canImport(UIKit) || canImport(AppKit))
  import ForceGraphScene
  import RealityKit
  import simd
  #if canImport(UIKit)
    import UIKit
    private typealias PlatformColor = UIColor
    private typealias PlatformFont = UIFont
  #elseif canImport(AppKit)
    import AppKit
    private typealias PlatformColor = NSColor
    private typealias PlatformFont = NSFont
  #endif

  /// Main-actor RealityKit entity synchronizer. Apple SDK compilation remains a maintainer gate.
  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor
  public final class RealityKitGraphSynchronizer<
    ID: Hashable & Sendable, LinkID: Hashable & Sendable
  > {
    /// Root containing every graph entity.
    public let root = Entity()
    private var nodeRoots: [ID: Entity] = [:]
    private var edgeEntities: [LinkID: ModelEntity] = [:]
    private var pooledNodes: [Entity] = []
    private var pooledEdges: [ModelEntity] = []
    private var nodeVisuals: [ID: NodeVisual] = [:]

    /// Creates an empty synchronizer.
    public init() { root.name = "ForceGraphKit.Root" }

    /// Applies one authoritative frame to nodes, labels, and all edges.
    public func synchronize(frame: ForceGraphRenderFrame<ID, LinkID>) {
      let activeNodes = Set(frame.nodes.map { $0.snapshot.id })
      for id in Array(nodeRoots.keys).filter({ !activeNodes.contains($0) }) { recycleNode(id) }
      for node in frame.nodes {
        if nodeVisuals[node.snapshot.id] != node.visual { recycleNode(node.snapshot.id) }
        let entity =
          nodeRoots[node.snapshot.id] ?? makeNode(id: node.snapshot.id, visual: node.visual)
        let y = node.snapshot.y.isFinite ? node.snapshot.y : 0
        let z = node.snapshot.z.isFinite ? node.snapshot.z : 0
        entity.position = SIMD3(Float(node.snapshot.x), Float(y), Float(z))
        updateNode(entity, visual: node.visual, highlight: node.highlight)
      }

      let activeLinks = Set(frame.links.map(\.id))
      for id in Array(edgeEntities.keys).filter({ !activeLinks.contains($0) }) { recycleEdge(id) }
      for link in frame.links {
        let edge = edgeEntities[link.id] ?? makeEdge(id: link.id)
        updateEdge(edge, link: link)
      }
    }

    private func makeNode(id: ID, visual: NodeVisual) -> Entity {
      let rootEntity = pooledNodes.popLast() ?? Entity()
      rootEntity.isEnabled = true
      for child in Array(rootEntity.children) { child.removeFromParent() }
      let mesh = MeshResource.generateSphere(radius: Float(max(0.001, visual.radius)))
      let model = ModelEntity(mesh: mesh, materials: [material(visual.color)])
      model.components.set(
        CollisionComponent(shapes: [.generateSphere(radius: Float(max(0.001, visual.radius)))]))
      model.components.set(InputTargetComponent())
      rootEntity.addChild(model)
      if !visual.label.isEmpty {
        let text = MeshResource.generateText(
          visual.label, extrusionDepth: 0.001,
          font: PlatformFont.systemFont(ofSize: 0.04),
          containerFrame: .zero, alignment: .center,
          lineBreakMode: .byTruncatingTail)
        let label = ModelEntity(
          mesh: text, materials: [UnlitMaterial(color: PlatformColor.white)])
        label.position = [0, Float(visual.radius * 1.5), 0]
        rootEntity.addChild(label)
      }
      nodeRoots[id] = rootEntity
      nodeVisuals[id] = visual
      root.addChild(rootEntity)
      return rootEntity
    }

    private func updateNode(_ entity: Entity, visual: NodeVisual, highlight: HighlightState) {
      guard let model = entity.children.first as? ModelEntity else { return }
      let color =
        highlight == .dimmed
        ? GraphColor(
          red: visual.color.red, green: visual.color.green,
          blue: visual.color.blue, alpha: visual.color.alpha * 0.25)
        : visual.color
      model.model?.materials = [material(color)]
    }

    private func makeEdge(id: LinkID) -> ModelEntity {
      let edge = pooledEdges.popLast() ?? ModelEntity()
      edge.isEnabled = true
      edgeEntities[id] = edge
      root.addChild(edge)
      return edge
    }

    private func updateEdge(_ edge: ModelEntity, link: RenderLink<ID, LinkID>) {
      let source = SIMD3<Float>(
        finiteFloat(link.sourcePosition.x), finiteFloat(link.sourcePosition.y),
        finiteFloat(link.sourcePosition.z))
      let target = SIMD3<Float>(
        finiteFloat(link.targetPosition.x), finiteFloat(link.targetPosition.y),
        finiteFloat(link.targetPosition.z))
      let length = simd_distance(source, target)
      guard length.isFinite, length > 1e-7 else {
        edge.isEnabled = false
        return
      }
      edge.isEnabled = true
      edge.model = ModelComponent(
        mesh: .generateCylinder(height: length, radius: Float(max(0.0005, link.visual.width))),
        materials: [material(link.visual.color)])
      edge.position = (source + target) / 2
      edge.orientation = orientationAligningYAxis(to: (target - source) / length)
    }

    private func recycleNode(_ id: ID) {
      guard let entity = nodeRoots.removeValue(forKey: id) else { return }
      nodeVisuals[id] = nil
      entity.isEnabled = false
      entity.removeFromParent()
      pooledNodes.append(entity)
    }
    private func recycleEdge(_ id: LinkID) {
      guard let entity = edgeEntities.removeValue(forKey: id) else { return }
      entity.isEnabled = false
      entity.model = nil
      entity.removeFromParent()
      pooledEdges.append(entity)
    }
    private func material(_ color: GraphColor) -> SimpleMaterial {
      SimpleMaterial(
        color: PlatformColor(
          red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue),
          alpha: CGFloat(color.alpha)),
        roughness: 0.65, isMetallic: false)
    }

    private func finiteFloat(_ value: Double) -> Float {
      value.isFinite ? Float(value) : 0
    }

    private func orientationAligningYAxis(to direction: SIMD3<Float>) -> simd_quatf {
      let localYAxis = SIMD3<Float>(0, 1, 0)
      let cosine = max(-1, min(1, simd_dot(localYAxis, direction)))
      if cosine > 1 - 1e-6 { return simd_quatf(angle: 0, axis: localYAxis) }
      if cosine < -1 + 1e-6 {
        return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
      }
      return simd_quatf(from: localYAxis, to: direction)
    }
  }
#endif
