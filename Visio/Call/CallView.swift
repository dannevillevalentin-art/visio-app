import SwiftUI
import UIKit

/// L'écran d'appel simulé.
///
/// - Pendant la sonnerie : la caméra frontale occupe tout l'écran.
///   Toucher l'écran fait « décrocher » tout de suite.
/// - Une fois connecté : la vidéo occupe l'écran, la caméra frontale passe
///   dans un coin (déplaçable au doigt), les icônes se cachent après un délai
///   et réapparaissent au toucher.
struct CallView: View {
    let slot: CallSlot
    let settings: AppSettings
    /// Appel entrant décroché depuis l'écran d'appel d'iOS : pas de sonnerie,
    /// la vidéo démarre dès que l'app est à l'écran.
    var viaCallKit = false
    /// animated = false : fermeture instantanée (après un retour à l'accueil).
    let onFinish: (_ animated: Bool) -> Void

    @StateObject private var session: CallSession
    @StateObject private var camera = FrontCamera()
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var pipCorner: PipCorner
    @State private var dragOffset: CGSize = .zero
    @State private var showFakeHome = false
    @State private var ended = false
    @Environment(\.scenePhase) private var scenePhase

    init(slot: CallSlot, settings: AppSettings, viaCallKit: Bool = false, onFinish: @escaping (_ animated: Bool) -> Void) {
        self.slot = slot
        self.settings = settings
        self.viaCallKit = viaCallKit
        self.onFinish = onFinish
        _session = StateObject(wrappedValue: CallSession(videoURL: slot.videoFile.map(Media.url)))
        _pipCorner = State(initialValue: (slot.style ?? settings.defaultStyle).defaultPipCorner)
    }

    private var style: CallStyle { slot.style ?? settings.defaultStyle }
    private var contactName: String {
        let name = slot.contactName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? settings.defaultContactName : name
    }
    private var connected: Bool { viaCallKit || session.phase == .connected }

    var body: some View {
        ZStack {
            GeometryReader { outer in
                let insets = outer.safeAreaInsets
                ZStack {
                    GeometryReader { geo in
                        stage(size: geo.size, insets: insets)
                    }
                    .ignoresSafeArea()

                    CallChrome(
                        style: style,
                        connected: connected,
                        name: contactName,
                        photo: Media.image(slot.contactPhotoFile),
                        elapsed: session.elapsed,
                        onEnd: endCall
                    )
                    .opacity(controlsVisible || !connected ? 1 : 0)
                    .allowsHitTesting(controlsVisible || !connected)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: handleTap)
            }

            if showFakeHome {
                FakeHomeView(image: Media.image(settings.fakeHomeFile)) {
                    onFinish(false)
                }
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: session.phase)
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
        .statusBarHidden(showFakeHome)
        .preferredColorScheme(.dark)
        .onAppear(perform: begin)
        .onDisappear(perform: cleanUp)
        .onChange(of: session.phase) { _, phase in
            if phase == .connected { scheduleHide() }
        }
        .onChange(of: scenePhase) { _, phase in
            if viaCallKit && phase == .active && !ended { session.connect() }
        }
    }

    // MARK: - Vidéo + caméra

    @ViewBuilder
    private func stage(size: CGSize, insets: EdgeInsets) -> some View {
        let rect = cameraRect(size: size, insets: insets, corner: pipCorner)
        ZStack(alignment: .topLeading) {
            Color.black
            PlayerSurface(player: session.player)
                .frame(width: size.width, height: size.height)
                .opacity(connected ? 1 : 0)
            CameraPreview(session: camera.session)
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: connected ? 14 : 0, style: .continuous))
                .overlay { Color.clear.contentShape(Rectangle()) }
                .offset(x: rect.minX + dragOffset.width, y: rect.minY + dragOffset.height)
                .gesture(pipDrag(size: size, insets: insets))
                .allowsHitTesting(connected)
        }
        .frame(width: size.width, height: size.height)
    }

    private func cameraRect(size: CGSize, insets: EdgeInsets, corner: PipCorner) -> CGRect {
        guard connected else { return CGRect(origin: .zero, size: size) }
        let width = (size.width * 0.28).rounded()
        let height = (width * 1.5).rounded()
        let margin: CGFloat = 12
        let x = corner.isLeft ? margin : size.width - margin - width
        let y = corner.isTop
            ? insets.top + style.pipTopInset
            : size.height - insets.bottom - style.pipBottomInset - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func pipDrag(size: CGSize, insets: EdgeInsets) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let rect = cameraRect(size: size, insets: insets, corner: pipCorner)
                let x = rect.midX + value.predictedEndTranslation.width
                let y = rect.midY + value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pipCorner = PipCorner(left: x < size.width / 2, top: y < size.height / 2)
                    dragOffset = .zero
                }
            }
    }

    // MARK: - Déroulé

    private func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        camera.start()
        session.onVideoEnd = {
            if slot.hangUpAtEnd {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { endCall() }
            }
        }
        if viaCallKit {
            // L'audio est géré par l'appel iOS. La vidéo attend que l'app soit visible
            // (après déverrouillage si le téléphone était verrouillé).
            if UIApplication.shared.applicationState == .active { session.connect() }
        } else {
            session.start(ringSeconds: settings.ringSeconds, ringbackSound: settings.ringbackSound)
        }
    }

    private func cleanUp() {
        hideTask?.cancel()
        session.stop()
        camera.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handleTap() {
        guard !ended else { return }
        if session.phase != .connected {
            session.connect()
        } else if controlsVisible {
            hideTask?.cancel()
            controlsVisible = false
        } else {
            controlsVisible = true
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        let delay = settings.hideControlsAfter
        guard delay > 0 else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private func endCall() {
        guard !ended else { return }
        ended = true
        hideTask?.cancel()
        session.stop()
        camera.stop()
        if viaCallKit { IncomingCallManager.shared.hangUpFromApp() }

        var action = settings.endAction
        if action == .fakeHome && settings.fakeHomeFile == nil { action = .homeScreen }

        switch action {
        case .gallery:
            onFinish(true)
        case .fakeHome:
            withAnimation(.easeOut(duration: 0.25)) { showFakeHome = true }
        case .homeScreen:
            SystemHome.go()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onFinish(false) }
        }
    }
}

/// Capture d'écran de l'écran d'accueil, affichée après l'appel.
/// Appui long (1 s) pour revenir à la galerie.
struct FakeHomeView: View {
    let image: UIImage?
    let onExit: () -> Void

    var body: some View {
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1) { onExit() }
    }
}
