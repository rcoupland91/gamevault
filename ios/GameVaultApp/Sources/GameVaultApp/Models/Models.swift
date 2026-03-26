import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let avatarUrl: String?
    let isAdmin: Bool
    let isActive: Bool?
    let createdAt: String?
    var totpEnabled: Bool?
    var emailOtpEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
        case isActive = "is_active"
        case createdAt = "created_at"
        case totpEnabled = "totp_enabled"
        case emailOtpEnabled = "email_otp_enabled"
    }
}

// MARK: - Auth Responses

struct AuthResponse: Codable {
    let user: User?
    let access: String?
    let refresh: String?
    let requires2FA: Bool?
    let preToken: String?
    let methods: TwoFAMethods?

    enum CodingKeys: String, CodingKey {
        case user, access, refresh
        case requires2FA
        case preToken
        case methods
    }
}

struct TwoFAMethods: Codable {
    let totp: Bool?
    let email: Bool?
}

struct TwoFAStatus: Codable {
    let totpEnabled: Bool
    let emailOtpEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case totpEnabled = "totp_enabled"
        case emailOtpEnabled = "email_otp_enabled"
    }
}

// MARK: - Game

enum GameStatus: String, Codable, CaseIterable, Identifiable {
    case playing
    case played
    case toplay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playing: return "Now Playing"
        case .played: return "Completed"
        case .toplay: return "Backlog"
        }
    }

    var icon: String {
        switch self {
        case .playing: return "gamecontroller.fill"
        case .played: return "checkmark.circle.fill"
        case .toplay: return "bookmark.fill"
        }
    }
}

struct Game: Codable, Identifiable {
    let id: String
    let userId: String?
    var rawgId: Int?
    var title: String
    var status: GameStatus
    var rating: Int?
    var hours: Double?
    var review: String?
    var platform: String?
    var genre: String?
    var year: String?
    var artUrl: String?
    var backgroundUrl: String?
    var developer: String?
    var publisher: String?
    var metacritic: Int?
    var rawgSlug: String?
    var notes: String?
    var completedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rawgId = "rawg_id"
        case title, status, rating, hours, review, platform, genre, year
        case artUrl = "art_url"
        case backgroundUrl = "background_url"
        case developer, publisher, metacritic
        case rawgSlug = "rawg_slug"
        case notes
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayRating: String {
        guard let r = rating, r > 0 else { return "Unrated" }
        return String(repeating: "★", count: r) + String(repeating: "☆", count: 5 - r)
    }

    var displayHours: String {
        guard let h = hours, h > 0 else { return "" }
        if h == h.rounded() {
            return "\(Int(h))h"
        }
        return String(format: "%.1fh", h)
    }
}

// MARK: - Game Create/Update Request

struct GameRequest: Codable {
    var rawgId: Int?
    var title: String
    var status: String
    var rating: Int?
    var hours: Double?
    var review: String?
    var platform: String?
    var genre: String?
    var year: String?
    var artUrl: String?
    var backgroundUrl: String?
    var developer: String?
    var publisher: String?
    var metacritic: Int?
    var rawgSlug: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case rawgId = "rawg_id"
        case title, status, rating, hours, review, platform, genre, year
        case artUrl = "art_url"
        case backgroundUrl = "background_url"
        case developer, publisher, metacritic
        case rawgSlug = "rawg_slug"
        case notes
    }

    init(from game: Game) {
        self.rawgId = game.rawgId
        self.title = game.title
        self.status = game.status.rawValue
        self.rating = game.rating
        self.hours = game.hours
        self.review = game.review
        self.platform = game.platform
        self.genre = game.genre
        self.year = game.year
        self.artUrl = game.artUrl
        self.backgroundUrl = game.backgroundUrl
        self.developer = game.developer
        self.publisher = game.publisher
        self.metacritic = game.metacritic
        self.rawgSlug = game.rawgSlug
        self.notes = game.notes
    }
}

// MARK: - Stats

struct GameStats: Codable {
    let total: Int
    let playing: Int
    let played: Int
    let toplay: Int
    let totalHours: String?
    let avgHours: String?
    let avgRating: String?
    let platformBreakdown: [PlatformStat]?
    let genreBreakdown: [GenreStat]?
    let recentActivity: [Game]?

    enum CodingKeys: String, CodingKey {
        case total, playing, played, toplay
        case totalHours = "totalHours"
        case avgHours = "avgHours"
        case avgRating = "avgRating"
        case platformBreakdown = "platformBreakdown"
        case genreBreakdown = "genreBreakdown"
        case recentActivity = "recentActivity"
    }

    var totalHoursDouble: Double {
        Double(totalHours ?? "0") ?? 0
    }

    var avgRatingDouble: Double {
        Double(avgRating ?? "0") ?? 0
    }
}

struct PlatformStat: Codable, Identifiable {
    var id: String { platform ?? "unknown" }
    let platform: String?
    let hours: String?
    let count: Int
}

struct GenreStat: Codable, Identifiable {
    var id: String { genre ?? "unknown" }
    let genre: String?
    let count: Int
}

// MARK: - RAWG Search

struct RAWGSearchResponse: Codable {
    let count: Int?
    let results: [RAWGGame]
}

struct RAWGGame: Codable, Identifiable {
    var id: Int { rawgId ?? 0 }
    let rawgId: Int?
    let rawgSlug: String?
    let title: String?
    let artUrl: String?
    let year: String?
    let platforms: [String]?
    let genres: [String]?
    let metacritic: Int?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case rawgId = "rawg_id"
        case rawgSlug = "rawg_slug"
        case title
        case artUrl = "art_url"
        case year, platforms, genres, metacritic, rating
    }
}

// MARK: - API Error

struct APIError: Codable {
    let error: String?
    let message: String?
    let code: String?

    var displayMessage: String {
        error ?? message ?? "An unknown error occurred"
    }
}

// MARK: - Admin

struct AdminUser: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let isAdmin: Bool
    let isActive: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isAdmin = "is_admin"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}
