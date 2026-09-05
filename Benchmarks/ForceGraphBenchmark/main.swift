import ForceGraphCore
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let sizes: [Int]
if arguments.isEmpty {
  sizes = [100, 1_000]
} else {
  sizes = arguments.map { argument in
    guard let size = Int(argument), size > 0 else {
      fail("usage: force-graph-benchmark [positive-node-count ...]")
    }
    return size
  }
}
for size in sizes {
  var simulation = ForceSimulation(nodes: (0..<size).map { ForceNode(id: $0) }, dimensions: .three)
  simulation.force(
    "charge",
    .manyBody(
      strength: -5, algorithm: .barnesHut(theta: 0.9, directThreshold: 32)
    ))
  let clock = ContinuousClock()
  let start = clock.now
  simulation.tick(iterations: 10)
  let elapsed = start.duration(to: clock.now)
  let seconds =
    Double(elapsed.components.seconds)
    + Double(elapsed.components.attoseconds) / 1e18
  let total = String(format: "%.6f", seconds)
  let perTick = String(format: "%.3f", seconds * 100)
  print("nodes=\(size) ticks=10 total_seconds=\(total) ms_per_tick=\(perTick)")
}
