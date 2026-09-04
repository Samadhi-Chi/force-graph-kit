import Foundation
import Testing

@testable import ForceGraphCore

@Test func spatialIndexQueriesAndCoincidentDepthAreSafe() {
  let points: [SpatialPoint<Int>] = (0..<100).map { index in
    let x = index < 20 ? 0.0 : Double(index)
    let y = index < 20 ? 0.0 : Double(index % 7)
    return SpatialPoint(id: index, x: x, y: y)
  }
  let index = SpatialIndex(points: points, dimensions: .two, leafCapacity: 2, maximumDepth: 8)
  #expect(index.nearest(x: 80.1, y: 3)?.id == 80)
  #expect(index.points(x: 0, y: 0, within: 0).count == 20)
  #expect(index.points(x: 0, within: -1).isEmpty)
  #expect(index.cells.count < 1_000)
}

@Test func spatialQueriesRespectDimensionsTiesAndInvalidInputs() {
  let points = [
    SpatialPoint(id: "first", x: -1, y: 100, z: 100),
    SpatialPoint(id: "second", x: 1, y: 0, z: 0),
    SpatialPoint(id: "invalid", x: .nan, y: 0, z: 0),
  ]
  let one = SpatialIndex(points: points, dimensions: .one)
  #expect(one.points.count == 2)
  #expect(one.nearest(x: 0)?.id == "first")
  #expect(one.nearest(x: 0, radius: 0.5) == nil)
  #expect(one.nearest(x: .nan) == nil)
  #expect(one.nearest(x: 0, radius: .infinity) == nil)
  let three = SpatialIndex(points: points, dimensions: .three)
  #expect(three.nearest(x: 0, y: 0, z: 0)?.id == "second")
  #expect(three.points(x: 0, y: .nan, within: 10).isEmpty)
}

@Test func orthantFanoutMatchesDimensionsAndHandlesEmptySingleton() {
  for (dimensions, maximumChildren) in [
    (SimulationDimensions.one, 2), (.two, 4), (.three, 8),
  ] {
    let points = (0..<64).map {
      SpatialPoint(id: $0, x: Double($0 % 4), y: Double(($0 / 4) % 4), z: Double($0 / 16))
    }
    let index = SpatialIndex(points: points, dimensions: dimensions, leafCapacity: 1)
    #expect(index.cells.allSatisfy { $0.children.count <= maximumChildren })
    #expect(index.points.count == 64)
    for cell in index.cells where cell.children.isEmpty {
      for pointIndex in cell.indices {
        let point = index.points[pointIndex]
        #expect(abs(point.x - cell.center.0) <= cell.half + 1e-12)
        if dimensions.rawValue > 1 { #expect(abs(point.y - cell.center.1) <= cell.half + 1e-12) }
        if dimensions.rawValue > 2 { #expect(abs(point.z - cell.center.2) <= cell.half + 1e-12) }
      }
    }
    let repeated = SpatialIndex(points: points, dimensions: dimensions, leafCapacity: 1)
    #expect(index.cells.map { $0.children } == repeated.cells.map { $0.children })
    #expect(index.cells.map { $0.indices } == repeated.cells.map { $0.indices })
  }
  #expect(SpatialIndex<Int>(points: [], dimensions: .three).cells.isEmpty)
  let singleton = SpatialIndex(points: [SpatialPoint(id: 1, x: 0)], dimensions: .one)
  #expect(singleton.cells.count == 1 && singleton.nearest(x: 0)?.id == 1)

  let aggregateIndex = SpatialIndex(
    points: [SpatialPoint(id: 0, x: 0, y: 2), SpatialPoint(id: 1, x: 4, y: 6)],
    dimensions: .two, leafCapacity: 1)
  let root = barnesHutAggregates(tree: aggregateIndex)[0]
  #expect(root.count == 2 && root.x == 2 && root.y == 4 && root.z == 0)
}

@Test func barnesHutTracksDirectAndIsDeterministic() {
  let nodes = (0..<80).map { ForceNode(id: $0) }
  func run(_ algorithm: ManyBodyAlgorithm) -> [ForceNode<Int>] {
    var simulation = ForceSimulation(nodes: nodes, dimensions: .three)
    simulation.velocityDecay = 0
    simulation.force("charge", .manyBody(strength: -2, algorithm: algorithm))
    simulation.tick()
    return simulation.nodes
  }
  let direct = run(.direct)
  let approximate = run(.barnesHut(theta: 0.5, directThreshold: 0))
  let repeated = run(.barnesHut(theta: 0.5, directThreshold: 0))
  #expect(approximate.map(\.vx) == repeated.map(\.vx))
  let meanError = zip(direct, approximate).map { abs($0.vx - $1.vx) }.reduce(0, +) / 80
  let meanMagnitude = direct.map { abs($0.vx) }.reduce(0, +) / 80
  #expect(meanError < meanMagnitude * 0.2)
}

@Test func barnesHutTracksAttractionAndRepulsionInEveryDimension() {
  for dimensions in [SimulationDimensions.one, .two, .three] {
    let nodes = (0..<96).map { ForceNode(id: $0) }
    for strength in [-3.0, 3.0] {
      func run(_ algorithm: ManyBodyAlgorithm) -> [ForceNode<Int>] {
        var simulation = ForceSimulation(nodes: nodes, dimensions: dimensions)
        simulation.alphaDecay = 0
        simulation.velocityDecay = 0
        simulation.force("charge", .manyBody(strength: strength, algorithm: algorithm))
        simulation.tick()
        return simulation.nodes
      }
      let direct = run(.direct)
      let approximate = run(.barnesHut(theta: 0.45, directThreshold: 0))
      let directMagnitude = direct.map { abs($0.vx) + abs($0.vy) + abs($0.vz) }.reduce(0, +)
      let error = zip(direct, approximate).map {
        abs($0.vx - $1.vx) + abs($0.vy - $1.vy) + abs($0.vz - $1.vz)
      }.reduce(0, +)
      #expect(error < directMagnitude * 0.25)
      #expect(direct[0].vx.sign == approximate[0].vx.sign || direct[0].vx == 0)
    }
  }
}

@Test func manyBodyAlgorithmValidationAndDistanceBoundsAreSafe() {
  let nodes = (0..<40).map { ForceNode(id: $0) }
  func velocities(_ force: AnyForce<Int>) -> [Double] {
    var simulation = ForceSimulation(nodes: nodes, dimensions: .two)
    simulation.force("charge", force)
    simulation.tick()
    return simulation.nodes.map(\.vx)
  }
  #expect(velocities(.manyBody(strength: 0)).allSatisfy { $0 == 0 })
  #expect(
    velocities(.manyBody(algorithm: .barnesHut(theta: 0, directThreshold: 0))).allSatisfy {
      $0 == 0
    })
  #expect(
    velocities(.manyBody(algorithm: .barnesHut(theta: .nan, directThreshold: 0))).allSatisfy {
      $0 == 0
    })
  #expect(velocities(.manyBody(minimumDistance: 10, maximumDistance: 1)).allSatisfy { $0 == 0 })
  #expect(
    velocities(
      .manyBody(maximumDistance: 0, algorithm: .barnesHut(theta: 0.9, directThreshold: 0))
    ).allSatisfy { $0 == 0 })
  #expect(
    velocities(.manyBody(algorithm: .barnesHut(theta: 0.9, directThreshold: 40)))
      == velocities(.manyBody(algorithm: .direct)))
  let negativeThreshold = velocities(
    .manyBody(algorithm: .barnesHut(theta: 0.9, directThreshold: -2)))
  #expect(negativeThreshold.allSatisfy { $0.isFinite })
}

@Test func cachedManyBodyStrengthSignsZeroAndInvalidArePerNode() {
  let nodes = [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 10)]
  func velocity(_ strength: Double) -> Double {
    var simulation = ForceSimulation(nodes: nodes, dimensions: .one)
    simulation.alphaDecay = 0
    simulation.velocityDecay = 0
    simulation.force(
      "charge",
      .manyBody(nodes: nodes, strengths: .constant(strength), minimumDistance: 0))
    simulation.tick()
    return simulation.nodes[0].vx
  }
  #expect(velocity(2) > 0)
  #expect(velocity(-2) < 0)
  #expect(velocity(0) == 0)
  #expect(velocity(.nan) == 0)
}

@Test func cachedProvidersAndCollisionRadii() {
  let nodes = [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 1)]
  let provider = CachedValueProvider<ForceNode<Int>> { _, index in Double(index + 1) }
  var simulation = ForceSimulation(nodes: nodes, dimensions: .one)
  simulation.velocityDecay = 0
  simulation.force("collision", .collision(nodes: nodes, radii: provider))
  simulation.tick(iterations: 2)
  #expect(abs(simulation.nodes[1].x - simulation.nodes[0].x) >= 3 - 1e-6)

  var radial = ForceSimulation(nodes: [ForceNode(id: 0, x: 1)], dimensions: .one)
  radial.velocityDecay = 0
  radial.force(
    "radial",
    .radial(
      nodes: radial.nodes, radii: .constant(10),
      strengths: .constant(1)))
  radial.tick()
  #expect(radial.nodes[0].x > 1)
}

@Test func providersCacheAtConstructionAndHandleDuplicateOrIDs() {
  let duplicateNodes = [ForceNode(id: 1, x: 0), ForceNode(id: 1, x: 2)]
  let force = AnyForce<Int>.x(
    nodes: duplicateNodes,
    targets: CachedValueProvider { node, _ in node.x + 10 },
    strengths: .constant(1))
  var simulation = ForceSimulation(nodes: duplicateNodes, dimensions: .one)
  simulation.velocityDecay = 0
  simulation.updateNode(id: 1) { $0.x = 100 }
  simulation.force("cached", force)
  simulation.tick()
  #expect(simulation.nodes[0].vx < 0)
  #expect(simulation.nodes.allSatisfy { $0.vx.isFinite })
}

@Test func collisionBroadPhaseHandlesVeryDifferentRadiiAndInvalidValues() {
  let nodes = [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 50), ForceNode(id: 2, x: 500)]
  let radii = CachedValueProvider<ForceNode<Int>> { _, index in
    index == 0 ? 100 : (index == 1 ? 1 : .nan)
  }
  var simulation = ForceSimulation(nodes: nodes, dimensions: .one)
  simulation.velocityDecay = 0
  simulation.force("collision", .collision(nodes: nodes, radii: radii))
  simulation.tick()
  #expect(abs(simulation.nodes[1].x - simulation.nodes[0].x) >= 101 - 1e-9)
  #expect(simulation.nodes[2].x == 500)

  var zero = ForceSimulation(
    nodes: [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 0)], dimensions: .one)
  zero.force("collision", .collision(nodes: zero.nodes, radii: .constant(0)))
  zero.tick()
  #expect(zero.nodes[0].x == 0 && zero.nodes[1].x == 0)
}

@Test func cachedLinkProvidersAreEvaluatedForOneRevision() {
  let links = [ForceLink(source: 0, target: 1)]
  let force = AnyForce<Int>.link(
    links, distances: .constant(5), strengths: .constant(1), iterations: 1)
  var simulation = ForceSimulation(
    nodes: [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 20)], dimensions: .one)
  simulation.alphaDecay = 0
  simulation.velocityDecay = 0
  simulation.force("link", force)
  simulation.tick()
  #expect(abs(simulation.nodes[1].x - simulation.nodes[0].x) == 5)
}

@Test func graphDiagnosticsAndDeltasPreserveDynamics() {
  let nodes = [ForceNode(id: 1, x: 5, vx: 2), ForceNode(id: 1), ForceNode(id: 2)]
  let links = [ForceLink(source: 1, target: 3), ForceLink(source: 2, target: 2)]
  let diagnostics = validateGraph(nodes: nodes, links: links)
  #expect(diagnostics.duplicateNodeIDs == [1])
  #expect(diagnostics.unresolvedLinks.count == 1 && diagnostics.selfLinks.count == 1)
  var simulation = ForceSimulation(nodes: [nodes[0]], dimensions: .one)
  #expect(simulation.apply([.insert(ForceNode(id: 1))]) == [1])
  simulation.apply([.upsert(ForceNode(id: 1, x: 99)), .insert(ForceNode(id: 2)), .remove(2)])
  #expect(simulation.nodes[0].x == 5 && simulation.nodes[0].vx == 2)
  simulation.apply([.update(id: 1, state: NodeStateUpdate(x: 8, vx: 4, fx: .set(8)))])
  #expect(simulation.nodes[0].x == 8 && simulation.nodes[0].vx == 4 && simulation.nodes[0].fx == 8)
  simulation.apply([.update(id: 1, state: NodeStateUpdate(x: .nan, fx: .clear))])
  #expect(simulation.nodes[0].x == 8 && simulation.nodes[0].fx == nil)
  let changed = applying(
    [
      LinkDelta.upsert(id: "a", link: ForceLink(source: 1, target: 2)),
      .upsert(id: "b", link: ForceLink(source: 2, target: 1)),
      .remove("a"),
    ], to: [] as [(id: String, link: ForceLink<Int>)])
  #expect(changed.map(\.id) == ["b"])
}

@Test func sampleKnowledgeGraphJSONIsValid() throws {
  let testFile = URL(fileURLWithPath: #filePath)
  let repository = testFile.deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
  let data = try Data(
    contentsOf: repository.appendingPathComponent("Examples/Data/knowledge-graph.json"))
  let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  #expect((object["nodes"] as? [[String: Any]])?.count == 5)
  #expect((object["links"] as? [[String: Any]])?.count == 5)
}

@Test func boundsAndFitAreDeterministic() {
  let nodes = [ForceNode(id: 0, x: -10, y: -5, z: 0), ForceNode(id: 1, x: 10, y: 5, z: 0)]
  let bounds = layoutBounds(of: nodes, dimensions: .two)!
  #expect(bounds.width == 20 && bounds.height == 10)
  let fit = fitTransform(bounds: bounds, width: 100, height: 100, depth: 100, padding: 0.1)
  #expect(fit.scale == 4)
  let point = fit.apply(x: 10, y: 5, z: 0)
  #expect(point.x == 40 && point.y == 20)
}

@Test func runnerStreamsAndCancels() async {
  let simulation = ForceSimulation(nodes: [ForceNode(id: 0)], dimensions: .one)
  let runner = SimulationRunner(simulation: simulation, framesPerSecond: 240)
  let stream = await runner.start()
  var iterator = stream.makeAsyncIterator()
  let frame = await iterator.next()
  #expect(frame?.sequence == 1)
  await runner.pause()
  await runner.stop()
  #expect(await iterator.next() == nil)
}

@Test func runnerRepeatedLifecycleHasOnlyOneActiveGeneration() async {
  let runner = SimulationRunner(
    simulation: ForceSimulation(nodes: [ForceNode(id: 0)], dimensions: .one),
    framesPerSecond: .nan, ticksPerFrame: -4
  )
  let first = await runner.start()
  var firstIterator = first.makeAsyncIterator()
  let second = await runner.start()
  if await firstIterator.next() != nil { #expect(await firstIterator.next() == nil) }
  var secondIterator = second.makeAsyncIterator()
  #expect(await secondIterator.next()?.sequence != nil)
  await runner.pause()
  let paused = await runner.currentFrame().sequence
  try? await Task.sleep(for: .milliseconds(25))
  #expect(await runner.currentFrame().sequence == paused)
  await runner.configure(framesPerSecond: 500, ticksPerFrame: 5_000)
  await runner.resume()
  try? await Task.sleep(for: .milliseconds(10))
  #expect(await runner.currentFrame().sequence > paused)
  await runner.stop()
  await runner.stop()
  if await secondIterator.next() != nil { #expect(await secondIterator.next() == nil) }
}

@Test func runnerDoesNotRetainItselfWithoutAnOwner() async {
  weak var weakRunner: SimulationRunner<Int>?
  do {
    let runner = SimulationRunner(
      simulation: ForceSimulation(nodes: [ForceNode(id: 0)], dimensions: .one))
    weakRunner = runner
    _ = await runner.start()
  }
  for _ in 0..<10 where weakRunner != nil { await Task.yield() }
  #expect(weakRunner == nil)
}
