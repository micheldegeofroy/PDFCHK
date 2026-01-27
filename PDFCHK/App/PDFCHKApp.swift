import SwiftUI

@main
struct PDFCHKApp: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .newItem) {
                Button("New Comparison") {
                    viewModel.reset()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Export as JSON...") {
                    viewModel.exportReportAsJSON()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(viewModel.viewState != .results)

                Button("Export as PDF...") {
                    viewModel.exportReportAsPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(viewModel.viewState != .results)
            }
        }
    }
}
