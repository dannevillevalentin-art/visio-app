import Foundation
import UIKit

/// L'index : 12 emplacements + réglages, enregistrés dans library.json.
@MainActor
final class LibraryStore: ObservableObject {
    static let slotCount = 12

    @Published private(set) var slots: [CallSlot]
    @Published var settings: AppSettings {
        didSet { if settings != oldValue { save() } }
    }

    private struct Library: Codable {
        var slots: [CallSlot]
        var settings: AppSettings
    }

    private let fileURL = Media.folder.deletingLastPathComponent().appendingPathComponent("library.json")

    init() {
        var slots: [CallSlot] = []
        var settings = AppSettings()
        if let data = try? Data(contentsOf: fileURL),
           let library = try? JSONDecoder().decode(Library.self, from: data) {
            slots = library.slots
            settings = library.settings
        }
        while slots.count < Self.slotCount { slots.append(CallSlot()) }
        self.slots = Array(slots.prefix(Self.slotCount))
        self.settings = settings
    }

    func save() {
        let library = Library(slots: slots, settings: settings)
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func index(of id: UUID) -> Int? {
        slots.firstIndex { $0.id == id }
    }

    func slot(_ id: UUID) -> CallSlot? {
        slots.first { $0.id == id }
    }

    func update(_ slot: CallSlot) {
        guard let i = index(of: slot.id), slots[i] != slot else { return }
        slots[i] = slot
        save()
    }

    /// Échange la position de l'emplacement avec celui qui occupe `position`.
    func move(_ id: UUID, to position: Int) {
        guard let from = index(of: id), slots.indices.contains(position), from != position else { return }
        slots.swapAt(from, position)
        save()
    }

    func setVideo(slotID: UUID, from source: URL) async throws {
        let name = try Media.storeVideo(from: source)
        let thumbnail = await Media.makeThumbnail(forVideo: name)
        let duration = await Media.duration(ofVideo: name)
        guard let i = index(of: slotID) else {
            Media.delete(name)
            Media.delete(thumbnail)
            return
        }
        let old = slots[i]
        slots[i].videoFile = name
        slots[i].autoThumbnailFile = thumbnail
        slots[i].videoDuration = duration
        save()
        Media.delete(old.videoFile)
        Media.delete(old.autoThumbnailFile)
    }

    func setThumbnail(slotID: UUID, data: Data?) {
        guard let i = index(of: slotID) else { return }
        let old = slots[i].thumbnailFile
        slots[i].thumbnailFile = data.flatMap { Media.saveImage(data: $0, maxSide: 600) }
        save()
        Media.delete(old)
    }

    func setContactPhoto(slotID: UUID, data: Data?) {
        guard let i = index(of: slotID) else { return }
        let old = slots[i].contactPhotoFile
        slots[i].contactPhotoFile = data.flatMap { Media.saveImage(data: $0, maxSide: 400) }
        save()
        Media.delete(old)
    }

    func setFakeHome(data: Data?) {
        let old = settings.fakeHomeFile
        settings.fakeHomeFile = data.flatMap { Media.saveImage(data: $0, maxSide: 3000) }
        Media.delete(old)
    }

    func clear(slotID: UUID) {
        guard let i = index(of: slotID) else { return }
        let old = slots[i]
        var empty = CallSlot()
        empty.id = old.id
        slots[i] = empty
        save()
        [old.videoFile, old.autoThumbnailFile, old.thumbnailFile, old.contactPhotoFile].forEach(Media.delete)
    }
}
