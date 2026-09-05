#if os(visionOS) && canImport(SwiftUI) && canImport(RealityKit)
  import ForceGraphRealityKit
  import ForceGraphScene
  import RealityKit
  import SwiftUI

  // Compile this source in a visionOS app target after adding ForceGraphKit through SwiftPM.
  // The app owns controller lifetime and presents this view in a WindowGroup volumetric style.
  @available(visionOS 2.0, *)
  struct ForceGraphVolumeExample: View {
    let controller: ForceGraphController<String, String>
    @State private var synchronizer = RealityKitGraphSynchronizer<String, String>()
    let scheduler: ForceGraphSceneScheduler<String, String>

    var body: some View {
      RealityView { content in content.add(synchronizer.root) }
        .task {
          for await frame in await scheduler.start() {
            synchronizer.synchronize(frame: frame)
          }
        }
        .onDisappear { Task { await scheduler.stop() } }
      // Add targeted spatial tap/drag gestures in the host app and forward world-space
      // coordinates to beginDrag/updateDrag/endDrag. Details remain application-owned.
    }
  }
#endif
