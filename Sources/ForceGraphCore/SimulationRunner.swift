import Foundation

/// Immutable output from an asynchronous simulation runner.
public struct SimulationFrame<ID: Hashable & Sendable>: Sendable {
  /// Monotonic frame number.
  public let sequence: UInt64
  /// Alpha after the frame's ticks.
  public let alpha: Double
  /// Complete node snapshots.
  public let nodes: [NodeSnapshot<ID>]
}

/// Actor-isolated scheduler for render-loop-friendly simulation frames.
///
/// At most one loop is active. Streams buffer only the newest frame; terminating the current
/// stream cancels its loop. Manual reads and mutations are serialized through the actor.
public actor SimulationRunner<ID: Hashable & Sendable> {
  private var simulation: ForceSimulation<ID>
  private var task: Task<Void, Never>?
  private var continuation: AsyncStream<SimulationFrame<ID>>.Continuation?
  private var paused = false
  private var framesPerSecond: Double
  private var ticksPerFrame: Int
  private var sequence: UInt64 = 0
  private var generation: UInt64 = 0

  /// Creates a runner without starting it.
  /// - Parameters:
  ///   - simulation: Simulation exclusively owned by the actor.
  ///   - framesPerSecond: Target cadence, clamped to `1...240`; invalid values become 60.
  ///   - ticksPerFrame: Tick budget per frame, clamped to `1...1_000`.
  public init(simulation: ForceSimulation<ID>, framesPerSecond: Double = 60, ticksPerFrame: Int = 1)
  {
    self.simulation = simulation
    self.framesPerSecond = Self.validFPS(framesPerSecond)
    self.ticksPerFrame = Self.validTicks(ticksPerFrame)
  }

  deinit {
    task?.cancel()
    continuation?.finish()
  }

  /// Starts a new loop, finishing and cancelling any previous stream.
  /// - Returns: A newest-frame-buffered stream. Cancelling iteration terminates this generation.
  public func start() -> AsyncStream<SimulationFrame<ID>> {
    terminateCurrent()
    generation &+= 1
    let token = generation
    let stream = AsyncStream<SimulationFrame<ID>>(bufferingPolicy: .bufferingNewest(1)) {
      continuation in
      self.continuation = continuation
      continuation.onTermination = { @Sendable [weak self] _ in
        Task { await self?.streamTerminated(token: token) }
      }
    }
    paused = false
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let nanoseconds = await self?.runFrame(token: token) else { return }
        do { try await Task.sleep(nanoseconds: nanoseconds) } catch { return }
      }
    }
    return stream
  }

  /// Pauses ticking without terminating the current stream. Repeated calls are harmless.
  public func pause() { paused = true }
  /// Resumes ticking. Calling it before start only updates state for the next start.
  public func resume() { paused = false }

  /// Updates cadence and tick budget using the same validation as initialization.
  public func configure(framesPerSecond: Double, ticksPerFrame: Int) {
    self.framesPerSecond = Self.validFPS(framesPerSecond)
    self.ticksPerFrame = Self.validTicks(ticksPerFrame)
  }

  /// Mutates the owned simulation synchronously on the actor.
  public func update(_ body: @Sendable (inout ForceSimulation<ID>) -> Void) { body(&simulation) }

  /// Returns the current state without ticking, for deterministic inspection.
  public func currentFrame() -> SimulationFrame<ID> {
    SimulationFrame(sequence: sequence, alpha: simulation.alpha, nodes: simulation.snapshots())
  }

  /// Cancels scheduling and finishes the current stream. Safe to call repeatedly.
  public func stop() {
    generation &+= 1
    terminateCurrent()
  }

  private func terminateCurrent() {
    task?.cancel()
    task = nil
    let current = continuation
    continuation = nil
    current?.onTermination = nil
    current?.finish()
  }

  private func streamTerminated(token: UInt64) {
    guard generation == token else { return }
    generation &+= 1
    terminateCurrent()
  }

  private func runFrame(token: UInt64) -> UInt64? {
    guard generation == token else { return nil }
    if !paused {
      simulation.tick(iterations: ticksPerFrame)
      sequence &+= 1
      continuation?.yield(
        SimulationFrame(
          sequence: sequence, alpha: simulation.alpha,
          nodes: simulation.snapshots()))
    }
    return UInt64(1_000_000_000 / framesPerSecond)
  }

  private static func validFPS(_ value: Double) -> Double {
    value.isFinite && value > 0 ? min(max(1, value), 240) : 60
  }
  private static func validTicks(_ value: Int) -> Int { min(max(1, value), 1_000) }
}
