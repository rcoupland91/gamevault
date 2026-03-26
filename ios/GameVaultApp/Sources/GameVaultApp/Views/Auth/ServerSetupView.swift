import SwiftUI

struct ServerSetupView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isTestingConnection = false
    @State private var connectionResult: String?
    @State private var connectionSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.indigo.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "server.rack")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                                    )
                            }
                            Text("Server Setup")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Enter the URL of your GameVault server")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Server URL")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                GlassTextField(
                                    placeholder: "http://192.168.1.100:3000",
                                    text: $authVM.serverURL,
                                    icon: "link",
                                    keyboardType: .URL,
                                    autocapitalization: .never,
                                    autocorrect: false
                                )

                                Text("This is the address of your self-hosted GameVault instance. Include http:// or https://")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Connection test result
                                if let result = connectionResult {
                                    HStack(spacing: 8) {
                                        Image(systemName: connectionSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                            .foregroundStyle(connectionSuccess ? .green : .red)
                                        Text(result)
                                            .font(.caption)
                                            .foregroundStyle(connectionSuccess ? .green : .red)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            GlassButton(
                                title: isTestingConnection ? "Testing..." : "Test Connection",
                                icon: "wifi",
                                action: testConnection,
                                isLoading: isTestingConnection,
                                style: .glass
                            )

                            GlassButton(
                                title: "Save & Continue",
                                icon: "checkmark",
                                action: save
                            )
                        }

                        // Examples
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Common examples:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                ForEach(examples, id: \.self) { example in
                                    Button {
                                        authVM.serverURL = example
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.right.circle")
                                                .font(.caption)
                                                .foregroundStyle(.indigo)
                                            Text(example)
                                                .font(.caption)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Configure Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private let examples = [
        "http://192.168.1.100:3000",
        "http://10.0.0.5:3000",
        "https://games.yourdomain.com"
    ]

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.indigo.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func testConnection() {
        guard !authVM.serverURL.isEmpty else {
            connectionResult = "Please enter a server URL"
            connectionSuccess = false
            return
        }

        isTestingConnection = true
        connectionResult = nil
        APIService.shared.baseURL = authVM.serverURL

        Task {
            do {
                struct HealthResponse: Decodable { let status: String? }
                let response: HealthResponse = try await APIService.shared.request("/health", retryOnUnauthorized: false)
                connectionResult = "Connected successfully! Server is healthy."
                connectionSuccess = true
            } catch {
                connectionResult = "Could not connect: \(error.localizedDescription)"
                connectionSuccess = false
            }
            isTestingConnection = false
        }
    }

    private func save() {
        authVM.saveServerURL()
        dismiss()
    }
}
