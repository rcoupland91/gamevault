import SwiftUI

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var showRegister = false

    var body: some View {
        ZStack {
            // Background
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.indigo.opacity(0.3), Color.purple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                }

                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, Color.white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(color: Color.indigo.opacity(0.4), radius: 20)

                        VStack(spacing: 4) {
                            Text("GameVault")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Your personal game library")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Login Form
                    GlassCard {
                        VStack(spacing: 16) {
                            VStack(spacing: 10) {
                                GlassTextField(
                                    placeholder: "Email or username",
                                    text: $authVM.loginInput,
                                    icon: "person",
                                    autocapitalization: .never,
                                    autocorrect: false
                                )

                                GlassTextField(
                                    placeholder: "Password",
                                    text: $authVM.loginPassword,
                                    isSecure: true,
                                    icon: "lock"
                                )
                            }

                            if let error = authVM.error {
                                ErrorBanner(message: error) {
                                    authVM.error = nil
                                }
                            }

                            GlassButton(
                                title: "Sign In",
                                icon: "arrow.right",
                                action: { Task { await authVM.login() } },
                                isLoading: authVM.isLoading
                            )
                        }
                    }

                    // Server config button
                    Button {
                        authVM.showServerSetup = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                                .font(.caption)
                            Text(authVM.serverURL.isEmpty ? "Configure Server" : authVM.serverURL)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }

                    // Register link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Button("Sign Up") { showRegister = true }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.indigo)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView(authVM: authVM)
        }
        .sheet(isPresented: $authVM.showServerSetup) {
            ServerSetupView(authVM: authVM)
        }
        .sheet(isPresented: $authVM.requires2FA) {
            TwoFactorView(authVM: authVM)
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(
                colors: [Color.indigo.opacity(0.15), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color.purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                            Text("Create Account")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Join GameVault and start tracking your games")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        GlassCard {
                            VStack(spacing: 14) {
                                GlassTextField(
                                    placeholder: "Username",
                                    text: $authVM.registerUsername,
                                    icon: "person",
                                    autocapitalization: .never,
                                    autocorrect: false
                                )
                                GlassTextField(
                                    placeholder: "Email",
                                    text: $authVM.registerEmail,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    autocorrect: false
                                )
                                GlassTextField(
                                    placeholder: "Password (min 8 characters)",
                                    text: $authVM.registerPassword,
                                    isSecure: true,
                                    icon: "lock"
                                )
                                GlassTextField(
                                    placeholder: "Confirm Password",
                                    text: $authVM.registerConfirmPassword,
                                    isSecure: true,
                                    icon: "lock.shield"
                                )

                                if let error = authVM.error {
                                    ErrorBanner(message: error) { authVM.error = nil }
                                }

                                GlassButton(
                                    title: "Create Account",
                                    icon: "person.badge.plus",
                                    action: { Task { await authVM.register() } },
                                    isLoading: authVM.isLoading
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
