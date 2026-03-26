import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?

    // Login
    @Published var loginInput = ""
    @Published var loginPassword = ""

    // Register
    @Published var registerUsername = ""
    @Published var registerEmail = ""
    @Published var registerPassword = ""
    @Published var registerConfirmPassword = ""

    // 2FA
    @Published var requires2FA = false
    @Published var preToken = ""
    @Published var twoFACode = ""
    @Published var twoFAMethods: TwoFAMethods?
    @Published var selected2FAMethod = "totp"
    @Published var otpResentSuccess = false

    // Server
    @Published var serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
    @Published var showServerSetup = false

    private let auth = AuthService.shared

    init() {
        isLoggedIn = auth.isLoggedIn
        if isLoggedIn {
            Task { await loadCurrentUser() }
        }
    }

    // MARK: - Login

    func login() async {
        guard !serverURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Please configure your server URL first."
            showServerSetup = true
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await auth.login(login: loginInput, password: loginPassword)

            if response.requires2FA == true {
                preToken = response.preToken ?? ""
                twoFAMethods = response.methods
                selected2FAMethod = (response.methods?.totp == true) ? "totp" : "email"
                requires2FA = true
            } else if let user = response.user {
                currentUser = user
                isLoggedIn = true
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 2FA Verify

    func verify2FA() async {
        isLoading = true
        error = nil

        do {
            let response = try await auth.verify2FA(preToken: preToken, code: twoFACode, method: selected2FAMethod)
            if let user = response.user {
                currentUser = user
                isLoggedIn = true
                requires2FA = false
                twoFACode = ""
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func resendEmailOTP() async {
        do {
            try await auth.resendEmailOTP(preToken: preToken)
            otpResentSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.otpResentSuccess = false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Register

    func register() async {
        guard registerPassword == registerConfirmPassword else {
            error = "Passwords do not match"
            return
        }
        guard registerPassword.count >= 8 else {
            error = "Password must be at least 8 characters"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await auth.register(username: registerUsername, email: registerEmail, password: registerPassword)
            if let user = response.user {
                currentUser = user
                isLoggedIn = true
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Profile

    func loadCurrentUser() async {
        do {
            currentUser = try await auth.me()
        } catch {
            if case APIServiceError.unauthorized = error {
                logout()
            }
        }
    }

    func updateProfile(username: String? = nil, currentPassword: String? = nil, newPassword: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        currentUser = try await auth.updateProfile(username: username, currentPassword: currentPassword, newPassword: newPassword)
    }

    // MARK: - Logout

    func logout() {
        Task {
            try? await auth.logout()
        }
        auth.clearSession()
        currentUser = nil
        isLoggedIn = false
        requires2FA = false
        loginInput = ""
        loginPassword = ""
        twoFACode = ""
    }

    // MARK: - Server URL

    func saveServerURL() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
        APIService.shared.baseURL = trimmed
        showServerSetup = false
    }
}
