import AVFoundation
import SwiftUI
import UIKit

/// Déroulé d'un appel : sonnerie → connexion → lecture de la vidéo.
@MainActor
final class CallSession: ObservableObject {
    enum Phase: Equatable { case calling, connected }

    @Published private(set) var phase: Phase = .calling
    @Published private(set) var elapsed = 0

    let player: AVPlayer
    var onVideoEnd: (() -> Void)?

    private var ringTask: Task<Void, Never>?
    private var timer: Timer?
    private var endObserver: NSObjectProtocol?
    private let ringback = Ringback()

    init(videoURL: URL?) {
        if let videoURL {
            player = AVPlayer(url: videoURL)
        } else {
            player = AVPlayer()
        }
        player.actionAtItemEnd = .pause
    }

    func start(ringSeconds: Double, ringbackSound: Bool) {
        let audio = AVAudioSession.sharedInstance()
        // .playback : le son sort même si l'iPhone est en mode silencieux.
        try? audio.setCategory(.playback, mode: .default, options: [])
        try? audio.setActive(true)

        if ringbackSound { ringback.start() }
        let delay = max(0, ringSeconds)
        ringTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    func connect() {
        guard phase == .calling else { return }
        ringTask?.cancel()
        ringback.stop()
        phase = .connected
        player.play()

        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let seconds = Int(Date().timeIntervalSince(start))
                if seconds != self.elapsed { self.elapsed = seconds }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onVideoEnd?() }
        }
    }

    func stop() {
        ringTask?.cancel()
        ringTask = nil
        ringback.stop()
        timer?.invalidate()
        timer = nil
        player.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}

/// Retour vidéo de la caméra frontale (rien n'est enregistré).
final class FrontCamera: ObservableObject {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "visio.front-camera")
    private var configured = false

    func start() {
        queue.async { [self] in
            if !configured { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        configured = true
        session.beginConfiguration()
        session.automaticallyConfiguresApplicationAudioSession = false
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }
}

/// Tonalité de retour d'appel (440 Hz, 1,5 s / 3,5 s, comme en France).
final class Ringback {
    private var player: AVAudioPlayer?

    func start() {
        if player == nil {
            player = try? AVAudioPlayer(data: Self.makeWAV())
            player?.numberOfLoops = -1
            player?.volume = 0.6
        }
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        player?.stop()
    }

    private static func makeWAV() -> Data {
        let rate = 22_050
        let frequency = 440.0
        let samplesTotal = rate * 5
        let samplesOn = Int(Double(rate) * 1.5)
        let fade = rate / 100
        var samples = [Int16](repeating: 0, count: samplesTotal)
        for i in 0..<samplesOn {
            var amplitude = 0.35
            if i < fade { amplitude *= Double(i) / Double(fade) }
            if i > samplesOn - fade { amplitude *= Double(samplesOn - i) / Double(fade) }
            let value = amplitude * 32_767 * sin(2 * .pi * frequency * Double(i) / Double(rate))
            samples[i] = Int16(value)
        }

        var data = Data()
        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        let dataSize = UInt32(samples.count * 2)
        append("RIFF"); append32(36 + dataSize); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(rate)); append32(UInt32(rate * 2)); append16(2); append16(16)
        append("data"); append32(dataSize)
        for sample in samples { append16(UInt16(bitPattern: sample)) }
        return data
    }
}

/// Renvoie sur l'écran d'accueil avec l'animation normale d'iOS
/// (comme un balayage vers le haut). Usage privé uniquement : refusé sur l'App Store.
enum SystemHome {
    static func go() {
        UIControl().sendAction(NSSelectorFromString("suspend"), to: UIApplication.shared, for: nil)
    }
}

// MARK: - Surfaces vidéo

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}
