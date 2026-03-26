import SwiftUI

struct GameLibraryView: View {
    @StateObject private var vm = GameListViewModel()
    @State private var selectedStatus: GameStatus? = nil
    @State private var showAddGame = false
    @State private var selectedGame: Game?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status filter pills
                    statusFilterBar
                        .padding(.vertical, 8)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search games...", text: $vm.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: vm.searchText) { _, _ in
                                Task { await vm.loadGames(status: selectedStatus) }
                            }
                        if !vm.searchText.isEmpty {
                            Button { vm.searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Content
                    if vm.isLoading && vm.games.isEmpty {
                        Spacer()
                        ProgressView().tint(.indigo)
                        Spacer()
                    } else if vm.filteredGames.isEmpty {
                        emptyStateView
                    } else {
                        gameGrid
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddGame = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.indigo)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
            }
            .sheet(isPresented: $showAddGame) {
                AddGameView {
                    Task { await vm.loadGames(status: selectedStatus) }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game) {
                    Task { await vm.loadGames(status: selectedStatus) }
                }
            }
            .task { await vm.loadGames(status: selectedStatus) }
            .onChange(of: selectedStatus) { _, newStatus in
                Task { await vm.loadGames(status: newStatus) }
            }
        }
    }

    // MARK: - Status Filter

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterPill(title: "All", icon: "square.grid.2x2", isSelected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                ForEach(GameStatus.allCases) { status in
                    FilterPill(title: status.displayName, icon: status.icon, isSelected: selectedStatus == status) {
                        selectedStatus = selectedStatus == status ? nil : status
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Game Grid

    private var gameGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)],
                spacing: 12
            ) {
                ForEach(vm.filteredGames) { game in
                    GameCard(game: game)
                        .onTapGesture { selectedGame = game }
                        .contextMenu {
                            statusMenuItems(game: game)
                            Divider()
                            Button(role: .destructive) {
                                Task { await vm.deleteGame(id: game.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .refreshable { await vm.loadGames(status: selectedStatus) }
    }

    @ViewBuilder
    private func statusMenuItems(game: Game) -> some View {
        ForEach(GameStatus.allCases) { status in
            if status != game.status {
                Button {
                    Task { await vm.updateGameStatus(game: game, newStatus: status) }
                } label: {
                    Label("Move to \(status.displayName)", systemImage: status.icon)
                }
            }
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach([
                ("updated_at", "Recently Updated"),
                ("title", "Title"),
                ("rating", "Rating"),
                ("hours", "Hours Played"),
                ("created_at", "Date Added")
            ], id: \.0) { key, label in
                Button {
                    if vm.sortBy == key {
                        vm.sortOrder = vm.sortOrder == "desc" ? "asc" : "desc"
                    } else {
                        vm.sortBy = key
                        vm.sortOrder = "desc"
                    }
                    Task { await vm.loadGames(status: selectedStatus) }
                } label: {
                    HStack {
                        Text(label)
                        if vm.sortBy == key {
                            Image(systemName: vm.sortOrder == "desc" ? "arrow.down" : "arrow.up")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(.indigo)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "gamecontroller")
                .font(.system(size: 70))
                .foregroundStyle(.quaternary)
            VStack(spacing: 8) {
                Text(vm.searchText.isEmpty ? "No Games" : "No Results")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(vm.searchText.isEmpty
                    ? "Add your first game to start building your library"
                    : "No games match \"\(vm.searchText)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if vm.searchText.isEmpty {
                Button {
                    showAddGame = true
                } label: {
                    Label("Add Game", systemImage: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.indigo)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding()
    }

    @State private var showAddGame2 = false

    private var backgroundGradient: some View {
        Color(uiColor: .systemBackground)
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.indigo)
                } else {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artwork
            ZStack(alignment: .topTrailing) {
                GameArtworkView(url: game.artUrl, cornerRadius: 0, aspectRatio: 3/4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                StatusBadge(status: game.status)
                    .padding(8)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let platform = game.platform, !platform.isEmpty {
                        Text(platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let rating = game.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let hours = game.hours, hours > 0 {
                    Text(game.displayHours)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
