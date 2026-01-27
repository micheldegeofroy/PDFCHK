import SwiftUI

// MARK: - Main View
// Root view with state-based view switching
struct MainView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            // Background - always white per CLAUDE.md
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Content based on state
            switch viewModel.viewState {
            case .welcome:
                WelcomeView()
                    .transition(.opacity)

            case .analyzing:
                AnalysisProgressView()
                    .transition(.opacity)

            case .results:
                ResultsView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.viewState)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
}
