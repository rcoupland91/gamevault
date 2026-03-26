import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats: GameStats?
    @Published var isLoading = false
    @Published var error: String?

    private let service = GameService.shared

    func load() async {
        isLoading = true
        error = nil
        do {
            stats = try await service.getStats()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
