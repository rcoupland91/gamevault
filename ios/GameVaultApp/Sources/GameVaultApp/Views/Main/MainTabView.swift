import SwiftUI

struct MainTabView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(authVM: authVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            NowPlayingView()
                .tabItem {
                    Label("Playing", systemImage: "play.fill")
                }
                .tag(1)

            GameLibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(2)

            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "bookmark.fill")
                }
                .tag(3)

            ProfileView(authVM: authVM)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(.indigo)
        .if { view in
            if #available(iOS 26.0, *) {
                view
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                view
            }
        }
    }
}

// MARK: - Now Playing (filtered game list)

struct NowPlayingView: View {
    @StateObject private var vm = GameListViewModel()
    @State private var selectedGame: Game?
    @State private var showAddGame = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                if vm.isLoading && vm.games.isEmpty {
                    ProgressView().tint(.green)
                } else if vm.games.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.games) { game in
                                NowPlayingRow(game: game)
                                    .onTapGesture { selectedGame = game }
                                    .contextMenu {
                                        Button {
                                            Task { await vm.updateGameStatus(game: game, newStatus: .played) }
                                        } label: {
                                            Label("Mark as Completed", systemImage: "checkmark.circle.fill")
                                        }
                                        Button {
                                            Task { await vm.updateGameStatus(game: game, newStatus: .toplay) }
                                        } label: {
                                            Label("Move to Backlog", systemImage: "bookmark")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            Task { await vm.deleteGame(id: game.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.bottom, 80)
                    }
                    .refreshable { await vm.loadGames(status: .playing) }
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGame = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.green)
                    }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game) {
                    Task { await vm.loadGames(status: .playing) }
                }
            }
            .sheet(isPresented: $showAddGame) {
                AddGameView {
                    Task { await vm.loadGames(status: .playing) }
                }
            }
        }
        .task { await vm.loadGames(status: .playing) }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "play.circle")
                .font(.system(size: 70))
                .foregroundStyle(.quaternary)
            Text("Nothing Playing")
                .font(.title2).fontWeight(.bold)
            Text("Start tracking a game you're currently playing")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button {
                showAddGame = true
            } label: {
                Label("Add Game", systemImage: "plus")
                    .fontWeight(.semibold).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.green).clipShape(Capsule())
            }
            Spacer()
        }
    }
}

// MARK: - Now Playing Row

struct NowPlayingRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 14) {
            GameArtworkView(url: game.artUrl, cornerRadius: 10, aspectRatio: 1)
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let platform = game.platform, !platform.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "display").font(.caption2)
                            Text(platform)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if let hours = game.hours, hours > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.caption2)
                            Text(game.displayHours)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let rating = game.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.3))
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

// MARK: - Backlog View

struct BacklogView: View {
    @StateObject private var vm = GameListViewModel()
    @State private var selectedGame: Game?
    @State private var showAddGame = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                if vm.isLoading && vm.games.isEmpty {
                    ProgressView().tint(.orange)
                } else if vm.games.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "bookmark.circle")
                            .font(.system(size: 70)).foregroundStyle(.quaternary)
                        Text("Backlog Empty")
                            .font(.title2).fontWeight(.bold)
                        Text("Add games you want to play in the future")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                        Button { showAddGame = true } label: {
                            Label("Add to Backlog", systemImage: "plus")
                                .fontWeight(.semibold).foregroundStyle(.white)
                                .padding(.horizontal, 24).padding(.vertical, 12)
                                .background(Color.orange).clipShape(Capsule())
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(vm.games) { game in
                            BacklogRow(game: game)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGame = game }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task { await vm.updateGameStatus(game: game, newStatus: .playing) }
                                    } label: {
                                        Label("Play Now", systemImage: "play.fill")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteGame(id: game.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.loadGames(status: .toplay) }
                }
            }
            .navigationTitle("Backlog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGame = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.orange)
                    }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game) { Task { await vm.loadGames(status: .toplay) } }
            }
            .sheet(isPresented: $showAddGame) {
                AddGameView { Task { await vm.loadGames(status: .toplay) } }
            }
        }
        .task { await vm.loadGames(status: .toplay) }
    }
}

// MARK: - Backlog Row

struct BacklogRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 12) {
            GameArtworkView(url: game.artUrl, cornerRadius: 8, aspectRatio: 1)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    if let genre = game.genre, !genre.isEmpty {
                        Text(genre).font(.caption).foregroundStyle(.secondary)
                    }
                    if let year = game.year {
                        Text(year).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let mc = game.metacritic, mc > 0 {
                    Text("MC: \(mc)").font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background((mc >= 75 ? Color.green : mc >= 50 ? Color.yellow : Color.red).opacity(0.15))
                        .foregroundStyle(mc >= 75 ? Color.green : mc >= 50 ? Color.yellow : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View extension helper for conditional modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
