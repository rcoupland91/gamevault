import SwiftUI

@main
struct GameVaultApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(authVM: authVM)
                .preferredColorScheme(nil) // Respect system setting
        }
    }
}

struct RootView: View {
    @ObservedObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                MainTabView(authVM: authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                LoginView(authVM: authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: authVM.isLoggedIn)
    }
}
