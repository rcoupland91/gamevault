import SwiftUI

struct ProfileView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var show2FASetup = false
    @State private var showServerSetup = false
    @State private var showLogoutConfirm = false
    @State private var showAdminPanel = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Profile header
                        profileHeader

                        // Account section
                        settingsSection(title: "Account") {
                            SettingsRow(icon: "person.fill", title: "Edit Profile", color: .indigo) {
                                showEditProfile = true
                            }
                            Divider().padding(.leading, 52)
                            SettingsRow(icon: "lock.fill", title: "Change Password", color: .blue) {
                                showChangePassword = true
                            }
                            Divider().padding(.leading, 52)
                            SettingsRow(icon: "shield.fill", title: "Two-Factor Authentication", color: .green) {
                                show2FASetup = true
                            }
                        }

                        // Server section
                        settingsSection(title: "Server") {
                            SettingsRow(icon: "server.rack", title: "Server Settings", color: .purple) {
                                showServerSetup = true
                            }
                            if let url = UserDefaults.standard.string(forKey: "server_url"), !url.isEmpty {
                                Divider().padding(.leading, 52)
                                HStack {
                                    Spacer().frame(width: 52)
                                    Text(url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.trailing, 16)
                            }
                        }

                        // Admin section
                        if authVM.currentUser?.isAdmin == true {
                            settingsSection(title: "Administration") {
                                SettingsRow(icon: "person.3.fill", title: "User Management", color: .orange) {
                                    showAdminPanel = true
                                }
                            }
                        }

                        // Stats
                        if let user = authVM.currentUser, let createdAt = user.createdAt {
                            settingsSection(title: "Account Info") {
                                infoRow("User ID", value: String(user.id.prefix(8)) + "...")
                                Divider().padding(.leading, 16)
                                infoRow("Member since", value: formatDate(createdAt))
                                if user.isAdmin == true {
                                    Divider().padding(.leading, 16)
                                    HStack {
                                        Text("Role")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(.yellow)
                                            Text("Administrator")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }

                        // Logout
                        GlassButton(
                            title: "Sign Out",
                            icon: "rectangle.portrait.and.arrow.right",
                            action: { showLogoutConfirm = true },
                            isDestructive: true,
                            style: .secondary
                        )
                        .padding(.horizontal, 16)

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(authVM: authVM)
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView(authVM: authVM)
            }
            .sheet(isPresented: $show2FASetup) {
                TwoFAManagementView()
            }
            .sheet(isPresented: $showServerSetup) {
                ServerSetupView(authVM: authVM)
            }
            .sheet(isPresented: $showAdminPanel) {
                AdminPanelView()
            }
            .confirmationDialog("Sign out of GameVault?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authVM.logout() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 70, height: 70)
                    if let avatarUrl = authVM.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        .clipShape(Circle())
                        .frame(width: 70, height: 70)
                    } else {
                        Text(authVM.currentUser?.username.prefix(1).uppercased() ?? "G")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(authVM.currentUser?.username ?? "Loading...")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(authVM.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if authVM.currentUser?.isAdmin == true {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("Admin")
                                .font(.caption)
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            GlassCard(cornerRadius: 16, padding: 0) {
                content()
            }
            .padding(.horizontal, 16)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.leading, 4)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var avatarUrl = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Username").font(.caption).foregroundStyle(.secondary)
                                GlassTextField(placeholder: "Username", text: $username, icon: "person", autocapitalization: .never, autocorrect: false)
                            }
                            Divider().opacity(0.5)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Avatar URL").font(.caption).foregroundStyle(.secondary)
                                GlassTextField(placeholder: "https://...", text: $avatarUrl, icon: "photo.circle", keyboardType: .URL, autocapitalization: .never, autocorrect: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if let error { ErrorBanner(message: error).padding(.horizontal, 16) }

                    if success {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Profile updated").foregroundStyle(.green)
                        }
                    }

                    GlassButton(title: "Save Changes", icon: "checkmark", action: save, isLoading: isSaving)
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                username = authVM.currentUser?.username ?? ""
                avatarUrl = authVM.currentUser?.avatarUrl ?? ""
            }
        }
    }

    private func save() {
        isSaving = true
        error = nil
        Task {
            do {
                try await authVM.updateProfile(
                    username: username.isEmpty ? nil : username,
                    currentPassword: nil,
                    newPassword: nil
                )
                success = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 14) {
                            GlassTextField(placeholder: "Current password", text: $currentPassword, isSecure: true, icon: "lock")
                            Divider().opacity(0.5)
                            GlassTextField(placeholder: "New password (min 8 chars)", text: $newPassword, isSecure: true, icon: "lock.open")
                            Divider().opacity(0.5)
                            GlassTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true, icon: "lock.shield")
                        }
                    }
                    .padding(.horizontal, 16)

                    if let error { ErrorBanner(message: error).padding(.horizontal, 16) }
                    if success {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Password changed").foregroundStyle(.green)
                        }
                    }

                    GlassButton(title: "Change Password", icon: "lock.rotation", action: changePassword, isLoading: isSaving, isDestructive: false)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func changePassword() {
        guard newPassword == confirmPassword else { error = "Passwords don't match"; return }
        guard newPassword.count >= 8 else { error = "Password must be at least 8 characters"; return }
        isSaving = true
        Task {
            do {
                try await authVM.updateProfile(currentPassword: currentPassword, newPassword: newPassword)
                success = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - 2FA Management (stub - expand as needed)

struct TwoFAManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status: TwoFAStatus?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.indigo)
                } else {
                    VStack(spacing: 20) {
                        GlassCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "qrcode").foregroundStyle(.indigo)
                                    Text("Authenticator App (TOTP)")
                                    Spacer()
                                    Image(systemName: (status?.totpEnabled ?? false) ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle((status?.totpEnabled ?? false) ? .green : .secondary)
                                }
                                Divider()
                                HStack {
                                    Image(systemName: "envelope").foregroundStyle(.blue)
                                    Text("Email OTP")
                                    Spacer()
                                    Image(systemName: (status?.emailOtpEnabled ?? false) ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle((status?.emailOtpEnabled ?? false) ? .green : .secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Text("To configure 2FA settings, use the GameVault web interface.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Two-Factor Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task {
                status = try? await AuthService.shared.get2FAStatus()
                isLoading = false
            }
        }
    }
}

// MARK: - Admin Panel

struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                if isLoading {
                    ProgressView("Loading users...").tint(.indigo)
                } else if let error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.red)
                        Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadUsers() } }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(users) { user in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(user.isAdmin ? Color.yellow.opacity(0.2) : Color.indigo.opacity(0.1)).frame(width: 40, height: 40)
                                    Text(user.username.prefix(1).uppercased())
                                        .fontWeight(.bold)
                                        .foregroundStyle(user.isAdmin ? .yellow : .indigo)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(user.username).fontWeight(.medium)
                                        if user.isAdmin {
                                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                                        }
                                    }
                                    Text(user.email).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !user.isActive {
                                    Text("Disabled").font(.caption).foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task { await loadUsers() }
        }
    }

    private func loadUsers() async {
        isLoading = true
        do {
            users = try await APIService.shared.request("/admin/users")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
