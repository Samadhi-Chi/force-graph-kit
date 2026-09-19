#if os(visionOS)
  import ForceGraphCore
  import ForceGraphScene
  import SwiftUI

  @main
  @available(visionOS 2.0, *)
  @MainActor
  struct ForceGraphVisionSample: App {
    private let controller: ForceGraphController<String, String>
    private let scheduler: ForceGraphSceneScheduler<String, String>

    init() {
      let scene = ForceGraphScene(
        nodes: [
          SceneNode(
            physics: ForceNode(id: "a", x: -20, y: 0), visual: NodeVisual(label: "A", radius: 3)
          ),
          SceneNode(
            physics: ForceNode(id: "b", x: 20, y: 0), visual: NodeVisual(label: "B", radius: 3)),
        ],
        links: [
          SceneLink(
            id: "ab", physics: ForceLink(source: "a", target: "b"),
            visual: LinkVisual(width: 0.4))
        ],
        dimensions: .two, policy: LayoutPolicy(warmupTicks: 0), topologyRevision: 1)
      let controller = ForceGraphController(scene: scene)
      self.controller = controller
      self.scheduler = ForceGraphSceneScheduler(controller: controller)
    }

    var body: some Scene {
      WindowGroup {
        ForceGraphVolumeExample(controller: controller, scheduler: scheduler)
      }.windowStyle(.volumetric)
    }
  }
#endif
