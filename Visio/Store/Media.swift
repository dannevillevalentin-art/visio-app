import AVFoundation
import UIKit

/// Fichiers de l'app (vidéos, miniatures, photos), rangés dans
/// Application Support/Media. Les vidéos sont copiées ici : elles restent
/// disponibles même si on les supprime de la pellicule, et sont incluses
/// dans les sauvegardes iCloud de l'iPhone.
enum Media {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let cache = NSCache<NSString, UIImage>()

    static func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    static func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: url(name))
    }

    /// Range une vidéo (fichier temporaire) dans le dossier de l'app.
    static func storeVideo(from source: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        let dest = url(name)
        do {
            try FileManager.default.moveItem(at: source, to: dest)
        } catch {
            try FileManager.default.copyItem(at: source, to: dest)
        }
        return name
    }

    static func saveImage(_ image: UIImage, maxSide: CGFloat) -> String? {
        let resized = resized(image, maxSide: maxSide)
        guard let data = resized.jpegData(compressionQuality: 0.88) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: url(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func saveImage(data: Data, maxSide: CGFloat) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return saveImage(image, maxSide: maxSide)
    }

    static func makeThumbnail(forVideo name: String) async -> String? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url(name)))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        do {
            let result = try await generator.image(at: CMTime(seconds: 0.3, preferredTimescale: 600))
            return saveImage(UIImage(cgImage: result.image), maxSide: 600)
        } catch {
            return nil
        }
    }

    static func duration(ofVideo name: String) async -> Double {
        let asset = AVURLAsset(url: url(name))
        guard let time = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite ? seconds : 0
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Redessiner aussi applique l'orientation de la photo.
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
