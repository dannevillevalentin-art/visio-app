import SwiftUI
import UIKit

/// Icônes et textes superposés à l'appel, selon le style choisi.
/// Toutes les icônes sont des symboles système génériques.
struct CallChrome: View {
    let style: CallStyle
    let connected: Bool
    let name: String
    let photo: UIImage?
    let elapsed: Int
    let onEnd: () -> Void

    var body: some View {
        Group {
            switch style {
            case .whatsapp:
                WhatsAppChrome(connected: connected, name: name, elapsed: elapsed, onEnd: onEnd)
            case .instagram:
                InstagramChrome(connected: connected, name: name, photo: photo, elapsed: elapsed, onEnd: onEnd)
            case .facetime:
                FaceTimeChrome(connected: connected, name: name, photo: photo, onEnd: onEnd)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Marges réservées au retour caméra (sous / au-dessus des icônes)

extension CallStyle {
    var pipTopInset: CGFloat {
        switch self {
        case .whatsapp: return 64
        case .instagram: return 64
        case .facetime: return 150
        }
    }

    var pipBottomInset: CGFloat {
        switch self {
        case .whatsapp: return 96
        case .instagram: return 104
        case .facetime: return 16
        }
    }
}

// MARK: - WhatsApp

private struct WhatsAppChrome: View {
    let connected: Bool
    let name: String
    let elapsed: Int
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    CallIcon(symbol: "chevron.down", size: 40, toggles: false)
                    Spacer()
                    CallIcon(symbol: "person.badge.plus", size: 40, toggles: false)
                }
                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 20, weight: .semibold))
                    Text(connected ? String(format: "%02d:%02d", elapsed / 60, elapsed % 60) : "Sonnerie…")
                        .font(.system(size: 15))
                        .monospacedDigit()
                        .opacity(0.85)
                }
                .lineLimit(1)
                .padding(.horizontal, 56)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            if !connected {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text("Chiffré de bout en bout")
                }
                .font(.system(size: 12))
                .opacity(0.75)
                .padding(.top, 8)
            }

            Spacer()

            HStack(spacing: 12) {
                CallIcon(symbol: "ellipsis", toggles: false)
                CallIcon(symbol: "video.fill", toggles: false)
                CallIcon(symbol: "speaker.wave.2.fill")
                CallIcon(symbol: "mic.fill", activeSymbol: "mic.slash.fill")
                EndCallButton(symbol: "phone.down.fill", action: onEnd)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 10)
        }
        .textShadow()
    }
}

// MARK: - Instagram

private struct InstagramChrome: View {
    let connected: Bool
    let name: String
    let photo: UIImage?
    let elapsed: Int
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            if !connected {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        CallIcon(symbol: "chevron.down", size: 40, toggles: false)
                        Spacer()
                        CallIcon(symbol: "person.badge.plus", size: 40, toggles: false)
                    }
                    if connected {
                        VStack(spacing: 2) {
                            Text(name)
                                .font(.system(size: 17, weight: .semibold))
                            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                                .font(.system(size: 14))
                                .monospacedDigit()
                                .opacity(0.85)
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 56)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                Spacer()

                if !connected {
                    VStack(spacing: 10) {
                        Avatar(photo: photo, name: name, size: 112)
                        Text(name)
                            .font(.system(size: 24, weight: .bold))
                        Text("Appel en cours…")
                            .font(.system(size: 15))
                            .opacity(0.85)
                    }
                    Spacer()
                }

                HStack(spacing: 14) {
                    CallIcon(symbol: "arrow.triangle.2.circlepath.camera", toggles: false)
                    CallIcon(symbol: "video.fill", toggles: false)
                    CallIcon(symbol: "mic.fill", activeSymbol: "mic.slash.fill")
                    CallIcon(symbol: "face.smiling", toggles: false)
                    EndCallButton(symbol: "phone.down.fill", action: onEnd)
                }
                .padding(.bottom, 14)
            }
        }
        .textShadow()
    }
}

// MARK: - FaceTime

private struct FaceTimeChrome: View {
    let connected: Bool
    let name: String
    let photo: UIImage?
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Avatar(photo: photo, name: name, size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 17, weight: .semibold))
                        if !connected {
                            Text("FaceTime…")
                                .font(.system(size: 14))
                                .opacity(0.75)
                        }
                    }
                    .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.6)
                    Spacer()
                }
                HStack(spacing: 12) {
                    CallIcon(symbol: "speaker.wave.2.fill", size: 50)
                    CallIcon(symbol: "video.fill", size: 50, toggles: false)
                    CallIcon(symbol: "mic.fill", activeSymbol: "mic.slash.fill", size: 50)
                    CallIcon(symbol: "shareplay", size: 50, toggles: false)
                    EndCallButton(symbol: "xmark", size: 50, action: onEnd)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.top, 4)

            Spacer()
        }
    }
}

// MARK: - Éléments communs

/// Bouton rond. Au toucher il change d'aspect (comme « couper le micro »)
/// mais ne fait rien d'autre.
struct CallIcon: View {
    let symbol: String
    var activeSymbol: String?
    var size: CGFloat = 52
    var toggles = true

    @State private var active = false

    var body: some View {
        Button {
            if toggles { active.toggle() }
        } label: {
            Image(systemName: active ? (activeSymbol ?? symbol) : symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(active ? Color.black : Color.white)
                .frame(width: size, height: size)
                .background(Circle().fill(active ? Color.white : Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

struct EndCallButton: View {
    let symbol: String
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(red: 1, green: 0.23, blue: 0.19)))
        }
        .buttonStyle(.plain)
    }
}

struct Avatar: View {
    let photo: UIImage?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(white: 0.62), Color(white: 0.45)], startPoint: .top, endPoint: .bottom)
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

private extension View {
    func textShadow() -> some View {
        shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
    }
}
