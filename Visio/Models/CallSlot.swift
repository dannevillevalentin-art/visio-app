import Foundation

/// Apparence de l'appel simulé.
enum CallStyle: String, Codable, CaseIterable, Identifiable {
    case whatsapp, instagram, facetime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .facetime: return "FaceTime"
        }
    }

    /// Coin où se place le retour caméra une fois l'appel connecté.
    var defaultPipCorner: PipCorner {
        switch self {
        case .whatsapp, .instagram: return .topTrailing
        case .facetime: return .bottomTrailing
        }
    }
}

enum PipCorner: Equatable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    init(left: Bool, top: Bool) {
        switch (left, top) {
        case (true, true): self = .topLeading
        case (false, true): self = .topTrailing
        case (true, false): self = .bottomLeading
        case (false, false): self = .bottomTrailing
        }
    }

    var isLeft: Bool { self == .topLeading || self == .bottomLeading }
    var isTop: Bool { self == .topLeading || self == .topTrailing }
}

/// Ce qui se passe quand on raccroche.
enum EndAction: String, Codable, CaseIterable, Identifiable {
    case homeScreen, fakeHome, gallery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .homeScreen: return "Écran d'accueil"
        case .fakeHome: return "Image d'écran d'accueil"
        case .gallery: return "Revenir à la galerie"
        }
    }
}

/// Un emplacement de l'index (12 au total).
struct CallSlot: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Vidéo copiée dans l'app (nom de fichier dans le dossier Media).
    var videoFile: String?
    var videoDuration: Double = 0
    /// Miniature extraite automatiquement de la vidéo.
    var autoThumbnailFile: String?
    /// Miniature choisie à la main (prioritaire).
    var thumbnailFile: String?
    /// Note privée, visible seulement en mode index (ex. « Dame de cœur »).
    var label = ""
    var contactName = ""
    var contactPhotoFile: String?
    /// nil = style par défaut des réglages.
    var style: CallStyle?
    var hangUpAtEnd = false

    var displayThumbnail: String? { thumbnailFile ?? autoThumbnailFile }
    var hasVideo: Bool { videoFile != nil }

    init() {}

    // Décodage tolérant : les champs ajoutés plus tard ne cassent pas les données existantes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        videoFile = try c.decodeIfPresent(String.self, forKey: .videoFile)
        videoDuration = try c.decodeIfPresent(Double.self, forKey: .videoDuration) ?? 0
        autoThumbnailFile = try c.decodeIfPresent(String.self, forKey: .autoThumbnailFile)
        thumbnailFile = try c.decodeIfPresent(String.self, forKey: .thumbnailFile)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        contactName = try c.decodeIfPresent(String.self, forKey: .contactName) ?? ""
        contactPhotoFile = try c.decodeIfPresent(String.self, forKey: .contactPhotoFile)
        style = try c.decodeIfPresent(CallStyle.self, forKey: .style)
        hangUpAtEnd = try c.decodeIfPresent(Bool.self, forKey: .hangUpAtEnd) ?? false
    }
}

struct AppSettings: Codable, Equatable {
    var defaultStyle: CallStyle = .whatsapp
    var defaultContactName = "Julien"
    /// Durée de la sonnerie avant que l'appel « décroche ».
    var ringSeconds: Double = 4
    var ringbackSound = true
    /// Délai avant que les icônes disparaissent (0 = jamais).
    var hideControlsAfter: Double = 5
    var endAction: EndAction = .homeScreen
    var fakeHomeFile: String?
    var columns = 3
    var showDurations = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        defaultStyle = try c.decodeIfPresent(CallStyle.self, forKey: .defaultStyle) ?? d.defaultStyle
        defaultContactName = try c.decodeIfPresent(String.self, forKey: .defaultContactName) ?? d.defaultContactName
        ringSeconds = try c.decodeIfPresent(Double.self, forKey: .ringSeconds) ?? d.ringSeconds
        ringbackSound = try c.decodeIfPresent(Bool.self, forKey: .ringbackSound) ?? d.ringbackSound
        hideControlsAfter = try c.decodeIfPresent(Double.self, forKey: .hideControlsAfter) ?? d.hideControlsAfter
        endAction = try c.decodeIfPresent(EndAction.self, forKey: .endAction) ?? d.endAction
        fakeHomeFile = try c.decodeIfPresent(String.self, forKey: .fakeHomeFile)
        columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? d.columns
        showDurations = try c.decodeIfPresent(Bool.self, forKey: .showDurations) ?? d.showDurations
    }
}

extension TimeInterval {
    /// « 0:42 », comme dans Photos.
    var shortDuration: String {
        let total = Int(self.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
