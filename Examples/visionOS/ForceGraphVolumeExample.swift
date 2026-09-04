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

    var body: some View {
      RealityView { content in content.add(synchronizer.root) }
        .task {
          while !Task.isCancelled {
            synchronizer.synchronize(frame: await controller.tick())
            try? await Task.sleep(for: .milliseconds(16))
          }
        }
      // Add targeted spatial tap/drag gestures in the host app and forward world-space
      // coordinates to beginDrag/updateDrag/endDrag. Details remain application-owned.
    }
  }
#endif
