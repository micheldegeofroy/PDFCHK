import Foundation
import SwiftUI
import Combine
import PDFKit

// MARK: - Main View Model
@MainActor
class MainViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var viewState: AppViewState = .welcome
    @Published var droppedFiles = DroppedFiles()
    @Published var analysisProgress = AnalysisProgress.initial
    @Published var report: DetectionReport?
    @Published var error: AnalysisError?
    @Published var showError: Bool = false

    // Analysis state (for page viewer)
    @Published var originalAnalysis: PDFAnalysis?
    @Published var comparisonAnalysis: PDFAnalysis?
    @Published var imageComparison: ImageComparisonResult?
    @Published var textComparison: TextComparisonResult?

    // MARK: - Private Properties
    private let detectionEngine = DetectionEngine()
    private var analysisTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {}

    // MARK: - File Handling
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] data, error in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isPDF else {
                        return
                    }

                    Task { @MainActor in
                        self?.addFile(url: url)
                    }
                }
                return true
            }
        }
        return false
    }

    func addFile(url: URL) {
        if droppedFiles.originalURL == nil {
            droppedFiles.originalURL = url
        } else if droppedFiles.comparisonURL == nil {
            droppedFiles.comparisonURL = url
        }
    }

    func selectOriginalFile() {
        selectFile { [weak self] url in
            self?.droppedFiles.originalURL = url
        }
    }

    func selectComparisonFile() {
        selectFile { [weak self] url in
            self?.droppedFiles.comparisonURL = url
        }
    }

    private func selectFile(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        panel.title = "Select PDF"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    completion(url)
                }
            }
        }
    }

    func clearFiles() {
        droppedFiles.clear()
    }

    func swapFiles() {
        let temp = droppedFiles.originalURL
        droppedFiles.originalURL = droppedFiles.comparisonURL
        droppedFiles.comparisonURL = temp
    }

    // MARK: - Analysis
    func startAnalysis() {
        guard let originalURL = droppedFiles.originalURL,
              let comparisonURL = droppedFiles.comparisonURL else {
            return
        }

        viewState = .analyzing
        error = nil
        report = nil

        analysisTask = Task {
            do {
                // Create a local reference to engine for the async closure
                let engine = detectionEngine

                // Run analysis with progress updates
                let result = try await engine.runAnalysis(
                    originalURL: originalURL,
                    comparisonURL: comparisonURL
                ) { [weak self] progress in
                    await MainActor.run {
                        self?.analysisProgress = progress
                    }
                }

                self.report = result

                // Store analysis data for page viewer before transitioning to results
                await self.loadAnalysisData(originalURL: originalURL, comparisonURL: comparisonURL)

                self.viewState = .results

            } catch let analysisError as AnalysisError {
                self.error = analysisError
                self.showError = true
                self.viewState = .welcome
            } catch {
                self.error = .unknown(error)
                self.showError = true
                self.viewState = .welcome
            }
        }
    }

    private func loadAnalysisData(originalURL: URL, comparisonURL: URL) async {
        let pdfAnalyzer = PDFAnalyzer()
        let imageComp = ImageComparator()
        let textComp = TextComparator()

        do {
            let orig = try await pdfAnalyzer.analyze(url: originalURL)
            let comp = try await pdfAnalyzer.analyze(url: comparisonURL)

            self.originalAnalysis = orig
            self.comparisonAnalysis = comp

            self.imageComparison = await imageComp.compare(original: orig, comparison: comp)
            self.textComparison = await textComp.compare(original: orig, comparison: comp)
        } catch {
            // Analysis data couldn't be loaded, but report is still valid
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        Task {
            await detectionEngine.cancel()
        }
        viewState = .welcome
    }

    // MARK: - Reset
    func reset() {
        viewState = .welcome
        droppedFiles.clear()
        analysisProgress = .initial
        report = nil
        error = nil
        originalAnalysis = nil
        comparisonAnalysis = nil
        imageComparison = nil
        textComparison = nil
    }

    // MARK: - Export
    func exportReportAsJSON() {
        guard let report = report else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PDFCHCK-Report.json"
        panel.title = "Export Report as JSON"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ReportExporter.exportToJSON(report: report, url: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    func exportReportAsPDF() {
        guard let report = report else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "PDFCHCK-Report.pdf"
        panel.title = "Export Report as PDF"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ReportExporter.exportToPDF(report: report, url: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    // MARK: - Computed Properties
    var canStartAnalysis: Bool {
        droppedFiles.bothFilesSelected
    }

    var riskLevelText: String {
        report?.riskLevel.rawValue ?? "Unknown"
    }

    var riskScoreText: String {
        guard let score = report?.riskScore else { return "0" }
        return String(format: "%.0f", score)
    }
}
