import ForceGraphCore

/// Actor coordinating normalized scene state, physics, interaction, and immutable render frames.
/// Missing or hidden interaction IDs are safe no-ops. A controller accepts only the deterministic
/// normalized subset of a scene; call ``ForceGraphScene/diagnostics()`` before updates to surface
/// duplicate identities, unresolved endpoints, or self-links to users.
public actor ForceGraphController<ID: Hashable & Sendable, LinkID: Hashable & Sendable> {
  private var scene: ForceGraphScene<ID, LinkID>
  private var simulation: ForceSimulation<ID>
  private var selectedID: ID?
  private var focusedID: ID?
  private var hoveredID: ID?
  private var sequence: UInt64 = 0
  private var intentContinuation: AsyncStream<ForceGraphIntent<ID>>.Continuation?
  private var intentGeneration: UInt64 = 0

  /// Creates a controller from the scene's normalized subset and performs configured warmup.
  /// - Parameters:
  ///   - scene: Renderer-neutral scene revision.
  ///   - seed: D3-compatible deterministic random seed.
  public init(scene: ForceGraphScene<ID, LinkID>, seed: UInt32 = 1) {
    let normalized = scene.normalized()
    self.scene = normalized
    self.simulation = ForceSimulation(
      nodes: normalized.nodes.map(\.physics),
      dimensions: normalized.dimensions, seed: seed)
    simulation.replaceLinks(normalized.links.map(\.physics))
    simulation.force("charge", .manyBody())
    simulation.force("center", .center())
    simulation.tick(iterations: normalized.policy.warmupTicks)
  }

  deinit { intentContinuation?.finish() }

  /// Creates a newest-event-buffered intent stream, finishing the previous consumer.
  public func intents() -> AsyncStream<ForceGraphIntent<ID>> {
    intentGeneration &+= 1
    let token = intentGeneration
    intentContinuation?.onTermination = nil
    intentContinuation?.finish()
    return AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
      intentContinuation = continuation
      continuation.onTermination = { @Sendable [weak self] _ in
        Task { await self?.intentTerminated(token: token) }
      }
    }
  }

  /// Advances physics and returns one immutable synchronized frame.
  public func tick(iterations: Int = 1) -> ForceGraphRenderFrame<ID, LinkID> {
    simulation.tick(iterations: iterations)
    sequence &+= 1
    return makeFrame()
  }

  /// Returns current state without advancing physics.
  public func frame() -> ForceGraphRenderFrame<ID, LinkID> { makeFrame() }

  /// Selects a visible node or clears selection with `nil`; unknown/hidden IDs do nothing.
  public func select(_ id: ID?) {
    if let id {
      guard validVisible(id) else { return }
      selectedID = id
    } else {
      selectedID = nil
    }
    intentContinuation?.yield(.selected(selectedID))
  }

  /// Sets hover for a visible node or clears it with `nil`; unknown/hidden IDs do nothing.
  public func hover(_ id: ID?) {
    if let id {
      guard validVisible(id) else { return }
      hoveredID = id
    } else {
      hoveredID = nil
    }
  }

  /// Focuses a visible node or clears focus with `nil`; unknown/hidden IDs do nothing.
  public func focus(_ id: ID?) {
    if let id {
      guard validVisible(id) else { return }
      focusedID = id
    } else {
      focusedID = nil
    }
    intentContinuation?.yield(.focused(focusedID))
  }

  /// Requests application-owned details for a visible node. Unknown/hidden IDs do nothing.
  public func requestDetails(for id: ID) {
    guard validVisible(id) else { return }
    intentContinuation?.yield(.details(id))
  }

  /// Emits a camera-neutral fit request.
  public func requestFit() { intentContinuation?.yield(.fitRequested) }

  /// Selects and pins a visible node on active axes, then reheats the layout.
  public func beginDrag(id: ID, x: Double, y: Double = 0, z: Double = 0) {
    guard updatePin(id: id, x: x, y: y, z: z) else { return }
    selectedID = id
    simulation.alphaTarget = scene.policy.dragAlphaTarget
    simulation.restart()
  }

  /// Updates a visible dragged node's active fixed coordinates. Invalid values do nothing.
  public func updateDrag(id: ID, x: Double, y: Double = 0, z: Double = 0) {
    _ = updatePin(id: id, x: x, y: y, z: z)
  }

  /// Ends drag for a visible node, optionally retaining its pin, then cools per policy.
  public func endDrag(id: ID, keepPinned: Bool = false) {
    guard validVisible(id) else { return }
    if !keepPinned {
      simulation.updateNode(id: id) {
        $0.fx = nil
        $0.fy = nil
        $0.fz = nil
      }
    }
    simulation.alphaTarget = scene.policy.releaseAlphaTarget
  }

  /// Replaces scene data using its normalized subset while preserving position, velocity, and
  /// fixed coordinates for retained IDs. Visuals, links, policy, visibility, and dimensions update.
  /// - Returns: Diagnostics for the unnormalized input revision.
  @discardableResult
  public func updateScene(_ updated: ForceGraphScene<ID, LinkID>) -> SceneDiagnostics<ID, LinkID> {
    let diagnostics = updated.diagnostics()
    let normalized = updated.normalized()
    var old: [ID: ForceNode<ID>] = [:]
    for node in simulation.nodes where old[node.id] == nil { old[node.id] = node }
    let merged = normalized.nodes.map { old[$0.physics.id] ?? $0.physics }
    scene = normalized
    simulation.replaceNodes(merged)
    simulation.setDimensions(normalized.dimensions)
    simulation.replaceLinks(normalized.links.map(\.physics))
    if !validVisible(selectedID) { selectedID = nil }
    if !validVisible(focusedID) { focusedID = nil }
    if !validVisible(hoveredID) { hoveredID = nil }
    return diagnostics
  }

  private func updatePin(id: ID, x: Double, y: Double, z: Double) -> Bool {
    guard validVisible(id), x.isFinite,
      scene.dimensions == .one || y.isFinite,
      scene.dimensions != .three || z.isFinite
    else { return false }
    let dimensions = scene.dimensions
    return simulation.updateNode(id: id) {
      $0.fx = x
      if dimensions.rawValue > 1 { $0.fy = y }
      if dimensions.rawValue > 2 { $0.fz = z }
    }
  }

  private func validVisible(_ id: ID?) -> Bool {
    guard let id else { return false }
    return scene.nodes.contains { $0.physics.id == id && $0.visual.isVisible }
  }

  private func makeFrame() -> ForceGraphRenderFrame<ID, LinkID> {
    let snapshots = simulation.snapshots()
    var positions: [ID: NodeSnapshot<ID>] = [:]
    for snapshot in snapshots where positions[snapshot.id] == nil {
      positions[snapshot.id] = snapshot
    }
    var visualByID: [ID: NodeVisual] = [:]
    for node in scene.nodes where visualByID[node.physics.id] == nil {
      visualByID[node.physics.id] = node.visual
    }
    let visibleIDs = Set(visualByID.compactMap { $0.value.isVisible ? $0.key : nil })
    let connected: Set<ID> =
      selectedID.map { selected in
        Set(
          scene.links.flatMap { link -> [ID] in
            if link.physics.source == selected { return [link.physics.target] }
            if link.physics.target == selected { return [link.physics.source] }
            return []
          })
      } ?? []
    let renderNodes = snapshots.compactMap { snapshot -> RenderNode<ID>? in
      guard let visual = visualByID[snapshot.id], visual.isVisible else { return nil }
      let highlight: HighlightState
      if snapshot.id == hoveredID {
        highlight = .hovered
      } else if snapshot.id == selectedID {
        highlight = .selected
      } else if connected.contains(snapshot.id) {
        highlight = .connected
      } else if selectedID != nil {
        highlight = .dimmed
      } else {
        highlight = .normal
      }
      return RenderNode(snapshot: snapshot, visual: visual, highlight: highlight)
    }
    let renderLinks = scene.links.compactMap { link -> RenderLink<ID, LinkID>? in
      guard link.visual.isVisible,
        visibleIDs.contains(link.physics.source), visibleIDs.contains(link.physics.target),
        let source = positions[link.physics.source],
        let target = positions[link.physics.target]
      else { return nil }
      let highlighted = selectedID == link.physics.source || selectedID == link.physics.target
      return RenderLink(
        id: link.id, source: link.physics.source, target: link.physics.target,
        sourcePosition: (source.x, source.y, source.z),
        targetPosition: (target.x, target.y, target.z),
        visual: link.visual, highlight: highlighted ? .connected : .normal)
    }
    return ForceGraphRenderFrame(
      sequence: sequence, alpha: simulation.alpha,
      dimensions: scene.dimensions, nodes: renderNodes,
      links: renderLinks, selectedID: selectedID, focusedID: focusedID)
  }

  private func intentTerminated(token: UInt64) {
    guard intentGeneration == token else { return }
    intentContinuation = nil
  }
}
