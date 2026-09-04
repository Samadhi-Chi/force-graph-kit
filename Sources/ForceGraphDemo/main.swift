import ForceGraphCore
import Foundation

struct DemoNode: Codable {
  let id: String
  let x: Double
  let y: Double
  let z: Double
}
struct DemoEdge: Codable {
  let source: String
  let target: String
  let sourcePosition: [Double]
  let targetPosition: [Double]
}
struct DemoOutput: Codable {
  let dimensions: Int
  let alpha: Double
  let nodes: [DemoNode]
  let edges: [DemoEdge]
}

func fail(_ message: String, status: Int32 = 2) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(status)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let raw = arguments.first ?? "3"
guard arguments.count <= 1, let count = Int(raw),
  let dimensions = SimulationDimensions(rawValue: count)
else {
  fail("usage: force-graph-demo [1|2|3]")
}
let links = (0..<7).map {
  ForceLink(source: "node-\($0)", target: "node-\($0 + 1)", distance: 24)
}
var simulation = ForceSimulation(
  nodes: (0..<8).map { ForceNode(id: "node-\($0)") }, dimensions: dimensions
)
simulation.force("links", .link(links))
simulation.force("charge", .manyBody(strength: -15))
simulation.force("center", .center())
simulation.tick(iterations: 120)

let snapshots = simulation.snapshots()
let nodes = snapshots.map {
  DemoNode(id: $0.id, x: $0.x, y: $0.y.isFinite ? $0.y : 0, z: $0.z.isFinite ? $0.z : 0)
}
let positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, [$0.x, $0.y, $0.z]) })
let edges = links.compactMap { link -> DemoEdge? in
  guard let source = positions[link.source], let target = positions[link.target] else { return nil }
  return DemoEdge(
    source: link.source, target: link.target,
    sourcePosition: source, targetPosition: target)
}
let output = DemoOutput(dimensions: count, alpha: simulation.alpha, nodes: nodes, edges: edges)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
do {
  FileHandle.standardOutput.write(try encoder.encode(output))
  print()
} catch {
  fail("failed to encode finite demo output: \(error)", status: 1)
}
