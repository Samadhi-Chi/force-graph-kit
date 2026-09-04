import Foundation
import Testing
@testable import ForceGraphCore

private let tolerance = 1e-12
private func close(_ a: Double, _ b: Double, tolerance: Double = tolerance) -> Bool { abs(a - b) <= tolerance }

@Test func initializationMatchesD3References() {
    let one = ForceSimulation(nodes: (0..<3).map { ForceNode(id: $0) }, dimensions: .one)
    #expect(one.nodes.map(\.x) == [0, 10, 20])

    let two = ForceSimulation(nodes: (0..<3).map { ForceNode(id: $0) }, dimensions: .two)
    #expect(close(two.nodes[0].x, 7.0710678118654755))
    #expect(close(two.nodes[1].x, -9.03088751750192))
    #expect(close(two.nodes[1].y, 8.273032735715967))

    let three = ForceSimulation(nodes: (0..<3).map { ForceNode(id: $0) }, dimensions: .three)
    #expect(close(three.nodes[0].y, 7.937005259840998))
    #expect(close(three.nodes[1].x, 5.859546188141111))
    #expect(close(three.nodes[1].y, -8.440766567518239))
    #expect(close(three.nodes[1].z, 5.045418509118165))
}

@Test func defaultLCGAndJiggleMatchD3() {
    var random = D3Random()
    let expected = [0.23645552527159452, 0.3692706737201661,
                    0.5042420323006809, 0.7048832636792213]
    for value in expected { #expect(random.next() == value) }
    var jiggle = D3Random()
    #expect(jiggle.jiggle() == (expected[0] - 0.5) * 1e-6)
}

@Test func forceOrderReplacementAndReaddition() {
    let append: @Sendable (Double) -> AnyForce<Int> = { digit in
        AnyForce { nodes, _, _, _ in nodes[0].vx = nodes[0].vx * 10 + digit }
    }
    var simulation = ForceSimulation(nodes: [ForceNode(id: 0, x: 0)], dimensions: .one)
    simulation.velocityDecay = 0
    simulation.force("z-first", append(1))
    simulation.force("a-second", append(2))
    simulation.force("z-first", append(3))
    simulation.tick()
    #expect(simulation.nodes[0].vx == 32)
    simulation.force("z-first", nil)
    simulation.force("z-first", append(4))
    simulation.updateNode(id: 0) { $0.vx = 0 }
    simulation.tick()
    #expect(simulation.nodes[0].vx == 24)
}

@Test func alphaVelocityAndManualTickSemantics() {
    var simulation = ForceSimulation(nodes: [ForceNode(id: 0, x: 0, vx: 10)], dimensions: .one)
    simulation.alphaDecay = 0.5
    simulation.velocityDecay = 0.25
    simulation.stop()
    simulation.tick()
    #expect(simulation.alpha == 0.5)
    #expect(simulation.nodes[0].vx == 7.5)
    #expect(simulation.nodes[0].x == 7.5)
}

@Test func fixedCoordinatesApplyDuringInitializationAndIntegration() {
    var simulation = ForceSimulation(
        nodes: [ForceNode(id: 0, x: .nan, y: .nan, z: .nan,
                          vx: 2, vy: 3, vz: 4, fx: 7, fy: 8, fz: 9)],
        dimensions: .three
    )
    #expect(simulation.nodes[0].x == 7 && simulation.nodes[0].y == 8 && simulation.nodes[0].z == 9)
    simulation.tick()
    #expect(simulation.nodes[0].vx == 0 && simulation.nodes[0].vy == 0 && simulation.nodes[0].vz == 0)
}

@Test func inactiveAxesArePreservedAndDimensionChangesInitialize() {
    var simulation = ForceSimulation(
        nodes: [ForceNode(id: 0, x: 0, y: 5, z: 6, vx: 1, vy: 2, vz: 3)], dimensions: .one
    )
    simulation.velocityDecay = 0
    simulation.tick()
    #expect(simulation.nodes[0].y == 5 && simulation.nodes[0].vy == 2)
    #expect(simulation.nodes[0].z == 6 && simulation.nodes[0].vz == 3)
    simulation.setDimensions(.three)
    simulation.tick()
    #expect(simulation.nodes[0].y == 7 && simulation.nodes[0].z == 9)
}

@Test func manyBodySignsAndDistanceBounds() {
    func velocity(strength: Double, minimum: Double = 0, maximum: Double = .infinity) -> Double {
        var simulation = ForceSimulation(nodes: [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 0.5)], dimensions: .one)
        simulation.velocityDecay = 0
        simulation.alphaDecay = 0
        simulation.force("charge", .manyBody(strength: strength, minimumDistance: minimum, maximumDistance: maximum))
        simulation.tick()
        return simulation.nodes[0].vx
    }
    #expect(velocity(strength: -1) < 0)
    #expect(velocity(strength: 1) > 0)
    #expect(close(velocity(strength: -1, minimum: 2), -0.5))
    #expect(velocity(strength: -1, maximum: 0.5) == 0)
}

@Test func collisionSeparationAndDimensions() {
    var simulation = ForceSimulation(
        nodes: [ForceNode(id: 0, x: 0, y: 10), ForceNode(id: 1, x: 0, y: 10)],
        dimensions: .one
    )
    simulation.velocityDecay = 0
    simulation.force("collision", .collision(radius: 1))
    simulation.tick()
    #expect(close(abs(simulation.nodes[1].x - simulation.nodes[0].x), 2, tolerance: 1e-6))
    #expect(simulation.nodes.allSatisfy { $0.y == 10 })
}

@Test func linkDistanceStrengthIterationsAndDegreeBias() {
    func run(strength: Double, iterations: Int) -> [ForceNode<Int>] {
        var simulation = ForceSimulation(
            nodes: [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 100), ForceNode(id: 2, x: 0)],
            dimensions: .one
        )
        simulation.velocityDecay = 0
        simulation.alphaDecay = 0
        simulation.replaceLinks([
            ForceLink(source: 0, target: 1, distance: 10, strength: strength),
            ForceLink(source: 0, target: 2, distance: 10, strength: strength)
        ], iterations: iterations)
        simulation.tick()
        return simulation.nodes
    }
    let weak = run(strength: 0.1, iterations: 1)
    let strong = run(strength: 1, iterations: 1)
    let iterated = run(strength: 0.1, iterations: 2)
    #expect(abs(strong[1].x - strong[0].x) < abs(weak[1].x - weak[0].x))
    #expect(abs(iterated[1].x - iterated[0].x) < abs(weak[1].x - weak[0].x))
    #expect(abs(strong[0].vx) < abs(strong[1].vx + strong[2].vx))
}

@Test func linksIgnoreMissingSelfInvalidAndResolveAfterUpdate() {
    var simulation = ForceSimulation(nodes: [ForceNode(id: 0), ForceNode(id: 0), ForceNode(id: 1)])
    simulation.replaceLinks([
        ForceLink(source: 99, target: 1), ForceLink(source: 0, target: 0),
        ForceLink(source: 0, target: 1, distance: .nan)
    ])
    simulation.tick()
    #expect(simulation.nodes.allSatisfy { $0.vx == 0 && $0.vy == 0 })
    simulation.replaceNodes([ForceNode(id: 1), ForceNode(id: 0), ForceNode(id: 2)])
    simulation.replaceLinks([ForceLink(source: 0, target: 1)])
    simulation.tick()
    #expect(simulation.nodes.count == 3)
}

@Test func findUsesDimensionsAndRadius() {
    let nodes = [ForceNode(id: "x", x: 0, y: 100, z: 100), ForceNode(id: "y", x: 2, y: 0, z: 0)]
    let one = ForceSimulation(nodes: nodes, dimensions: .one)
    #expect(one.find(x: 0, y: 0)?.id == "x")
    let three = ForceSimulation(nodes: nodes, dimensions: .three)
    #expect(three.find(x: 0, y: 0, z: 0)?.id == "y")
    #expect(three.find(x: 0, y: 0, z: 0, radius: 1) == nil)
    #expect(three.find(x: 0, radius: -.infinity) == nil)
}

@Test func invalidParametersAreNoOpsAndRemainFinite() {
    var simulation = ForceSimulation(nodes: [ForceNode(id: 0, x: 0), ForceNode(id: 1, x: 1)], dimensions: .three)
    simulation.force("charge", .manyBody(strength: .nan, minimumDistance: -1))
    simulation.force("collision", .collision(radius: -.infinity, iterations: -1))
    simulation.force("radial", .radial(radius: .infinity, strength: -.infinity))
    simulation.force("x", .x(.nan, strength: -1))
    simulation.tick(iterations: -5)
    simulation.tick()
    #expect(simulation.nodes.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
}

@Test func snapshotsAndDragReheatFlow() {
    var simulation = ForceSimulation(nodes: [ForceNode(id: "drag", x: 1, y: 2, vx: 3)], dimensions: .two)
    simulation.updateNode(id: "drag") { $0.fx = 9; $0.fy = 8 }
    simulation.alphaTarget = 0.3
    simulation.restart()
    simulation.tick()
    let snapshot = simulation.snapshots()[0]
    #expect(snapshot.x == 9 && snapshot.y == 8 && snapshot.vx == 0)
    #expect(snapshot.fx == 9 && snapshot.fy == 8 && snapshot.fz == nil)
    simulation.updateNode(id: "drag") { $0.fx = nil; $0.fy = nil }
    simulation.alphaTarget = 0
    #expect(simulation.isRunning)
}

@Test func emptyAndSingleNodeAreSafe() {
    var empty = ForceSimulation<Int>()
    empty.tick()
    #expect(empty.nodes.isEmpty)
    var one = ForceSimulation(nodes: [ForceNode(id: 1)], dimensions: .three)
    one.force("charge", .manyBody())
    one.tick(iterations: 4)
    #expect(one.nodes.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
}

@Test func alphaCoolingFixture() {
    var simulation = ForceSimulation<Int>()
    simulation.tick(iterations: 300)
    #expect(close(simulation.alpha, 0.001))
}
