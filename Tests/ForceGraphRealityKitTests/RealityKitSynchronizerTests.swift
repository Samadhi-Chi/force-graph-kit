#if canImport(RealityKit) && (canImport(UIKit) || canImport(AppKit))
  import ForceGraphCore
  import ForceGraphRealityKit
  import ForceGraphScene
  import RealityKit
  import Testing

  @available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
  @MainActor @Test func stableIdentityLookupAndStaleFrameProtection() async {
    let scene = ForceGraphScene(
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
    var scene = ForceGraphScene(
      nodes: [SceneNode(physics: ForceNode(id: "old", x: 0), visual: NodeVisual(label: "old"))],
      dimensions: .one, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
    let controller = ForceGraphController<String, String>(scene: scene)
    let synchronizer = RealityKitGraphSynchronizer<String, String>(poolCapacity: 1) { _, _ in
      Entity()
    }
    synchronizer.synchronize(frame: await controller.frame())
    let oldEntity = synchronizer.entity(forNode: "old")!
    scene.nodes = [SceneNode(physics: ForceNode(id: "new", x: 1), visual: NodeVisual(label: "new"))]
    scene.policy.labelVisibility = .all
    scene.topologyRevision = 2
    await controller.updateScene(scene, policy: .preserve)
    synchronizer.synchronize(frame: await controller.frame())
    #expect(synchronizer.entity(forNode: "old") == nil)
    #expect(synchronizer.entity(forNode: "new") === oldEntity)
    if case .node("new")? = synchronizer.element(for: oldEntity.children.last!) {
    } else {
      Issue.record("reused descendant retained stale identity")
    }
    synchronizer.reset()
    #expect(synchronizer.element(for: oldEntity) == nil)
  }
#endif
