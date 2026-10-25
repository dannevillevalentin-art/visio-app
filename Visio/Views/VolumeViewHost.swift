import MediaPlayer
import SwiftUI

/// Contrôle de volume système invisible. Il est nécessaire pour que l'app
/// puisse régler le volume du téléphone, et il masque aussi la bulle de volume d'iOS.
struct VolumeViewHost: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        view.alpha = 0.011
        view.isUserInteractionEnabled = false
        IncomingCallManager.shared.volumeView = view
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        IncomingCallManager.shared.volumeView = uiView
    }
}
