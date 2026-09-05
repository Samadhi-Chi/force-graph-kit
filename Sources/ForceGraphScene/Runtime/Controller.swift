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
  private var visualByID: [ID: NodeVisual] = [:]
  private var visibleIDs: Set<ID> = []
  private var neighbors: [ID: Set<ID>] = [:]
  private var renderTopologyRevision: UInt64

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
    self.renderTopologyRevision = normalized.topologyRevision
    simulation.replaceLinks(normalized.links.map(\.physics))
    simulation.force("charge", .manyBody())
    simulation.force("center", .center())
    simulation.tick(iterations: normalized.policy.warmupTicks)
    for node in normalized.nodes where visualByID[node.physics.id] == nil {
      visualByID[node.physics.id] = node.visual.sanitized
      if node.visual.isVisible { visibleIDs.insert(node.physics.id) }
    }
    for link in normalized.links {
      neighbors[link.physics.source, default: []].insert(link.physics.target)
      neighbors[link.physics.target, default: []].insert(link.physics.source)
    }
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

  /// Restarts layout scheduling, optionally raising alpha to a finite value.
  public func restart(alpha: Double? = nil) {
    if let alpha { reheat(alpha) } else { simulation.restart() }
    sequence &+= 1
  }

  /// Stops scheduled layout work; manual ``tick(iterations:)`` remains available.
  public func stop() {
    simulation.stop()
    sequence &+= 1
  }

  /// Selects a visible node or clears selection with `nil`; unknown/hidden IDs do nothing.
  public func select(_ id: ID?) {
    if let id {
      guard validVisible(id) else { return }
      selectedID = id
    } else {
      selectedID = nil
    }
    intentContinuation?.yield(.selected(selectedID))
    sequence &+= 1
  }

  /// Sets hover for a visible node or clears it with `nil`; unknown/hidden IDs do nothing.
  public func hover(_ id: ID?) {
    if let id {
      guard validVisible(id) else { return }
      hoveredID = id
    } else {
      hoveredID = nil
    }
    sequence &+= 1
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
    sequence &+= 1
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
    sequence &+= 1
  }

  /// Updates a visible dragged node's active fixed coordinates. Invalid values do nothing.
  public func updateDrag(id: ID, x: Double, y: Double = 0, z: Double = 0) {
    if updatePin(id: id, x: x, y: y, z: z) { sequence &+= 1 }
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
    sequence &+= 1
  }

  /// Replaces scene data using its normalized subset while preserving position, velocity, and
  /// fixed coordinates for retained IDs. Visuals, links, policy, visibility, and dimensions update.
  /// - Returns: Diagnostics for the unnormalized input revision.
  @discardableResult
  public func updateScene(_ updated: ForceGraphScene<ID, LinkID>) -> SceneDiagnostics<ID, LinkID> {
    updateScene(updated, policy: updated.policy.sceneUpdate)
  }

  /// Replaces scene data while explicitly controlling layout reheating.
  @discardableResult
  public func updateScene(
    _ updated: ForceGraphScene<ID, LinkID>, policy updatePolicy: SceneUpdatePolicy
  ) -> SceneDiagnostics<ID, LinkID> {
    let diagnostics = updated.diagnostics()
    let normalized = updated.normalized()
    let mechanicsChanged = mechanicsDiffer(scene, normalized)
    let membershipChanged = renderMembershipDiffers(scene, normalized)
    if normalized.topologyRevision != scene.topologyRevision || membershipChanged {
      renderTopologyRevision &+= 1
    }
    var old: [ID: ForceNode<ID>] = [:]
    for node in simulation.nodes where old[node.id] == nil { old[node.id] = node }
    let merged = normalized.nodes.map { old[$0.physics.id] ?? $0.physics }
    scene = normalized
    simulation.replaceNodes(merged)
    simulation.setDimensions(normalized.dimensions)
    simulation.replaceLinks(normalized.links.map(\.physics))
    rebuildSceneCache()
    switch updatePolicy {
    case .preserve: break
    case .restart: simulation.restart()
    case .reheat(let alpha): reheat(alpha)
    case .automatic(let alpha): if mechanicsChanged { reheat(alpha) }
    }
    if !validVisible(selectedID) { selectedID = nil }
    if !validVisible(focusedID) { focusedID = nil }
    if !validVisible(hoveredID) { hoveredID = nil }
    sequence &+= 1
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
    return visibleIDs.contains(id)
  }

  private func makeFrame() -> ForceGraphRenderFrame<ID, LinkID> {
    let snapshots = simulation.snapshots()
    var positions: [ID: NodeSnapshot<ID>] = [:]
    for snapshot in snapshots where positions[snapshot.id] == nil {
      positions[snapshot.id] = snapshot
    }
    let connected = selectedID.flatMap { neighbors[$0] } ?? []
    let labelIDs = visibleLabelIDs(connected: connected)
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
      return RenderNode(
        snapshot: snapshot, visual: visual, highlight: highlight,
        isLabelVisible: labelIDs.contains(snapshot.id) && !visual.label.isEmpty)
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
        visual: link.visual.sanitized,
        highlight: highlighted ? .connected : (selectedID == nil ? .normal : .dimmed))
    }
    return ForceGraphRenderFrame(
      sequence: sequence, alpha: simulation.alpha,
      dimensions: scene.dimensions, topologyRevision: renderTopologyRevision,
      visualRevision: scene.visualRevision, isLayoutRunning: simulation.isRunning,
      nodes: renderNodes,
      links: renderLinks, selectedID: selectedID, focusedID: focusedID)
  }

  private func intentTerminated(token: UInt64) {
    guard intentGeneration == token else { return }
    intentContinuation = nil
  }

  private func rebuildSceneCache() {
    visualByID.removeAll(keepingCapacity: true)
    visibleIDs.removeAll(keepingCapacity: true)
    neighbors.removeAll(keepingCapacity: true)
    for node in scene.nodes where visualByID[node.physics.id] == nil {
      visualByID[node.physics.id] = node.visual.sanitized
      if node.visual.isVisible { visibleIDs.insert(node.physics.id) }
    }
    for link in scene.links {
      neighbors[link.physics.source, default: []].insert(link.physics.target)
      neighbors[link.physics.target, default: []].insert(link.physics.source)
    }
  }

  private func visibleLabelIDs(connected: Set<ID>) -> Set<ID> {
    switch scene.policy.labelVisibility {
    case .none: return []
    case .all: return visibleIDs
    case .selectedAndNeighbors:
      var result = connected.intersection(visibleIDs)
      if let selectedID, visibleIDs.contains(selectedID) { result.insert(selectedID) }
      return result
    case .top(let count):
      guard count > 0 else { return [] }
      return Set(
        scene.nodes.enumerated().filter { visibleIDs.contains($0.element.physics.id) }
          .sorted {
            $0.element.visual.value == $1.element.visual.value
              ? $0.offset < $1.offset : $0.element.visual.value > $1.element.visual.value
          }.prefix(count).map { $0.element.physics.id })
    }
  }

  private func reheat(_ value: Double) {
    let safe = value.isFinite ? max(0, value) : 0.3
    simulation.alpha = max(simulation.alpha, safe)
    simulation.restart()
  }

  private func mechanicsDiffer(
    _ old: ForceGraphScene<ID, LinkID>, _ new: ForceGraphScene<ID, LinkID>
  ) -> Bool {
    if old.topologyRevision != new.topologyRevision || old.dimensions != new.dimensions
      || old.nodes.map(\.physics.id) != new.nodes.map(\.physics.id)
      || old.links.count != new.links.count
    {
      return true
    }
    return zip(old.links, new.links).contains { oldLink, newLink in
      oldLink.id != newLink.id || oldLink.physics.source != newLink.physics.source
        || oldLink.physics.target != newLink.physics.target
        || oldLink.physics.distance.bitPattern != newLink.physics.distance.bitPattern
        || oldLink.physics.strength?.bitPattern != newLink.physics.strength?.bitPattern
    }
  }

  private func renderMembershipDiffers(
    _ old: ForceGraphScene<ID, LinkID>, _ new: ForceGraphScene<ID, LinkID>
  ) -> Bool {
    let oldVisible = Set(old.nodes.lazy.filter(\.visual.isVisible).map(\.physics.id))
    let newVisible = Set(new.nodes.lazy.filter(\.visual.isVisible).map(\.physics.id))
    guard oldVisible == newVisible else { return true }
    let oldLinks = old.links.compactMap {
      $0.visual.isVisible && oldVisible.contains($0.physics.source)
        && oldVisible.contains($0.physics.target) ? $0.id : nil
    }
    let newLinks = new.links.compactMap {
      $0.visual.isVisible && newVisible.contains($0.physics.source)
        && newVisible.contains($0.physics.target) ? $0.id : nil
    }
    return oldLinks != newLinks
  }
}
