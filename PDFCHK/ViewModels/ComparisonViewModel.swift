import Foundation
import SwiftUI
import PDFKit

// MARK: - Comparison View Model
@MainActor
class ComparisonViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var currentPage: Int = 0
    @Published var zoomLevel: Double = 1.0
    @Published var showDiffOverlay: Bool = false
    @Published var viewMode: ViewMode = .sideBySide
    @Published var syncedScrollOffset: CGFloat = 0
    @Published var scrollSyncEnabled: Bool = true
    @Published var activeScrollPane: String? = nil  // Which pane is actively scrolling

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case originalOnly = "First PDF"
        case comparisonOnly = "Second PDF"
        case overlay = "Overlay"
        case diffOnly = "Diff Only"
    }

    // MARK: - Properties
    var originalAnalysis: PDFAnalysis?
    var comparisonAnalysis: PDFAnalysis?
    var imageComparison: ImageComparisonResult?

    // MARK: - Computed Properties
    var pageCount: Int {
        max(originalAnalysis?.pageCount ?? 0, comparisonAnalysis?.pageCount ?? 0)
    }

    var currentPageDisplay: Int {
        currentPage + 1
    }

    var originalPageImage: NSImage? {
        originalAnalysis?.pageImages[currentPage]
    }

    var comparisonPageImage: NSImage? {
        comparisonAnalysis?.pageImages[currentPage]
    }

    var diffImage: NSImage? {
        imageComparison?.pageResults.first { $0.pageNumber == currentPage + 1 }?.diffImage
    }

    var currentPageResult: PageImageResult? {
        imageComparison?.pageResults.first { $0.pageNumber == currentPage + 1 }
    }

    var currentPageSSIM: Double {
        currentPageResult?.ssim ?? 0
    }

    var currentPageHasDifference: Bool {
        currentPageResult?.hasSignificantDifference ?? false
    }

    var pagesWithDifferences: [Int] {
        imageComparison?.pagesWithDifferences ?? []
    }

    // MARK: - Initialization
    init() {}

    func configure(
        original: PDFAnalysis?,
        comparison: PDFAnalysis?,
        imageComparison: ImageComparisonResult?
    ) {
        self.originalAnalysis = original
        self.comparisonAnalysis = comparison
        self.imageComparison = imageComparison
        self.currentPage = 0
    }

    // MARK: - Navigation
    func nextPage() {
        if currentPage < pageCount - 1 {
            currentPage += 1
        }
    }

    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }

    func goToPage(_ page: Int) {
        if page >= 0 && page < pageCount {
            currentPage = page
        }
    }

    func goToFirstPage() {
        currentPage = 0
    }

    func goToLastPage() {
        currentPage = max(0, pageCount - 1)
    }

    func goToNextDifference() {
        let nextDiff = pagesWithDifferences.first { $0 > currentPage + 1 }
        if let next = nextDiff {
            currentPage = next - 1
        }
    }

    func goToPreviousDifference() {
        let prevDiff = pagesWithDifferences.last { $0 < currentPage + 1 }
        if let prev = prevDiff {
            currentPage = prev - 1
        }
    }

    // MARK: - Zoom
    func zoomIn() {
        zoomLevel = min(4.0, zoomLevel * 1.25)
    }

    func zoomOut() {
        zoomLevel = max(0.25, zoomLevel / 1.25)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }

    func fitToWindow() {
        zoomLevel = 1.0
    }

    var zoomPercentage: Int {
        Int(zoomLevel * 100)
    }

    // MARK: - View Mode
    func toggleDiffOverlay() {
        showDiffOverlay.toggle()
    }

    func setViewMode(_ mode: ViewMode) {
        viewMode = mode
    }

    func cycleViewMode() {
        let allModes = ViewMode.allCases
        if let currentIndex = allModes.firstIndex(of: viewMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            viewMode = allModes[nextIndex]
        }
    }

    // MARK: - Page Info
    func pageInfo(for page: Int) -> String {
        guard let result = imageComparison?.pageResults.first(where: { $0.pageNumber == page + 1 }) else {
            return "No data"
        }
        return String(format: "SSIM: %.1f%%", result.ssim * 100)
    }

    var hasNextPage: Bool {
        currentPage < pageCount - 1
    }

    var hasPreviousPage: Bool {
        currentPage > 0
    }

    var hasNextDifference: Bool {
        pagesWithDifferences.contains { $0 > currentPage + 1 }
    }

    var hasPreviousDifference: Bool {
        pagesWithDifferences.contains { $0 < currentPage + 1 }
    }

    // MARK: - Scroll Sync
    func updateScrollOffset(_ offset: CGFloat) {
        if scrollSyncEnabled {
            syncedScrollOffset = offset
        }
    }

    func toggleScrollSync() {
        scrollSyncEnabled.toggle()
    }
}
