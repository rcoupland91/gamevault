import SwiftUI

struct GameDetailView: View {
    @StateObject private var vm: GameDetailViewModel
    @Environment(\.dismiss) private var dismiss
    var onSave: (() -> Void)?

    init(game: Game, onSave: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: GameDetailViewModel(game: game))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero artwork
                        heroSection

                        // Core details
                        GlassCard {
                            VStack(spacing: 16) {
                                // Title
                                VStack(alignment: .leading, spacing: 6) {
                                    label("Title")
                                    GlassTextField(placeholder: "Game title", text: $vm.title, icon: "textformat")
                                }

                                Divider().opacity(0.5)

                                // Status
                                VStack(alignment: .leading, spacing: 8) {
                                    label("Status")
                                    HStack(spacing: 10) {
                                        ForEach(GameStatus.allCases) { status in
                                            StatusSelectButton(status: status, isSelected: vm.status == status) {
                                                vm.status = status
                                            }
                                        }
                                    }
                                }

                                Divider().opacity(0.5)

                                // Rating
                                VStack(alignment: .leading, spacing: 8) {
                                    label("Rating")
                                    HStack {
                                        StarRatingView(rating: $vm.rating)
                                        Spacer()
                                        if vm.rating > 0 {
                                            Button { vm.rating = 0 } label: {
                                                Text("Clear")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }

                                Divider().opacity(0.5)

                                // Hours
                                VStack(alignment: .leading, spacing: 6) {
                                    label("Hours Played")
                                    GlassTextField(placeholder: "e.g. 25", text: $vm.hours, icon: "clock", keyboardType: .decimalPad, autocapitalization: .never, autocorrect: false)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Game details
                        GlassCard {
                            VStack(spacing: 16) {
                                detailRow("Platform", icon: "display", binding: $vm.platform, placeholder: "e.g. PlayStation 5")
                                Divider().opacity(0.5)
                                detailRow("Genre", icon: "tag", binding: $vm.genre, placeholder: "e.g. Action RPG")
                                Divider().opacity(0.5)
                                detailRow("Year", icon: "calendar", binding: $vm.year, placeholder: "e.g. 2024", keyboardType: .numberPad)
                                Divider().opacity(0.5)
                                detailRow("Developer", icon: "hammer", binding: $vm.developer, placeholder: "Studio name")
                                Divider().opacity(0.5)
                                detailRow("Publisher", icon: "building", binding: $vm.publisher, placeholder: "Publisher name")
                            }
                        }
                        .padding(.horizontal, 16)

                        // Review & Notes
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                label("Review")
                                TextEditor(text: $vm.review)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(.quaternary.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Divider().opacity(0.5)

                                label("Notes")
                                TextEditor(text: $vm.notes)
                                    .frame(height: 80)
                                    .padding(8)
                                    .background(.quaternary.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 16)

                        // Metacritic score (read-only)
                        if let mc = vm.game.metacritic, mc > 0 {
                            GlassCard {
                                HStack {
                                    Text("Metacritic Score")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(mc)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(metacriticColor(mc))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(metacriticColor(mc).opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Error / Success
                        if let error = vm.error {
                            ErrorBanner(message: error) { vm.error = nil }
                                .padding(.horizontal, 16)
                        }

                        if vm.saveSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Saved successfully")
                                    .foregroundStyle(.green)
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(vm.game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await vm.save()
                            onSave?()
                        }
                    } label: {
                        if vm.isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            if let bgUrl = vm.game.backgroundUrl, let url = URL(string: bgUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.indigo.opacity(0.2)
                }
                .frame(height: 220)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color(uiColor: .systemGroupedBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            HStack(alignment: .bottom, spacing: 16) {
                GameArtworkView(url: vm.game.artUrl, cornerRadius: 12, aspectRatio: 3/4)
                    .frame(width: 90, height: 120)
                    .shadow(color: .black.opacity(0.2), radius: 10)

                VStack(alignment: .leading, spacing: 6) {
                    if let year = vm.game.year, !year.isEmpty {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(vm.game.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    if let dev = vm.game.developer, !dev.isEmpty {
                        Text(dev)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func detailRow(_ label: String, icon: String, binding: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            GlassTextField(placeholder: placeholder, text: binding, icon: icon, keyboardType: keyboardType, autocapitalization: .words, autocorrect: false)
        }
    }

    private func metacriticColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Status Select Button

struct StatusSelectButton: View {
    let status: GameStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.title3)
                Text(status.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? statusColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
                        }
                    }
            }
            .foregroundStyle(isSelected ? statusColor : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var statusColor: Color {
        switch status {
        case .playing: return .green
        case .played: return .blue
        case .toplay: return .orange
        }
    }
}
