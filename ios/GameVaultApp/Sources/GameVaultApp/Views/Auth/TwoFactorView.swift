import SwiftUI

struct TwoFactorView: View {
    @ObservedObject var authVM: AuthViewModel
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color.indigo.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Icon + Title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 90, height: 90)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                        }
                        .shadow(color: .indigo.opacity(0.3), radius: 16)

                        Text("Two-Factor Authentication")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text(authVM.selected2FAMethod == "totp"
                            ? "Enter the 6-digit code from your authenticator app"
                            : "Enter the 6-digit code sent to your email")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Method Toggle
                    if authVM.twoFAMethods?.totp == true && authVM.twoFAMethods?.email == true {
                        HStack(spacing: 0) {
                            ForEach([("totp", "Authenticator", "qrcode"), ("email", "Email", "envelope")], id: \.0) { method, label, icon in
                                Button {
                                    authVM.selected2FAMethod = method
                                    authVM.twoFACode = ""
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: icon)
                                            .font(.caption)
                                        Text(label)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        authVM.selected2FAMethod == method
                                        ? Color.indigo
                                        : Color.clear
                                    )
                                    .foregroundStyle(
                                        authVM.selected2FAMethod == method ? .white : .secondary
                                    )
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Code Input
                    GlassCard(padding: 20) {
                        VStack(spacing: 20) {
                            // OTP-style digit display
                            TextField("000000", text: $authVM.twoFACode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .tracking(12)
                                .focused($codeFocused)
                                .onChange(of: authVM.twoFACode) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 6 {
                                        authVM.twoFACode = String(filtered.prefix(6))
                                    } else {
                                        authVM.twoFACode = filtered
                                    }
                                }

                            Text("\(authVM.twoFACode.count)/6 digits")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let error = authVM.error {
                                ErrorBanner(message: error) { authVM.error = nil }
                            }

                            if authVM.otpResentSuccess {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Code resent to your email")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            GlassButton(
                                title: "Verify",
                                icon: "checkmark.shield",
                                action: { Task { await authVM.verify2FA() } },
                                isLoading: authVM.isLoading
                            )
                            .disabled(authVM.twoFACode.count != 6)
                            .opacity(authVM.twoFACode.count != 6 ? 0.6 : 1)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Resend for email method
                    if authVM.selected2FAMethod == "email" {
                        Button {
                            Task { await authVM.resendEmailOTP() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                Text("Resend Code")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.indigo)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Verify Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        authVM.requires2FA = false
                        authVM.twoFACode = ""
                    }
                }
            }
            .onAppear { codeFocused = true }
        }
    }
}
