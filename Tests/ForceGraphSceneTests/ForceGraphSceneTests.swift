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
