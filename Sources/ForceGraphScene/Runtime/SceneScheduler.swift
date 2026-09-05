/// Actor-owned scene scheduler that emits only the newest frame and runs no loop after cooling.
/// Cooling leaves the stream dormant and resumable; stopping or terminating its consumer tears it
/// down. Hosts should stop the scheduler or cancel stream consumption when their lifecycle ends.
public actor ForceGraphSceneScheduler<ID: Hashable & Sendable, LinkID: Hashable & Sendable> {
  internal enum ReentrancyPoint: Sendable, Equatable {
    case emit
    case restart
    case updateScene
  }

  private let controller: ForceGraphController<ID, LinkID>
  private var task: Task<Void, Never>?
  private var continuation: AsyncStream<ForceGraphRenderFrame<ID, LinkID>>.Continuation?
  private var generation: UInt64 = 0
  private var consumerGeneration: UInt64 = 0
  private var framesPerSecond: Double
  private var ticksPerFrame: Int
  private var reentrancyProbe: (@Sendable (ReentrancyPoint) async -> Void)?

  /// Observable scheduling state for lifecycle coordination and deterministic tests.
  public enum State: Sendable, Equatable {
    /// No stream is installed.
    case stopped
    /// A consumer exists but no loop is polling (paused or cooled).
    case dormant
    /// Exactly one tick loop is active.
    case running
  }

  /// Creates a scheduler without starting it.
  public init(
    controller: ForceGraphController<ID, LinkID>, framesPerSecond: Double = 60,
    ticksPerFrame: Int = 1
  ) {
    self.controller = controller
    self.framesPerSecond = Self.validFPS(framesPerSecond)
    self.ticksPerFrame = max(1, min(1_000, ticksPerFrame))
  }

  deinit {
    task?.cancel()
    continuation?.finish()
  }

  /// Starts one loop, replacing and finishing any prior subscription.
  /// Cooling stops only the tick loop; the returned stream remains dormant and can be resumed by
  /// ``resume()``, ``restart(alpha:)``, or a mechanical ``updateScene(_:policy:)``.
  public func start() -> AsyncStream<ForceGraphRenderFrame<ID, LinkID>> {
    stop()
    generation &+= 1
    consumerGeneration &+= 1
    let consumerToken = consumerGeneration
    let token = generation
    let stream = AsyncStream<ForceGraphRenderFrame<ID, LinkID>>(
      bufferingPolicy: .bufferingNewest(1)
    ) {
      continuation = $0
      $0.onTermination = { @Sendable [weak self] _ in
        Task { await self?.consumerTerminated(token: consumerToken) }
      }
    }
    launch(token: token)
    return stream
  }

  /// Pauses without polling or advancing the controller.
  public func pause() {
    generation &+= 1
    task?.cancel()
    task = nil
  }

  /// Resumes the current stream without creating a second loop.
  public func resume() {
    guard task == nil, continuation != nil else { return }
    generation &+= 1
    launch(token: generation)
  }

  /// Restarts physics and resumes the current stream, if any.
  public func restart(alpha: Double? = nil) async {
    let token = generation
    let consumerToken = consumerGeneration
    await controller.restart(alpha: alpha)
    await reentrancyProbe?(.restart)
    guard generation == token, consumerGeneration == consumerToken, continuation != nil else {
      return
    }
    resume()
  }

  /// Applies a scene revision and wakes the same stream when the update restarts physics.
  @discardableResult
  public func updateScene(
    _ scene: ForceGraphScene<ID, LinkID>, policy: SceneUpdatePolicy? = nil
  ) async -> SceneDiagnostics<ID, LinkID> {
    let token = generation
    let consumerToken = consumerGeneration
    let diagnostics: SceneDiagnostics<ID, LinkID>
    if let policy {
      diagnostics = await controller.updateScene(scene, policy: policy)
    } else {
      diagnostics = await controller.updateScene(scene)
    }
    await reentrancyProbe?(.updateScene)
    guard generation == token, consumerGeneration == consumerToken, continuation != nil else {
      return diagnostics
    }
    let frame = await controller.frame()
    guard generation == token, consumerGeneration == consumerToken, continuation != nil else {
      return diagnostics
    }
    continuation?.yield(frame)
    if frame.isLayoutRunning { resume() }
    return diagnostics
  }

  /// Returns whether the scheduler is stopped, dormant, or actively ticking.
  public func state() -> State {
    if continuation == nil { return .stopped }
    return task == nil ? .dormant : .running
  }

  /// Cancels work and finishes the current stream. Repeated calls are harmless.
  public func stop() {
    generation &+= 1
    consumerGeneration &+= 1
    task?.cancel()
    task = nil
    let current = continuation
    continuation = nil
    current?.onTermination = nil
    current?.finish()
  }

  private func launch(token: UInt64) {
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let delay = await self?.emit(token: token) else { return }
        do { try await Task.sleep(nanoseconds: delay) } catch { return }
      }
    }
  }

  private func emit(token: UInt64) async -> UInt64? {
    let consumerToken = consumerGeneration
    guard generation == token, continuation != nil else { return nil }
    let frame = await controller.tick(iterations: ticksPerFrame)
    await reentrancyProbe?(.emit)
    guard generation == token, consumerGeneration == consumerToken, continuation != nil else {
      return nil
    }
    continuation?.yield(frame)
    guard frame.isLayoutRunning else {
      task = nil
      return nil
    }
    return UInt64(1_000_000_000 / framesPerSecond)
  }

  private func consumerTerminated(token: UInt64) {
    guard consumerGeneration == token else { return }
    stop()
  }

  internal func setReentrancyProbe(
    _ probe: (@Sendable (ReentrancyPoint) async -> Void)?
  ) {
    reentrancyProbe = probe
  }

  private static func validFPS(_ value: Double) -> Double {
    value.isFinite && value > 0 ? min(240, max(1, value)) : 60
  }
}
