import AVFoundation
import SwiftUI

@main
struct VisioApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .environmentObject(store)
                .task {
                    // Demande l'accès caméra dès le premier lancement,
                    // pour ne jamais voir la question pendant un tour.
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                }
        }
    }
}
