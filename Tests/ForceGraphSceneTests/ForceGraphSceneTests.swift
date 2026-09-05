import ForceGraphCore
import ForceGraphScene
import Testing

private func sampleScene() -> ForceGraphScene<String, String> {
  ForceGraphScene(
    nodes: [
      SceneNode(physics: ForceNode(id: "a", x: 0, y: 0), visual: NodeVisual(label: "A")),
      SceneNode(physics: ForceNode(id: "b", x: 20, y: 0), visual: NodeVisual(label: "B")),
      SceneNode(physics: ForceNode(id: "c", x: 40, y: 0), visual: NodeVisual(label: "C")),
    ],
    links: [
      SceneLink(id: "ab", physics: ForceLink(source: "a", target: "b")),
      SceneLink(id: "bc", physics: ForceLink(source: "b", target: "c")),
    ], dimensions: .two, policy: LayoutPolicy(warmupTicks: 0))
}

@Test func filteringIsStableAndRemovesDanglingLinks() {
  let filtered = sampleScene().filtered { $0.physics.id != "b" }
  #expect(filtered.nodes.map { $0.physics.id } == ["a", "c"])
  #expect(filtered.links.isEmpty)
}

@Test func selectionHighlightsNeighbors() async {
  let controller = ForceGraphController(scene: sampleScene())
  await controller.select("a")
  let frame = await controller.frame()
  #expect(frame.nodes.first { $0.snapshot.id == "a" }?.highlight == .selected)
  #expect(frame.nodes.first { $0.snapshot.id == "b" }?.highlight == .connected)
  #expect(frame.nodes.first { $0.snapshot.id == "c" }?.highlight == .dimmed)
}

@Test func dragUsesOneTransformForNodesEdgesAndLabels() async {
  let controller = ForceGraphController(scene: sampleScene())
  await controller.beginDrag(id: "a", x: 9, y: 8)
  let frame = await controller.tick()
  let node = frame.nodes.first { $0.snapshot.id == "a" }!
  let edge = frame.links.first { $0.id == "ab" }!
  #expect(node.snapshot.x == 9 && node.snapshot.y == 8)
  #expect(edge.sourcePosition.x == node.snapshot.x && edge.sourcePosition.y == node.snapshot.y)
  #expect(node.snapshot.fx == 9 && node.visual.label == "A")
  await controller.endDrag(id: "a")
  #expect((await controller.frame()).nodes.first { $0.snapshot.id == "a" }?.snapshot.fx == nil)
}

@Test func sceneUpdatePreservesPositionByStableID() async {
  let controller = ForceGraphController(scene: sampleScene())
  await controller.beginDrag(id: "a", x: 7, y: 6)
  _ = await controller.tick()
  var updated = sampleScene()
  updated.nodes[0].visual.label = "Updated"
  await controller.updateScene(updated)
  let node = (await controller.frame()).nodes.first { $0.snapshot.id == "a" }!
  #expect(node.snapshot.x == 7 && node.visual.label == "Updated")
}

@Test func draggingMovesALinkedNeighborAndCanKeepPin() async {
  let controller = ForceGraphController(scene: sampleScene())
  let before = await controller.frame()
  let oldNeighborX = before.nodes.first { $0.snapshot.id == "b" }!.snapshot.x
  await controller.beginDrag(id: "a", x: 100, y: 0)
  let during = await controller.tick(iterations: 3)
  let neighbor = during.nodes.first { $0.snapshot.id == "b" }!
  #expect(neighbor.snapshot.x != oldNeighborX)
  let incident = during.links.first { $0.id == "ab" }!
  #expect(incident.targetPosition.x == neighbor.snapshot.x)
  await controller.endDrag(id: "a", keepPinned: true)
  #expect((await controller.frame()).nodes.first { $0.snapshot.id == "a" }?.snapshot.fx == 100)
}

@Test func visibilityDirectionDimensionsAndMissingInteractionsAreCoherent() async {
  var scene = sampleScene()
  scene.nodes[1].visual.isVisible = false
  scene.links[0].visual.isDirectional = true
  scene.dimensions = .three
  let controller = ForceGraphController(scene: scene)
  await controller.select("missing")
  await controller.hover("missing")
  await controller.focus("missing")
  await controller.beginDrag(id: "missing", x: 3, y: 4, z: 5)
  let frame = await controller.frame()
  #expect(frame.dimensions == .three)
  #expect(frame.selectedID == nil && frame.focusedID == nil)
  #expect(frame.nodes.map(\.snapshot.id) == ["a", "c"])
  #expect(frame.links.isEmpty)
}

@Test func sceneDiagnosticsNormalizeDuplicateAndDanglingData() async {
  var scene = sampleScene()
  scene.nodes.append(scene.nodes[0])
  scene.links.append(scene.links[0])
  scene.links.append(SceneLink(id: "missing", physics: ForceLink(source: "a", target: "z")))
  scene.links.append(SceneLink(id: "self", physics: ForceLink(source: "a", target: "a")))
  let diagnostics = scene.diagnostics()
  #expect(diagnostics.duplicateNodeIDs == ["a"])
  #expect(diagnostics.duplicateLinkIDs == ["ab"])
  #expect(diagnostics.unresolvedLinkIDs == ["missing"])
  #expect(diagnostics.selfLinkIDs == ["self"])
  let controller = ForceGraphController(scene: scene)
  let frame = await controller.frame()
  #expect(frame.nodes.count == 3 && frame.links.count == 2)
}

@Test func intentStreamEmitsSelectionFocusDetailsAndFit() async {
  let controller = ForceGraphController(scene: sampleScene())
  let stream = await controller.intents()
  var iterator = stream.makeAsyncIterator()
  await controller.select("a")
  await controller.focus("b")
  await controller.requestDetails(for: "c")
  await controller.requestFit()
  guard case .selected("a")? = await iterator.next() else {
    Issue.record("missing selection intent")
    return
  }
  guard case .focused("b")? = await iterator.next() else {
    Issue.record("missing focus intent")
    return
  }
  guard case .details("c")? = await iterator.next() else {
    Issue.record("missing details intent")
    return
  }
  guard case .fitRequested? = await iterator.next() else {
    Issue.record("missing fit intent")
    return
  }
}

@Test func sceneVisualInputsAreSanitized() {
  let color = GraphColor(red: -1, green: 2, blue: .nan, alpha: .infinity)
  #expect(color == GraphColor(red: 0, green: 1, blue: 0, alpha: 0))
  let node = NodeVisual(label: "safe", radius: .nan, value: .infinity)
  let link = LinkVisual(width: -.infinity)
  #expect(node.radius == 0 && node.value == 0 && link.width == 0)
}

@Test func visibleFramesRetainSizingLabelsAndDirectionMetadata() async {
  var scene = sampleScene()
  scene.nodes[0].visual.radius = 3
  scene.nodes[0].visual.value = 9
  scene.links[0].visual.isDirectional = true
  let controller = ForceGraphController(scene: scene)
  let frame = await controller.frame()
  let node = frame.nodes.first { $0.snapshot.id == "a" }!
  let link = frame.links.first { $0.id == "ab" }!
  #expect(node.visual.label == "A" && node.visual.radius == 3 && node.visual.value == 9)
  #expect(link.visual.isDirectional)
}

@Test func sceneReplacementSwitchesDimensionsAndReportsDiagnostics() async {
  let controller = ForceGraphController(scene: sampleScene())
  var updated = sampleScene()
  updated.dimensions = .three
  updated.links.append(SceneLink(id: "bad", physics: ForceLink(source: "a", target: "missing")))
  let diagnostics = await controller.updateScene(updated)
  #expect(diagnostics.unresolvedLinkIDs == ["bad"])
  let frame = await controller.frame()
  #expect(frame.dimensions == .three)
  #expect(frame.links.map(\.id) == ["ab", "bc"])
  #expect(frame.nodes.allSatisfy { $0.snapshot.z.isFinite })
}

@Test func coordinateMappingRoundTripsAndFitsCoreBounds() {
  let point = GraphPosition3D(x: 2, y: -3, z: 4)
  for axes in [GraphAxisMapping.xyz, .xy, .xz, .yz] {
    let space = GraphCoordinateSpace(
      axes: axes, scale: 2.5, translation: GraphPosition3D(x: 1, y: 2, z: 3))
    let roundTrip = space.graphPosition(forRenderer: space.rendererPosition(forGraph: point))
    #expect(abs(roundTrip.x - point.x) < 1e-12)
    #expect(abs(roundTrip.y - point.y) < 1e-12)
    #expect(abs(roundTrip.z - point.z) < 1e-12)
  }
  let bounds = LayoutBounds(
    minimumX: -10, minimumY: -5, minimumZ: -2,
    maximumX: 10, maximumY: 5, maximumZ: 2)
  let fit = GraphCoordinateSpace.fitting(
    bounds: bounds, dimensions: .three, axes: .xz,
    volume: GraphPosition3D(x: 2, y: 1, z: 2), padding: 0)
  #expect(fit.scale == 0.1)
}

@Test func labelsUseIndependentStablePoliciesAndRevisions() async {
  var scene = sampleScene()
  scene.policy.labelVisibility = .selectedAndNeighbors
  scene.topologyRevision = 4
  scene.visualRevision = 7
  let controller = ForceGraphController(scene: scene)
  #expect((await controller.frame()).nodes.allSatisfy { !$0.isLabelVisible })
  await controller.select("a")
  let frame = await controller.frame()
  #expect(frame.topologyRevision == 4 && frame.visualRevision == 7)
  #expect(frame.nodes.filter(\.isLabelVisible).map(\.snapshot.id) == ["a", "b"])
}

@Test func visualOnlyUpdatePreservesCoolingWhileTopologyUpdateReheats() async {
  var scene = sampleScene()
  scene.policy.sceneUpdate = .automatic(alpha: 0.8)
  let controller = ForceGraphController(scene: scene)
  for _ in 0..<400 { _ = await controller.tick() }
  let cooled = await controller.frame()
  #expect(!cooled.isLayoutRunning)
  scene.visualRevision = 1
  scene.nodes[0].visual.color = GraphColor(red: 1, green: 0, blue: 0)
  await controller.updateScene(scene)
  #expect(!(await controller.frame()).isLayoutRunning)
  scene.topologyRevision = 1
  await controller.updateScene(scene)
  let reheated = await controller.frame()
  #expect(reheated.isLayoutRunning && reheated.alpha >= 0.8)
}

private func yieldUntil(
  _ predicate: @escaping @Sendable () async -> Bool, attempts: Int = 1_000
) async -> Bool {
  for _ in 0..<attempts {
    if await predicate() { return true }
    await Task.yield()
  }
  return false
}

@Test func schedulerKeepsSameStreamDormantAndRestarts() async {
  let controller = ForceGraphController(scene: sampleScene())
  await controller.stop()
  let scheduler = ForceGraphSceneScheduler(controller: controller, framesPerSecond: 240)
  let stream = await scheduler.start()
  var iterator = stream.makeAsyncIterator()
  let cold = await iterator.next()
  #expect(cold != nil)
  #expect(await yieldUntil { await scheduler.state() == .dormant })
  let sequence = (await controller.frame()).sequence
  for _ in 0..<20 { await Task.yield() }
  #expect((await controller.frame()).sequence == sequence)

  await scheduler.restart(alpha: 0.5)
  let resumed = await iterator.next()
  #expect(resumed != nil)
  #expect(resumed!.sequence > cold!.sequence)
  await scheduler.stop()
  #expect(await iterator.next() == nil)
}

@Test func schedulerPauseResumeAndRepeatedRestartKeepOneLoop() async {
  let controller = ForceGraphController(scene: sampleScene())
  let scheduler = ForceGraphSceneScheduler(controller: controller, framesPerSecond: 240)
  let stream = await scheduler.start()
  var iterator = stream.makeAsyncIterator()
  _ = await iterator.next()
  await scheduler.pause()
  #expect(await scheduler.state() == .dormant)
  let pausedSequence = (await controller.frame()).sequence
  for _ in 0..<20 { await Task.yield() }
  #expect((await controller.frame()).sequence == pausedSequence)
  await scheduler.restart(alpha: 0.4)
  await scheduler.restart(alpha: 0.4)
  #expect(await scheduler.state() == .running)
  #expect(await iterator.next() != nil)
  await scheduler.stop()
  #expect(await scheduler.state() == .stopped)
}

@Test func schedulerSceneUpdateWakesCooledStream() async {
  let controller = ForceGraphController(scene: sampleScene())
  await controller.stop()
  let scheduler = ForceGraphSceneScheduler(controller: controller, framesPerSecond: 240)
  let stream = await scheduler.start()
  var iterator = stream.makeAsyncIterator()
  _ = await iterator.next()
  #expect(await yieldUntil { await scheduler.state() == .dormant })
  var updated = sampleScene()
  updated.topologyRevision = 1
  await scheduler.updateScene(updated, policy: .reheat(0.5))
  let updateFrame = await iterator.next()
  #expect(updateFrame?.topologyRevision == 1)
  #expect(await scheduler.state() == .running)
  await scheduler.stop()
}

@Test func schedulerConsumerCancellationCleansUp() async {
  let controller = ForceGraphController(scene: sampleScene())
  let scheduler = ForceGraphSceneScheduler(controller: controller, framesPerSecond: 240)
  let stream = await scheduler.start()
  let consumer = Task {
    for await _ in stream { if Task.isCancelled { return } }
  }
  consumer.cancel()
  _ = await consumer.result
  #expect(await yieldUntil { await scheduler.state() == .stopped })
}
