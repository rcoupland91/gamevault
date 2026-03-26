import Foundation
import SwiftUI

@MainActor
final class GameListViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    @Published var selectedStatus: GameStatus? = nil
    @Published var sortBy = "updated_at"
    @Published var sortOrder = "desc"

    private let service = GameService.shared
    private var searchTask: Task<Void, Never>?

    var filteredGames: [Game] {
        if searchText.isEmpty { return games }
        return games.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    func loadGames(status: GameStatus? = nil) async {
        isLoading = true
        error = nil

        do {
            games = try await service.getGames(
                status: status,
                search: searchText.isEmpty ? nil : searchText,
                sort: sortBy,
                order: sortOrder
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteGame(id: String) async {
        do {
            try await service.deleteGame(id: id)
            games.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateGameStatus(game: Game, newStatus: GameStatus) async {
        var request = GameRequest(from: game)
        request.status = newStatus.rawValue
        do {
            let updated = try await service.updateGame(id: game.id, request)
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
final class GameDetailViewModel: ObservableObject {
    @Published var game: Game
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var error: String?
    @Published var saveSuccess = false

    // Edit fields
    @Published var title: String
    @Published var status: GameStatus
    @Published var rating: Int
    @Published var hours: String
    @Published var platform: String
    @Published var genre: String
    @Published var year: String
    @Published var review: String
    @Published var notes: String
    @Published var developer: String
    @Published var publisher: String

    private let service = GameService.shared

    init(game: Game) {
        self.game = game
        self.title = game.title
        self.status = game.status
        self.rating = game.rating ?? 0
        self.hours = game.hours.map { String(format: $0 == $0.rounded() ? "%.0f" : "%.1f", $0) } ?? ""
        self.platform = game.platform ?? ""
        self.genre = game.genre ?? ""
        self.year = game.year ?? ""
        self.review = game.review ?? ""
        self.notes = game.notes ?? ""
        self.developer = game.developer ?? ""
        self.publisher = game.publisher ?? ""
    }

    func save() async {
        isSaving = true
        error = nil

        var request = GameRequest(from: game)
        request.title = title
        request.status = status.rawValue
        request.rating = rating > 0 ? rating : nil
        request.hours = Double(hours)
        request.platform = platform.isEmpty ? nil : platform
        request.genre = genre.isEmpty ? nil : genre
        request.year = year.isEmpty ? nil : year
        request.review = review.isEmpty ? nil : review
        request.notes = notes.isEmpty ? nil : notes
        request.developer = developer.isEmpty ? nil : developer
        request.publisher = publisher.isEmpty ? nil : publisher

        do {
            game = try await service.updateGame(id: game.id, request)
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.saveSuccess = false
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

@MainActor
final class AddGameViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [RAWGGame] = []
    @Published var isSearching = false
    @Published var isAdding = false
    @Published var error: String?
    @Published var addedGame: Game?

    // Manual entry
    @Published var manualTitle = ""
    @Published var selectedStatus = GameStatus.toplay
    @Published var selectedRating = 0
    @Published var hours = ""
    @Published var platform = ""
    @Published var genre = ""
    @Published var year = ""
    @Published var notes = ""

    private let service = GameService.shared
    private var searchTask: Task<Void, Never>?

    func search() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let response = try await service.searchRAWG(query: searchText)
                searchResults = response.results
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            isSearching = false
        }
    }

    func addGame(from rawgGame: RAWGGame) async {
        isAdding = true
        error = nil

        let request = GameRequest(
            rawgId: rawgGame.rawgId,
            title: rawgGame.title ?? "Unknown",
            status: selectedStatus.rawValue,
            rating: nil,
            hours: nil,
            review: nil,
            platform: rawgGame.platforms?.first,
            genre: rawgGame.genres?.first,
            year: rawgGame.year,
            artUrl: rawgGame.artUrl,
            backgroundUrl: nil,
            developer: nil,
            publisher: nil,
            metacritic: rawgGame.metacritic,
            rawgSlug: rawgGame.rawgSlug,
            notes: nil
        )

        do {
            addedGame = try await service.createGame(request)
        } catch {
            self.error = error.localizedDescription
        }

        isAdding = false
    }

    func addManualGame() async {
        guard !manualTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Please enter a game title"
            return
        }

        isAdding = true
        error = nil

        let request = GameRequest(
            rawgId: nil,
            title: manualTitle,
            status: selectedStatus.rawValue,
            rating: selectedRating > 0 ? selectedRating : nil,
            hours: Double(hours),
            review: nil,
            platform: platform.isEmpty ? nil : platform,
            genre: genre.isEmpty ? nil : genre,
            year: year.isEmpty ? nil : year,
            artUrl: nil,
            backgroundUrl: nil,
            developer: nil,
            publisher: nil,
            metacritic: nil,
            rawgSlug: nil,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            addedGame = try await service.createGame(request)
        } catch {
            self.error = error.localizedDescription
        }

        isAdding = false
    }
}

// MARK: - GameRequest init helper

extension GameRequest {
    init(
        rawgId: Int?,
        title: String,
        status: String,
        rating: Int?,
        hours: Double?,
        review: String?,
        platform: String?,
        genre: String?,
        year: String?,
        artUrl: String?,
        backgroundUrl: String?,
        developer: String?,
        publisher: String?,
        metacritic: Int?,
        rawgSlug: String?,
        notes: String?
    ) {
        self.rawgId = rawgId
        self.title = title
        self.status = status
        self.rating = rating
        self.hours = hours
        self.review = review
        self.platform = platform
        self.genre = genre
        self.year = year
        self.artUrl = artUrl
        self.backgroundUrl = backgroundUrl
        self.developer = developer
        self.publisher = publisher
        self.metacritic = metacritic
        self.rawgSlug = rawgSlug
        self.notes = notes
    }
}
