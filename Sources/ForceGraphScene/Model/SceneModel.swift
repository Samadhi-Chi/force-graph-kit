import ForceGraphCore

/// Renderer-neutral RGBA color with components conventionally in `0...1`.
public struct GraphColor: Sendable, Equatable {
  /// Red component.
  public let red: Double
  /// Green component.
  public let green: Double
  /// Blue component.
  public let blue: Double
  /// Alpha component.
  public let alpha: Double
  /// Creates a color from renderer-neutral components.
  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = Self.component(red)
    self.green = Self.component(green)
    self.blue = Self.component(blue)
    self.alpha = Self.component(alpha)
  }
  /// Default node blue.
  public static let blue = GraphColor(red: 0.2, green: 0.5, blue: 0.95)
  /// Default edge gray.
  public static let gray = GraphColor(red: 0.55, green: 0.55, blue: 0.6)

  private static func component(_ value: Double) -> Double {
    value.isFinite ? min(1, max(0, value)) : 0
  }
}

/// Renderer-neutral node appearance and semantic metadata.
public struct NodeVisual: Sendable, Equatable {
  /// Text parented to the node by renderers.
  public var label: String
  /// Base node color.
  public var color: GraphColor
  /// Geometry and collision radius in graph units.
  public var radius: Double
  /// Application value available for sizing policies.
  public var value: Double
  /// Whether the node and its label should be emitted.
  public var isVisible: Bool
  /// Creates a visual descriptor.
  public init(
    label: String, color: GraphColor = .blue, radius: Double = 0.02,
    value: Double = 1, isVisible: Bool = true
  ) {
    self.label = label
    self.color = color
    self.radius = radius.isFinite ? max(0, radius) : 0
    self.value = value.isFinite ? value : 0
    self.isVisible = isVisible
  }
}

extension NodeVisual {
  var sanitized: Self {
    Self(label: label, color: color, radius: radius, value: value, isVisible: isVisible)
  }
}

/// Renderer-neutral policy deciding which node labels are emitted independently of node geometry.
public enum LabelVisibilityPolicy: Sendable, Equatable {
  /// Hides every label.
  case none
  /// Shows labels for the selected node and its direct neighbors.
  case selectedAndNeighbors
  /// Shows labels for the highest-valued visible nodes, with stable scene order as the tie-breaker.
  case top(Int)
  /// Shows every non-empty label.
  case all
}

/// Describes how a scene replacement affects the running layout.
public enum SceneUpdatePolicy: Sendable, Equatable {
  /// Preserve the current temperature and scheduling state.
  case preserve
  /// Restart scheduling without changing temperature.
  case restart
  /// Raise alpha to at least the associated finite value and restart scheduling.
  case reheat(Double)
  /// Reheat only when topology, dimensions, or node physics inputs changed.
  case automatic(alpha: Double)
}

/// Renderer-neutral link appearance and direction metadata.
public struct LinkVisual: Sendable, Equatable {
  /// Base edge color.
  public var color: GraphColor
  /// Edge width in graph units.
  public var width: Double
  /// Whether the edge should be emitted.
  public var isVisible: Bool
  /// Whether a renderer may display source-to-target direction.
  public var isDirectional: Bool
  /// Creates a link visual descriptor.
  public init(
    color: GraphColor = .gray, width: Double = 0.004,
    isVisible: Bool = true, isDirectional: Bool = false
  ) {
    self.color = color
    self.width = width.isFinite ? max(0, width) : 0
    self.isVisible = isVisible
    self.isDirectional = isDirectional
  }
}

extension LinkVisual {
  var sanitized: Self {
    Self(color: color, width: width, isVisible: isVisible, isDirectional: isDirectional)
  }
}

/// Stable scene node combining physics and visual state.
public struct SceneNode<ID: Hashable & Sendable>: Sendable {
  /// Physics state and stable identity.
  public var physics: ForceNode<ID>
  /// Visual metadata.
  public var visual: NodeVisual
  /// Creates a scene node.
  public init(physics: ForceNode<ID>, visual: NodeVisual) {
    self.physics = physics
    self.visual = visual
  }
}

/// Stable scene link. Its ID is independent of endpoint IDs, allowing parallel edges.
public struct SceneLink<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable {
  /// Stable link identity, including support for parallel edges.
  public let id: LinkID
  /// Physics endpoints and parameters.
  public var physics: ForceLink<ID>
  /// Visual metadata.
  public var visual: LinkVisual
  /// Creates a scene link.
  public init(id: LinkID, physics: ForceLink<ID>, visual: LinkVisual = LinkVisual()) {
    self.id = id
    self.physics = physics
    self.visual = visual
  }
}

/// Warmup and cooling policy used by ``ForceGraphController``.
public struct LayoutPolicy: Sendable, Equatable {
  /// Synchronous ticks performed when a controller is initialized.
  public var warmupTicks: Int
  /// Alpha target while dragging.
  public var dragAlphaTarget: Double
  /// Alpha target after drag completion.
  public var releaseAlphaTarget: Double
  /// Label selection policy. Labels remain independent of node visibility in render payloads.
  public var labelVisibility: LabelVisibilityPolicy
  /// Default behavior for scene replacements.
  public var sceneUpdate: SceneUpdatePolicy
  /// Creates a layout policy.
  public init(
    warmupTicks: Int = 30, dragAlphaTarget: Double = 0.3,
    releaseAlphaTarget: Double = 0, labelVisibility: LabelVisibilityPolicy = .none,
    sceneUpdate: SceneUpdatePolicy = .automatic(alpha: 0.3)
  ) {
    self.warmupTicks = max(0, warmupTicks)
    self.dragAlphaTarget = dragAlphaTarget.isFinite ? dragAlphaTarget : 0.3
    self.releaseAlphaTarget = releaseAlphaTarget.isFinite ? releaseAlphaTarget : 0
    self.labelVisibility = labelVisibility
    self.sceneUpdate = sceneUpdate
  }
}

/// Stable-identity and endpoint issues found in a scene revision.
public struct SceneDiagnostics<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable {
  /// Repeated node IDs after their first occurrence.
  public let duplicateNodeIDs: [ID]
  /// Repeated link IDs after their first occurrence.
  public let duplicateLinkIDs: [LinkID]
  /// Link IDs with an unresolved endpoint.
  public let unresolvedLinkIDs: [LinkID]
  /// Link IDs whose source equals target.
  public let selfLinkIDs: [LinkID]
  /// Whether the revision has no identity or endpoint issues.
  public var isValid: Bool {
    duplicateNodeIDs.isEmpty && duplicateLinkIDs.isEmpty
      && unresolvedLinkIDs.isEmpty && selfLinkIDs.isEmpty
  }
}

extension ForceGraphScene {
  /// Validates stable node/link identity and link endpoints without mutating the scene.
  public func diagnostics() -> SceneDiagnostics<ID, LinkID> {
    var nodeIDs = Set<ID>()
    var duplicateNodes: [ID] = []
    for node in nodes
    where !nodeIDs.insert(node.physics.id).inserted
      && !duplicateNodes.contains(node.physics.id)
    { duplicateNodes.append(node.physics.id) }
    var linkIDs = Set<LinkID>()
    var duplicateLinks: [LinkID] = []
    for link in links
    where !linkIDs.insert(link.id).inserted
      && !duplicateLinks.contains(link.id)
    { duplicateLinks.append(link.id) }
    return SceneDiagnostics(
      duplicateNodeIDs: duplicateNodes,
      duplicateLinkIDs: duplicateLinks,
      unresolvedLinkIDs: links.filter {
        !nodeIDs.contains($0.physics.source) || !nodeIDs.contains($0.physics.target)
      }.map(\.id),
      selfLinkIDs: links.filter { $0.physics.source == $0.physics.target }.map(\.id)
    )
  }

  /// Returns the deterministic safe subset used by the controller: first occurrence of each
  /// node/link ID, with self-links and unresolved links removed.
  public func normalized() -> Self {
    var nodeIDs = Set<ID>()
    let safeNodes = nodes.filter { nodeIDs.insert($0.physics.id).inserted }
    var linkIDs = Set<LinkID>()
    let safeLinks = links.filter {
      linkIDs.insert($0.id).inserted && $0.physics.source != $0.physics.target
        && nodeIDs.contains($0.physics.source) && nodeIDs.contains($0.physics.target)
    }
    return Self(
      nodes: safeNodes, links: safeLinks, dimensions: dimensions, policy: policy,
      topologyRevision: topologyRevision, visualRevision: visualRevision)
  }
}

/// Complete renderer-independent graph description.
public struct ForceGraphScene<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable {
  /// Stable scene nodes in deterministic order.
  public var nodes: [SceneNode<ID>]
  /// Stable scene links in deterministic order.
  public var links: [SceneLink<ID, LinkID>]
  /// Active simulation and rendering dimensions.
  public var dimensions: SimulationDimensions
  /// Warmup and drag cooling policy.
  public var policy: LayoutPolicy
  /// Caller-controlled topology hint. Controllers also advance their emitted render revision when
  /// node/link membership changes, so correctness does not depend on maintaining this value.
  public var topologyRevision: UInt64
  /// Caller-controlled visual revision used to invalidate renderer geometry and materials.
  public var visualRevision: UInt64
  /// Creates a scene description.
  public init(
    nodes: [SceneNode<ID>], links: [SceneLink<ID, LinkID>] = [],
    dimensions: SimulationDimensions = .three, policy: LayoutPolicy = LayoutPolicy(),
    topologyRevision: UInt64 = 0, visualRevision: UInt64 = 0
  ) {
    self.nodes = nodes
    self.links = links
    self.dimensions = dimensions
    self.policy = policy
    self.topologyRevision = topologyRevision
    self.visualRevision = visualRevision
  }

  /// Returns a deterministic filtered copy, retaining original node/link order and only
  /// links whose two endpoints survive.
  public func filtered(_ include: @Sendable (SceneNode<ID>) -> Bool) -> Self {
    let retained = nodes.filter(include)
    let ids = Set(retained.map { $0.physics.id })
    return Self(
      nodes: retained,
      links: links.filter {
        ids.contains($0.physics.source) && ids.contains($0.physics.target)
      }, dimensions: dimensions, policy: policy,
      topologyRevision: topologyRevision, visualRevision: visualRevision)
  }
}
