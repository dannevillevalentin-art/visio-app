import AVFoundation
import CallKit
import MediaPlayer
import SwiftUI
import UIKit

/// Mode « il m'appelle » :
/// 1. on choisit une vidéo → l'appel est programmé (armé) ;
/// 2. un appui sur un bouton de volume (même écran verrouillé) lance le compte à rebours ;
/// 3. après le délai, un vrai appel entrant iOS (CallKit) sonne ;
/// 4. quand on décroche, l'app affiche l'écran d'appel avec la vidéo.
///
/// Une boucle audio silencieuse garde l'app active écran verrouillé
/// (même principe que Sonore).
@MainActor
final class IncomingCallManager: NSObject, ObservableObject {
    static let shared = IncomingCallManager()

    enum State: Equatable { case idle, armed, waiting, ringing, active }

    struct Request: Equatable {
        let slot: CallSlot
        let name: String
        let handle: String
        let delay: Double
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var request: Request?
    /// Appel décroché : la galerie présente l'écran d'appel.
    @Published var answeredSlot: CallSlot?

    /// Contrôle de volume invisible, fourni par VolumeViewHost.
    weak var volumeView: MPVolumeView?

    private let provider: CXProvider
    private let controller = CXCallController()
    private var callUUID: UUID?
    private var endingFromApp = false
    private var volumeObservation: NSKeyValueObservation?
    private var interruptionObserver: NSObjectProtocol?
    private var silentPlayer: AVAudioPlayer?
    private var ignoreVolumeUntil = Date.distantPast
    private var triggerTask: Task<Void, Never>?

    var armedSlotID: UUID? {
        state == .armed || state == .waiting ? request?.slot.id : nil
    }

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.phoneNumber, .emailAddress, .generic]
        config.includesCallsInRecents = false
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Programmer / annuler

    func arm(_ request: Request) {
        guard state == .idle || state == .armed else { return }
        self.request = request
        startListening()
        state = .armed
    }

    func disarm() {
        guard state == .armed || state == .waiting else { return }
        triggerTask?.cancel()
        triggerTask = nil
        stopListening()
        request = nil
        state = .idle
    }

    // MARK: - Bouton de volume

    private func startListening() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        startSilentLoop()

        // Au maximum (ou à zéro), un appui sur + (ou −) ne change rien :
        // on se place dans une zone où les deux boutons fonctionnent.
        let volume = session.outputVolume
        if volume > 0.9 {
            setSystemVolume(0.8)
        } else if volume < 0.1 {
            setSystemVolume(0.2)
        }
        ignoreVolumeUntil = Date().addingTimeInterval(0.6)

        volumeObservation?.invalidate()
        volumeObservation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.volumeChanged() }
        }

        if interruptionObserver == nil {
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                Task { @MainActor in
                    guard let self, raw == AVAudioSession.InterruptionType.ended.rawValue,
                          self.state == .armed || self.state == .waiting else { return }
                    try? AVAudioSession.sharedInstance().setActive(true)
                    self.silentPlayer?.play()
                }
            }
        }
    }

    private func stopListening() {
        volumeObservation?.invalidate()
        volumeObservation = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        silentPlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func volumeChanged() {
        guard state == .armed, Date() >= ignoreVolumeUntil, let request else { return }
        state = .waiting
        volumeObservation?.invalidate()
        volumeObservation = nil
        let delay = max(0, request.delay)
        triggerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.ring()
        }
    }

    // MARK: - Appel entrant

    private func ring() {
        guard state == .waiting, let request else { return }
        let update = CXCallUpdate()
        update.remoteHandle = Self.handle(from: request.handle, fallback: request.name)
        update.localizedCallerName = request.name
        update.hasVideo = true
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        // La boucle silencieuse s'arrête : CallKit prend la main sur l'audio.
        stopListening()
        let uuid = UUID()
        callUUID = uuid
        state = .ringing
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in self?.resetCall() }
        }
    }

    /// Raccrocher depuis l'écran d'appel de l'app.
    func hangUpFromApp() {
        guard let uuid = callUUID else { return }
        endingFromApp = true
        controller.request(CXTransaction(action: CXEndCallAction(call: uuid))) { _ in }
    }

    private func resetCall() {
        callUUID = nil
        request = nil
        state = .idle
        endingFromApp = false
    }

    private func configureCallAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth])
    }

    nonisolated static func handle(from text: String, fallback: String) -> CXHandle {
        let value = text.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return CXHandle(type: .generic, value: fallback) }
        if value.contains("@") { return CXHandle(type: .emailAddress, value: value) }
        if value.allSatisfy({ "+0123456789 .-()".contains($0) }) {
            return CXHandle(type: .phoneNumber, value: value)
        }
        return CXHandle(type: .generic, value: value)
    }

    // MARK: - Boucle silencieuse et volume

    private func startSilentLoop() {
        if let silentPlayer {
            silentPlayer.play()
            return
        }
        guard let player = try? AVAudioPlayer(data: Self.silentWAV()) else { return }
        player.numberOfLoops = -1
        player.prepareToPlay()
        player.play()
        silentPlayer = player
    }

    private static func silentWAV() -> Data {
        let rate: UInt32 = 22_050
        let dataSize = rate * 2
        var data = Data()
        func append32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append32(16); append16(1); append16(1)
        append32(rate); append32(rate * 2); append16(2); append16(16)
        data.append(contentsOf: Array("data".utf8)); append32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }

    private var fallbackVolumeView: MPVolumeView?

    private func setSystemVolume(_ value: Float) {
        let view: MPVolumeView? = volumeView ?? {
            if fallbackVolumeView == nil {
                let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 60, height: 30))
                view.alpha = 0.011
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first?
                    .addSubview(view)
                fallbackVolumeView = view
            }
            return fallbackVolumeView
        }()
        guard let view, let slider = Self.findSlider(in: view) else { return }
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
    }

    private static func findSlider(in view: UIView) -> UISlider? {
        for sub in view.subviews {
            if let slider = sub as? UISlider { return slider }
            if let slider = findSlider(in: sub) { return slider }
        }
        return nil
    }
}

// MARK: - CallKit

extension IncomingCallManager: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        MainActor.assumeIsolated {
            answeredSlot = nil
            resetCall()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        MainActor.assumeIsolated {
            configureCallAudio()
            state = .active
            // Apparition instantanée de l'écran d'appel, sans glissement.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { answeredSlot = request?.slot }
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        MainActor.assumeIsolated {
            action.fulfill()
            // Raccroché depuis iOS (écran verrouillé, bouton latéral…) : on ferme l'écran d'appel.
            if !endingFromApp { answeredSlot = nil }
            resetCall()
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}
