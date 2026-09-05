import ForceGraphScene

/// Compile-oriented host callbacks that keep speculative gesture APIs outside the package.
/// A visionOS view converts its verified targeted-gesture location into graph coordinates,
/// then invokes these callbacks. The controller remains the only simulation owner.
struct HostInteractionCallbacks: Sendable {
  let tap: @Sendable (_ nodeID: String) async -> Void
  let details: @Sendable (_ nodeID: String) async -> Void
  let dragBegan: @Sendable (_ nodeID: String, _ position: GraphPosition) async -> Void
  let dragChanged: @Sendable (_ nodeID: String, _ position: GraphPosition) async -> Void
  let dragEnded: @Sendable (_ nodeID: String, _ keepPinned: Bool) async -> Void
  let fit: @Sendable () async -> Void

  static func forwarding(
    to controller: ForceGraphController<String, String>,
    scheduler: ForceGraphSceneScheduler<String, String>
  ) -> Self {
    Self(
      tap: {
        await controller.select($0)
        await scheduler.restart()
      },
      details: { await controller.requestDetails(for: $0) },
      dragBegan: { id, point in
        await controller.beginDrag(id: id, x: point.x, y: point.y, z: point.z)
        await scheduler.resume()
      },
      dragChanged: { id, point in
        await controller.updateDrag(id: id, x: point.x, y: point.y, z: point.z)
        await scheduler.resume()
      },
      dragEnded: { id, keepPinned in
        await controller.endDrag(id: id, keepPinned: keepPinned)
        await scheduler.resume()
      },
      fit: { await controller.requestFit() })
  }
}

struct GraphPosition: Sendable {
  let x: Double
  let y: Double
  let z: Double
}
