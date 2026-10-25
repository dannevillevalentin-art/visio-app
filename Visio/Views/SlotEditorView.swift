import PhotosUI
import SwiftUI

/// Réglages d'un emplacement de l'index.
struct SlotEditorView: View {
    let slotID: UUID

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var videoItem: PhotosPickerItem?
    @State private var thumbnailItem: PhotosPickerItem?
    @State private var photoItem: PhotosPickerItem?
    @State private var showRecorder = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                videoSection
                thumbnailSection
                indexSection
                callSection
                Section {
                    Button("Vider cet emplacement", role: .destructive) { confirmClear = true }
                        .disabled(!slot.wrappedValue.hasVideo && slot.wrappedValue.label.isEmpty)
                }
            }
            .navigationTitle("Emplacement \(position + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .overlay {
                if busy {
                    ProgressView("Import…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .disabled(busy)
            .alert("Import impossible", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("Supprimer la vidéo et les réglages de cet emplacement ?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Vider", role: .destructive) { store.clear(slotID: slotID) }
            }
            .fullScreenCover(isPresented: $showRecorder) {
                CameraRecorder { url in
                    showRecorder = false
                    if let url { importVideo(from: url) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: videoItem) { _, item in
                guard let item else { return }
                videoItem = nil
                busy = true
                Task {
                    do {
                        guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                            throw CocoaError(.fileReadUnknown)
                        }
                        try await store.setVideo(slotID: slotID, from: picked.url)
                    } catch {
                        errorMessage = "La vidéo n'a pas pu être importée. Si elle est dans iCloud, vérifiez la connexion et réessayez."
                    }
                    busy = false
                }
            }
            .onChange(of: thumbnailItem) { _, item in
                guard let item else { return }
                thumbnailItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.setThumbnail(slotID: slotID, data: data)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.setContactPhoto(slotID: slotID, data: data)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var videoSection: some View {
        Section {
            if let file = slot.wrappedValue.videoFile {
                HStack(spacing: 12) {
                    thumbnail(slot.wrappedValue.autoThumbnailFile, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vidéo enregistrée")
                        Text(slot.wrappedValue.videoDuration.shortDuration)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShareLink(item: Media.url(file)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            PhotosPicker(selection: $videoItem, matching: .videos) {
                Label(slot.wrappedValue.hasVideo ? "Remplacer depuis Photos" : "Importer depuis Photos",
                      systemImage: "photo.on.rectangle")
            }
            if CameraRecorder.isAvailable {
                Button {
                    showRecorder = true
                } label: {
                    Label("Filmer", systemImage: "video.badge.plus")
                }
            }
        } header: {
            Text("Vidéo")
        } footer: {
            Text("La vidéo est copiée dans l'app : elle reste disponible même si vous la supprimez de Photos. Le bouton de partage permet d'en enregistrer une copie.")
        }
    }

    private var thumbnailSection: some View {
        Section {
            HStack(spacing: 12) {
                thumbnail(slot.wrappedValue.displayThumbnail, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $thumbnailItem, matching: .images) {
                        Text("Choisir une image")
                    }
                    if slot.wrappedValue.thumbnailFile != nil {
                        Button("Utiliser l'image de la vidéo") {
                            store.setThumbnail(slotID: slotID, data: nil)
                        }
                    }
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Miniature dans la galerie")
        }
    }

    private var indexSection: some View {
        Section {
            TextField("Note (ex. Dame de cœur)", text: slot.label)
            Picker("Position", selection: Binding(
                get: { position },
                set: { store.move(slotID, to: $0) }
            )) {
                ForEach(0..<LibraryStore.slotCount, id: \.self) { i in
                    Text("\(i + 1)").tag(i)
                }
            }
        } header: {
            Text("Index")
        } footer: {
            Text("La note et les numéros ne s'affichent qu'en mode « Sélectionner ». Changer la position échange avec la vidéo qui s'y trouve.")
        }
    }

    private var callSection: some View {
        Section {
            Picker("Style", selection: slot.style) {
                Text("Par défaut (\(store.settings.defaultStyle.label))").tag(CallStyle?.none)
                ForEach(CallStyle.allCases) { style in
                    Text(style.label).tag(CallStyle?.some(style))
                }
            }
            TextField("Nom du contact (\(store.settings.defaultContactName))", text: slot.contactName)
            HStack(spacing: 12) {
                Avatar(
                    photo: Media.image(slot.wrappedValue.contactPhotoFile),
                    name: slot.wrappedValue.contactName.isEmpty ? store.settings.defaultContactName : slot.wrappedValue.contactName,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("Photo du contact")
                    }
                    if slot.wrappedValue.contactPhotoFile != nil {
                        Button("Retirer la photo", role: .destructive) {
                            store.setContactPhoto(slotID: slotID, data: nil)
                        }
                    }
                }
                .buttonStyle(.borderless)
            }
            TextField("Numéro ou e-mail (facultatif)", text: slot.contactHandle)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Toggle("Raccrocher à la fin de la vidéo", isOn: slot.hangUpAtEnd)
        } header: {
            Text("Appel")
        } footer: {
            Text("En mode « Il m'appelle », si le numéro ou l'e-mail correspond à un contact de l'iPhone, iOS affiche sa photo sur l'écran d'appel entrant.")
        }
    }

    // MARK: - Aides

    private var position: Int {
        store.index(of: slotID) ?? 0
    }

    private var slot: Binding<CallSlot> {
        Binding(
            get: { store.slot(slotID) ?? CallSlot() },
            set: { store.update($0) }
        )
    }

    private func thumbnail(_ name: String?, size: CGFloat) -> some View {
        Color(.secondarySystemBackground)
            .frame(width: size, height: size)
            .overlay {
                if let image = Media.image(name) {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func importVideo(from url: URL) {
        busy = true
        Task {
            do {
                try await store.setVideo(slotID: slotID, from: url)
            } catch {
                errorMessage = "La vidéo n'a pas pu être enregistrée."
            }
            busy = false
        }
    }
}
