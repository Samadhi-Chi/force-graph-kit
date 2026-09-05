import ForceGraphCore

/// Interaction styling calculated by the scene controller.
public enum HighlightState: Sendable, Equatable {
  /// No active interaction styling.
  case normal
  /// The directly selected node.
  case selected
  /// A selected node's incident node or edge.
  case connected
  /// Non-neighbor while another node is selected.
  case dimmed
  /// Pointer or gaze hover target.
  case hovered
}

/// Node payload consumed by a renderer from one authoritative transform source.
public struct RenderNode<ID: Hashable & Sendable>: Sendable {
  /// Complete authoritative physics state.
  public let snapshot: NodeSnapshot<ID>
  /// Visual metadata for geometry and the attached label.
  public let visual: NodeVisual
  /// Controller-computed interaction styling.
  public let highlight: HighlightState
  /// Whether a renderer should create or show this node's label.
  public let isLabelVisible: Bool
}

/// Edge payload containing endpoint positions from the same frame as its nodes and labels.
public struct RenderLink<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable {
  /// Stable edge identity.
  public let id: LinkID
  /// Stable source node identity.
  public let source: ID
  /// Stable target node identity.
  public let target: ID
  /// Source position from this frame.
  public let sourcePosition: (x: Double, y: Double, z: Double)
  /// Target position from this frame.
  public let targetPosition: (x: Double, y: Double, z: Double)
  /// Visual edge metadata.
  public let visual: LinkVisual
  /// Controller-computed interaction styling.
  public let highlight: HighlightState
}

/// Immutable scene frame. Labels are properties of `nodes`, so they cannot use a stale transform.
public struct ForceGraphRenderFrame<ID: Hashable & Sendable, LinkID: Hashable & Sendable>: Sendable
{
  /// Monotonically increasing controller frame number.
  public let sequence: UInt64
  /// Simulation alpha represented by this frame.
  public let alpha: Double
  /// Active dimensions.
  public let dimensions: SimulationDimensions
  /// Scene topology revision represented by this frame.
  public let topologyRevision: UInt64
  /// Scene visual revision represented by this frame.
  public let visualRevision: UInt64
  /// Whether physics still requires scheduled ticks.
  public let isLayoutRunning: Bool
  /// Visible nodes and their attached-label metadata.
  public let nodes: [RenderNode<ID>]
  /// Visible resolvable links.
  public let links: [RenderLink<ID, LinkID>]
  /// Current selection.
  public let selectedID: ID?
  /// Current focus request target.
  public let focusedID: ID?
}

/// UI-neutral controller intent suitable for SwiftUI, UIKit, or custom renderers.
public enum ForceGraphIntent<ID: Hashable & Sendable>: Sendable {
  /// Selection changed.
  case selected(ID?)
  /// Focus changed.
  case focused(ID?)
  /// Application-owned details were requested.
  case details(ID)
  /// Renderer should fit the current graph.
  case fitRequested
}
