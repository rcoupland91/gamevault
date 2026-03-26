import Foundation

final class GameService {
    static let shared = GameService()
    private init() {}

    private let api = APIService.shared

    // MARK: - Games

    func getGames(status: GameStatus? = nil, search: String? = nil, sort: String? = nil, order: String? = nil) async throws -> [Game] {
        var components = URLComponents()
        var queryItems: [URLQueryItem] = []

        if let status { queryItems.append(.init(name: "status", value: status.rawValue)) }
        if let search, !search.isEmpty { queryItems.append(.init(name: "search", value: search)) }
        if let sort { queryItems.append(.init(name: "sort", value: sort)) }
        if let order { queryItems.append(.init(name: "order", value: order)) }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        return try await api.request("/games\(query)")
    }

    func getGame(id: String) async throws -> Game {
        return try await api.request("/games/\(id)")
    }

    func createGame(_ request: GameRequest) async throws -> Game {
        return try await api.request("/games", method: .post, body: request)
    }

    func updateGame(id: String, _ request: GameRequest) async throws -> Game {
        return try await api.request("/games/\(id)", method: .patch, body: request)
    }

    func deleteGame(id: String) async throws {
        let _: EmptyResponse = try await api.request("/games/\(id)", method: .delete)
    }

    func getStats() async throws -> GameStats {
        return try await api.request("/games/stats/summary")
    }

    // MARK: - RAWG Search

    func searchRAWG(query: String, page: Int = 1, pageSize: Int = 20) async throws -> RAWGSearchResponse {
        var components = URLComponents()
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "page", value: String(page)),
            .init(name: "page_size", value: String(pageSize))
        ]
        let queryString = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return try await api.request("/rawg/search\(queryString)")
    }

    func getRAWGGame(idOrSlug: String) async throws -> RAWGGame {
        return try await api.request("/rawg/game/\(idOrSlug)")
    }
}
