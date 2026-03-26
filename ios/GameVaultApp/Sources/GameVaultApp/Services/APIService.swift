import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .noData: return "No data received"
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        case .serverError(let msg): return msg
        case .unauthorized: return "Session expired. Please log in again."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

final class APIService {
    static let shared = APIService()
    private init() {}

    private let keychain = KeychainService.shared
    private var isRefreshing = false
    private var refreshTask: Task<String, Error>?

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "server_url") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "server_url") }
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        token: String? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        guard !baseURL.isEmpty else { throw APIServiceError.serverError("No server URL configured") }

        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api" + path
        guard let url = URL(string: urlString) else { throw APIServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let authToken = token ?? keychain.load(.accessToken)
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.noData
            }

            if httpResponse.statusCode == 401 && retryOnUnauthorized {
                let newToken = try await refreshAccessToken()
                return try await self.request(path, method: method, body: body, token: newToken, retryOnUnauthorized: false)
            }

            if httpResponse.statusCode >= 400 {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    if httpResponse.statusCode == 401 {
                        throw APIServiceError.unauthorized
                    }
                    throw APIServiceError.serverError(apiError.displayMessage)
                }
                throw APIServiceError.serverError("Server error \(httpResponse.statusCode)")
            }

            if data.isEmpty {
                // For DELETE or empty-body 200/204 responses
                if let empty = EmptyResponse() as? T {
                    return empty
                }
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIServiceError.decodingError(error)
            }
        } catch let error as APIServiceError {
            throw error
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws -> String {
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }

            guard let refreshToken = keychain.load(.refreshToken) else {
                throw APIServiceError.unauthorized
            }

            struct RefreshBody: Encodable { let refreshToken: String }
            struct RefreshResponse: Decodable { let access: String; let refresh: String? }

            let body = RefreshBody(refreshToken: refreshToken)
            let response: RefreshResponse = try await self.request(
                "/auth/refresh",
                method: .post,
                body: body,
                retryOnUnauthorized: false
            )

            keychain.save(response.access, for: .accessToken)
            if let newRefresh = response.refresh {
                keychain.save(newRefresh, for: .refreshToken)
            }
            return response.access
        }

        refreshTask = task
        return try await task.value
    }
}

struct EmptyResponse: Codable {}
