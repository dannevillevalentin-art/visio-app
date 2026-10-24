import SwiftUI

/// Écran principal : ressemble à une grille de vidéos dans Photos.
/// - Mode normal : toucher une vidéo lance l'appel.
/// - « Sélectionner » : passe en mode index (numéros, notes, réglages).
struct GalleryView: View {
    @EnvironmentObject private var store: LibraryStore

    @State private var editing = false
    @State private var editingSlot: SlotRef?
    @State private var activeCall: CallSlot?
    @State private var showSettings = false

    private struct SlotRef: Identifiable { let id: UUID }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(store.slots.enumerated()), id: \.element.id) { index, slot in
                        GalleryTile(
                            slot: slot,
                            position: index + 1,
                            editing: editing,
                            showDuration: store.settings.showDurations
                        )
                        .onTapGesture { tap(slot) }
                    }
                }
            }
            .navigationTitle(editing ? "Index" : "Récents")
            .toolbar {
                if editing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("OK") { editing = false }
                            .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sélectionner") { editing = true }
                    }
                }
            }
        }
        .sheet(item: $editingSlot) { ref in
            SlotEditorView(slotID: ref.id)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $activeCall) { slot in
            CallView(slot: slot, settings: store.settings) { animated in
                if animated {
                    activeCall = nil
                } else {
                    withoutAnimation { activeCall = nil }
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: max(2, min(5, store.settings.columns)))
    }

    private func tap(_ slot: CallSlot) {
        if editing {
            editingSlot = SlotRef(id: slot.id)
        } else if slot.hasVideo {
            // L'écran d'appel apparaît instantanément, sans glissement.
            withoutAnimation { activeCall = slot }
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

private struct GalleryTile: View {
    let slot: CallSlot
    let position: Int
    let editing: Bool
    let showDuration: Bool

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = Media.image(slot.displayThumbnail) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if editing {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if showDuration && slot.hasVideo && !editing {
                    Text(slot.videoDuration.shortDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(5)
                }
            }
            .overlay(alignment: .topLeading) {
                if editing {
                    Text("\(position)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Circle().fill(Color.accentColor))
                        .padding(5)
                }
            }
            .overlay(alignment: .bottom) {
                if editing && !slot.label.isEmpty {
                    Text(slot.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.55))
                }
            }
            .contentShape(Rectangle())
    }
}
