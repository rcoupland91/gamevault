import SwiftUI

struct DashboardView: View {
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                if vm.isLoading && vm.stats == nil {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.indigo)
                        Text("Loading stats...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Welcome header
                            welcomeHeader

                            // Error
                            if let error = vm.error {
                                ErrorBanner(message: error)
                                    .padding(.horizontal, 20)
                            }

                            if let stats = vm.stats {
                                // Primary stats grid
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    StatCard(title: "Total Games", value: "\(stats.total)", icon: "gamecontroller.fill", color: .indigo)
                                    StatCard(title: "Now Playing", value: "\(stats.playing)", icon: "play.fill", color: .green)
                                    StatCard(title: "Completed", value: "\(stats.played)", icon: "checkmark.circle.fill", color: .blue)
                                    StatCard(title: "Backlog", value: "\(stats.toplay)", icon: "bookmark.fill", color: .orange)
                                }
                                .padding(.horizontal, 20)

                                // Hours & Rating
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Total Hours",
                                        value: formatHours(stats.totalHoursDouble),
                                        icon: "clock.fill",
                                        color: .purple
                                    )
                                    StatCard(
                                        title: "Avg Rating",
                                        value: stats.avgRatingDouble > 0 ? String(format: "%.1f★", stats.avgRatingDouble) : "—",
                                        icon: "star.fill",
                                        color: .yellow
                                    )
                                }
                                .padding(.horizontal, 20)

                                // Platform breakdown
                                if let platforms = stats.platformBreakdown, !platforms.isEmpty {
                                    platformSection(platforms)
                                }

                                // Genre breakdown
                                if let genres = stats.genreBreakdown, !genres.isEmpty {
                                    genreSection(genres)
                                }

                                // Recent activity
                                if let recent = stats.recentActivity, !recent.isEmpty {
                                    recentActivitySection(recent)
                                }
                            } else if !vm.isLoading {
                                emptyState
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Subviews

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(authVM.currentUser?.username ?? "Gamer")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
            if let avatarUrl = authVM.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func platformSection(_ platforms: [PlatformStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By Platform", icon: "display")

            GlassCard {
                VStack(spacing: 12) {
                    ForEach(platforms.prefix(6)) { stat in
                        HStack {
                            Text(stat.platform ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            HStack(spacing: 12) {
                                if let hours = stat.hours, let h = Double(hours), h > 0 {
                                    Text(formatHours(h))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(stat.count) game\(stat.count != 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if stat.id != platforms.prefix(6).last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func genreSection(_ genres: [GenreStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By Genre", icon: "tag.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres.prefix(10)) { stat in
                        VStack(spacing: 6) {
                            Text("\(stat.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.indigo)
                            Text(stat.genre ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 80, height: 70)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recentActivitySection(_ games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Activity", icon: "clock.arrow.circlepath")

            VStack(spacing: 10) {
                ForEach(games.prefix(5)) { game in
                    GlassCard(padding: 12) {
                        HStack(spacing: 12) {
                            GameArtworkView(url: game.artUrl, cornerRadius: 8, aspectRatio: 1)
                                .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                StatusBadge(status: game.status)
                            }
                            Spacer()

                            if let hours = game.hours, hours > 0 {
                                Text(game.displayHours)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            Text("No games yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Add your first game to see stats here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground), Color.indigo.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func formatHours(_ hours: Double) -> String {
        if hours >= 1000 {
            return String(format: "%.0fk", hours / 1000)
        } else if hours == hours.rounded() {
            return "\(Int(hours))h"
        }
        return String(format: "%.1fh", hours)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .font(.subheadline)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 20)
    }
}
