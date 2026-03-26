import SwiftUI

struct AddGameView: View {
    @StateObject private var vm = AddGameViewModel()
    @Environment(\.dismiss) private var dismiss
    var onAdded: (() -> Void)?
    @State private var mode: AddMode = .search

    enum AddMode: String, CaseIterable {
        case search = "Search"
        case manual = "Manual"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mode Picker
                    Picker("Mode", selection: $mode) {
                        ForEach(AddMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if mode == .search {
                        searchView
                    } else {
                        manualView
                    }
                }
            }
            .navigationTitle("Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: vm.addedGame) { _, game in
                if game != nil {
                    onAdded?()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Search Mode

    private var searchView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search for a game...", text: $vm.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: vm.searchText) { _, _ in
                        Task { await vm.search() }
                    }
                if !vm.searchText.isEmpty {
                    Button { vm.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Status picker for search results
            statusPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Results
            if vm.isSearching {
                Spacer()
                ProgressView("Searching...").tint(.indigo)
                Spacer()
            } else if vm.searchResults.isEmpty && !vm.searchText.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.quaternary)
                    Text("No results for \"\(vm.searchText)\"")
                        .foregroundStyle(.secondary)
                    Text("Try manual entry instead")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            } else if vm.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle").font(.system(size: 60)).foregroundStyle(.quaternary)
                    Text("Search for a game")
                        .font(.title3).fontWeight(.semibold)
                    Text("Find games from the RAWG database")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.searchResults) { game in
                            RAWGGameRow(game: game, isAdding: vm.isAdding) {
                                Task { await vm.addGame(from: game) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
            }
        }
    }

    // MARK: - Manual Mode

    private var manualView: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Game Title *").font(.caption).foregroundStyle(.secondary)
                            GlassTextField(placeholder: "Enter game title", text: $vm.manualTitle, icon: "gamecontroller")
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(GameStatus.allCases) { status in
                                    StatusSelectButton(status: status, isSelected: vm.selectedStatus == status) {
                                        vm.selectedStatus = status
                                    }
                                }
                            }
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Platform").font(.caption).foregroundStyle(.secondary)
                            GlassTextField(placeholder: "e.g. PlayStation 5", text: $vm.platform, icon: "display")
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Genre").font(.caption).foregroundStyle(.secondary)
                            GlassTextField(placeholder: "e.g. Action RPG", text: $vm.genre, icon: "tag")
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Year").font(.caption).foregroundStyle(.secondary)
                            GlassTextField(placeholder: "e.g. 2024", text: $vm.year, icon: "calendar", keyboardType: .numberPad, autocapitalization: .never, autocorrect: false)
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hours Played").font(.caption).foregroundStyle(.secondary)
                            GlassTextField(placeholder: "e.g. 25", text: $vm.hours, icon: "clock", keyboardType: .decimalPad, autocapitalization: .never, autocorrect: false)
                        }

                        Divider().opacity(0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating").font(.caption).foregroundStyle(.secondary)
                            StarRatingView(rating: $vm.selectedRating)
                        }
                    }
                }

                if let error = vm.error {
                    ErrorBanner(message: error) { vm.error = nil }
                }

                GlassButton(
                    title: "Add to Library",
                    icon: "plus.circle",
                    action: { Task { await vm.addManualGame() } },
                    isLoading: vm.isAdding
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }

    private var statusPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameStatus.allCases) { status in
                    FilterPill(title: status.displayName, icon: status.icon, isSelected: vm.selectedStatus == status) {
                        vm.selectedStatus = status
                    }
                }
            }
        }
    }
}

// MARK: - RAWG Game Row

struct RAWGGameRow: View {
    let game: RAWGGame
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GameArtworkView(url: game.artUrl, cornerRadius: 10, aspectRatio: 1)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = game.year {
                        Text(year).font(.caption).foregroundStyle(.secondary)
                    }
                    if let mc = game.metacritic {
                        Text("MC: \(mc)")
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(metacriticColor(mc).opacity(0.15))
                            .foregroundStyle(metacriticColor(mc))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let genres = game.genres, !genres.isEmpty {
                    Text(genres.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onAdd) {
                if isAdding {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.indigo)
                }
            }
            .disabled(isAdding)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func metacriticColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}
