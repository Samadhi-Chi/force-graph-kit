#if canImport(RealityKit) && (canImport(UIKit) || canImport(AppKit))
  import ForceGraphCore
  import ForceGraphRealityKit
  import ForceGraphScene
  import RealityKit
  import Testing

  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor @Test func stableIdentityLookupAndStaleFrameProtection() async {
    let scene: ForceGraphScene<String, String> = ForceGraphScene(
      nodes: [SceneNode(physics: ForceNode(id: "n", x: 1, y: 2), visual: NodeVisual(label: "N"))],
      dimensions: .two, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
    let controller = ForceGraphController<String, String>(scene: scene)
    let synchronizer = RealityKitGraphSynchronizer<String, String>(poolCapacity: 1)
    let frame = await controller.frame()
    synchronizer.synchronize(frame: frame)
    let entity = synchronizer.entity(forNode: "n")
    #expect(entity != nil)
    if let entity, case .node("n")? = synchronizer.element(for: entity) {
    } else {
      Issue.record("stable node lookup failed")
    }
    synchronizer.synchronize(frame: frame)
    #expect(synchronizer.entity(forNode: "n") === entity)

    await controller.beginDrag(id: "n", x: 8, y: 9)
    let newer = await controller.frame()
    synchronizer.synchronize(frame: newer)
    let newerPosition = entity?.position
    synchronizer.synchronize(frame: frame)
    #expect(entity?.position == newerPosition)

    let nextController = ForceGraphController<String, String>(
      scene: ForceGraphScene(
        nodes: [
          SceneNode(
            physics: ForceNode(id: "n", x: -4, y: -5), visual: NodeVisual(label: "replacement"))
        ], dimensions: .two, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1))
    synchronizer.beginSession()
    synchronizer.synchronize(frame: await nextController.frame())
    #expect(synchronizer.entity(forNode: "n")?.position.x == -4)
  }

  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor @Test func recycledEntitiesDoNotRetainOldIdentity() async {
    var scene: ForceGraphScene<String, String> = ForceGraphScene(
      nodes: [SceneNode(physics: ForceNode(id: "old", x: 0), visual: NodeVisual(label: "old"))],
      dimensions: .one, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
    let controller = ForceGraphController<String, String>(scene: scene)
    let synchronizer = RealityKitGraphSynchronizer<String, String>(poolCapacity: 1) { _, _ in
      Entity()
    }
    synchronizer.synchronize(frame: await controller.frame())
    guard let oldEntity = synchronizer.entity(forNode: "old") else {
      Issue.record("missing original node entity")
      return
    }
    scene.nodes = [SceneNode(physics: ForceNode(id: "new", x: 1), visual: NodeVisual(label: "new"))]
    scene.policy.labelVisibility = .all
    scene.topologyRevision = 2
    await controller.updateScene(scene, policy: .preserve)
    synchronizer.synchronize(frame: await controller.frame())
    #expect(synchronizer.entity(forNode: "old") == nil)
    #expect(synchronizer.entity(forNode: "new") === oldEntity)
    var lastDescendant: Entity?
    for child in oldEntity.children { lastDescendant = child }
    guard let descendant = lastDescendant else {
      Issue.record("reused node has no model descendant")
      return
    }
    if case .node("new")? = synchronizer.element(for: descendant) {
    } else {
      Issue.record("reused descendant retained stale identity")
    }
    synchronizer.reset()
    #expect(synchronizer.element(for: oldEntity) == nil)
  }

  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor @Test func sameRevisionMembershipAndConfigurationReapplyAreOrdered() async {
    var scene: ForceGraphScene<String, String> = ForceGraphScene(
      nodes: [SceneNode(physics: ForceNode(id: "node", x: 1), visual: NodeVisual(label: "one"))],
      dimensions: .one,
      policy: LayoutPolicy(warmupTicks: 0, labelVisibility: .all))
    let controller = ForceGraphController(scene: scene)
    let synchronizer = RealityKitGraphSynchronizer<String, String>(labelEntityFactory: { _, _ in
      Entity()
    })
    let old = await controller.frame()
    synchronizer.synchronize(frame: old)
    await controller.beginDrag(id: "node", x: 8)
    let latest = await controller.tick()
    synchronizer.synchronize(frame: latest)
    guard let entity = synchronizer.entity(forNode: "node") else {
      Issue.record("missing node entity")
      return
    }

    synchronizer.coordinateSpace.translation = GraphPosition3D(x: 10)
    synchronizer.synchronize(frame: old)
    #expect(entity.position.x == 8)
    synchronizer.synchronize(frame: latest)
    #expect(entity.position.x == 18)

    guard let oldLabel = Array(entity.children).last else {
      Issue.record("initial label factory did not create a label")
      return
    }
    synchronizer.labelEntityFactory = { _, _ in Entity() }
    synchronizer.synchronize(frame: old)
    #expect(entity.position.x == 18)
    synchronizer.synchronize(frame: latest)
    guard let newLabel = Array(entity.children).last else {
      Issue.record("label factory did not recreate a label")
      return
    }
    #expect(newLabel !== oldLabel)
    if case .node("node")? = synchronizer.element(for: newLabel) {
    } else {
      Issue.record("recreated label lost typed identity")
    }

    scene.nodes[0].visual.isVisible = false
    await controller.updateScene(scene, policy: .preserve)
    synchronizer.synchronize(frame: await controller.frame())
    #expect(synchronizer.entity(forNode: "node") == nil)
    scene.nodes[0].visual.isVisible = true
    await controller.updateScene(scene, policy: .preserve)
    synchronizer.synchronize(frame: await controller.frame())
    #expect(synchronizer.entity(forNode: "node") != nil)
  }

  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor @Test func renderSizesApplyGraphMinimumBeforeCoordinateScale() async {
    let scene: ForceGraphScene<String, String> = ForceGraphScene(
      nodes: [
        SceneNode(
          physics: ForceNode(id: "a", x: 0), visual: NodeVisual(label: "a", radius: 0.02)),
        SceneNode(
          physics: ForceNode(id: "b", x: 1), visual: NodeVisual(label: "b", radius: 0.02)),
      ],
      links: [
        SceneLink(
          id: "ab", physics: ForceLink(source: "a", target: "b"),
          visual: LinkVisual(width: 0.01))
      ], dimensions: .one, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
    let controller = ForceGraphController(scene: scene)
    let frame = await controller.frame()
    let synchronizer = RealityKitGraphSynchronizer<String, String>(
      coordinateSpace: GraphCoordinateSpace(scale: 0.01))
    synchronizer.synchronize(frame: frame)

    guard let nodeRoot = synchronizer.entity(forNode: "a"),
      let edgeRoot = synchronizer.entity(forLink: "ab")
    else {
      Issue.record("missing synchronized root entities")
      return
    }
    var nodeModel: ModelEntity?
    for child in nodeRoot.children where nodeModel == nil { nodeModel = child as? ModelEntity }
    var edgeModel: ModelEntity?
    for child in edgeRoot.children where edgeModel == nil { edgeModel = child as? ModelEntity }
    guard let nodeModel, let edgeModel else {
      Issue.record("missing synchronized model entities")
      return
    }
    #expect(abs(nodeModel.scale.x - 0.0002) < 1e-8)
    #expect(abs(edgeModel.scale.x - 0.0001) < 1e-8)

    synchronizer.coordinateSpace.scale = 10
    synchronizer.synchronize(frame: frame)
    #expect(abs(nodeModel.scale.x - 0.2) < 1e-6)
    #expect(abs(edgeModel.scale.x - 0.1) < 1e-6)

    synchronizer.coordinateSpace.scale = .nan
    synchronizer.synchronize(frame: frame)
    #expect(abs(nodeModel.scale.x - 0.02) < 1e-6)
    #expect(abs(edgeModel.scale.x - 0.01) < 1e-6)
  }
#endif
