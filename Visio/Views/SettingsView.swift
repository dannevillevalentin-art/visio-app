import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var fakeHomeItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Style par défaut", selection: $store.settings.defaultStyle) {
                        ForEach(CallStyle.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Nom du contact par défaut", text: $store.settings.defaultContactName)
                } header: {
                    Text("Appel")
                } footer: {
                    Text("Chaque emplacement peut avoir son propre style et son propre contact.")
                }

                Section {
                    Stepper(value: $store.settings.ringSeconds, in: 0...20, step: 1) {
                        LabeledContent("Durée de la sonnerie", value: "\(Int(store.settings.ringSeconds)) s")
                    }
                    Toggle("Tonalité d'appel", isOn: $store.settings.ringbackSound)
                } header: {
                    Text("Sonnerie")
                } footer: {
                    Text("Pendant la sonnerie, toucher l'écran fait décrocher immédiatement.")
                }

                Section {
                    Stepper(value: $store.settings.hideControlsAfter, in: 0...30, step: 1) {
                        LabeledContent(
                            "Masquer les icônes après",
                            value: store.settings.hideControlsAfter == 0 ? "Jamais" : "\(Int(store.settings.hideControlsAfter)) s"
                        )
                    }
                } header: {
                    Text("Pendant l'appel")
                } footer: {
                    Text("Toucher l'écran fait réapparaître les icônes. Le retour caméra se déplace au doigt vers n'importe quel coin.")
                }

                Section {
                    Picker("Après avoir raccroché", selection: $store.settings.endAction) {
                        ForEach(EndAction.allCases) { Text($0.label).tag($0) }
                    }
                    if store.settings.endAction == .fakeHome {
                        HStack(spacing: 12) {
                            Color(.secondarySystemBackground)
                                .frame(width: 44, height: 90)
                                .overlay {
                                    if let image = Media.image(store.settings.fakeHomeFile) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            PhotosPicker(selection: $fakeHomeItem, matching: .screenshots) {
                                Text(store.settings.fakeHomeFile == nil ? "Choisir la capture d'écran" : "Changer la capture d'écran")
                            }
                        }
                    }
                } header: {
                    Text("Fin d'appel")
                } footer: {
                    Text(endActionFooter)
                }

                Section {
                    Picker("Colonnes", selection: $store.settings.columns) {
                        ForEach(3...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Toggle("Afficher les durées", isOn: $store.settings.showDurations)
                } header: {
                    Text("Galerie")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .onChange(of: fakeHomeItem) { _, item in
                guard let item else { return }
                fakeHomeItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.setFakeHome(data: data)
                    }
                }
            }
        }
    }

    private var endActionFooter: String {
        switch store.settings.endAction {
        case .homeScreen:
            return "L'app se referme comme si on revenait à l'accueil, avec l'animation normale d'iOS. Au retour dans l'app, la galerie est affichée."
        case .fakeHome:
            return "Affiche une capture de votre écran d'accueil. Attention : l'heure de la capture reste figée. Appui long d'une seconde pour revenir à la galerie."
        case .gallery:
            return "Retour direct à la galerie."
        }
    }
}
