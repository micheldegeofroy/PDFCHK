import SwiftUI
import AppKit

// MARK: - Comparison View
struct ComparisonView: View {
    @StateObject private var viewModel = ComparisonViewModel()
    @StateObject private var scrollSync = ScrollSyncManager()

    let originalAnalysis: PDFAnalysis?
    let comparisonAnalysis: PDFAnalysis?
    let imageComparison: ImageComparisonResult?

    var body: some View {
        VStack(spacing: 0) {
            ComparisonToolbar(viewModel: viewModel, isComparisonMode: comparisonAnalysis != nil)

            GeometryReader { geometry in
                // Single document mode - no header, just the document
                if comparisonAnalysis == nil {
                    SingleDocumentView(
                        title: nil,
                        image: viewModel.originalPageImage,
                        zoom: viewModel.zoomLevel
                    )
                } else {
                    // Comparison mode - show based on view mode
                    switch viewModel.viewMode {
                    case .sideBySide:
                        HStack(spacing: 0) {
                            SyncedDocumentView(
                                title: "First Document",
                                image: viewModel.originalPageImage,
                                zoom: viewModel.zoomLevel,
                                scrollSync: scrollSync,
                                paneId: "original"
                            )

                            Divider()
                                .background(DesignSystem.Colors.border)

                            SyncedDocumentView(
                                title: "Second Document",
                                image: viewModel.comparisonPageImage,
                                zoom: viewModel.zoomLevel,
                                scrollSync: scrollSync,
                                paneId: "comparison",
                                showDiffOverlay: viewModel.showDiffOverlay,
                                diffImage: viewModel.diffImage
                            )
                        }

                    case .originalOnly:
                        SingleDocumentView(
                            title: "First Document",
                            image: viewModel.originalPageImage,
                            zoom: viewModel.zoomLevel
                        )

                    case .comparisonOnly:
                        SingleDocumentView(
                            title: "Second Document",
                            image: viewModel.comparisonPageImage,
                            zoom: viewModel.zoomLevel,
                            showDiffOverlay: viewModel.showDiffOverlay,
                            diffImage: viewModel.diffImage
                        )

                    case .overlay:
                        OverlayPageView(
                            original: viewModel.originalPageImage,
                            comparison: viewModel.comparisonPageImage,
                            zoom: viewModel.zoomLevel
                        )

                    case .diffOnly:
                        DiffOnlyView(
                            diffImage: viewModel.diffImage,
                            zoom: viewModel.zoomLevel
                        )
                    }
                }
            }

            PageNavigationBar(viewModel: viewModel)
        }
        .background(DesignSystem.Colors.background)
        .onAppear {
            viewModel.configure(
                original: originalAnalysis,
                comparison: comparisonAnalysis,
                imageComparison: imageComparison
            )
        }
        .onChange(of: viewModel.currentPage) { _ in
            scrollSync.scrollPosition = 0
        }
        .onChange(of: viewModel.scrollSyncEnabled) { enabled in
            scrollSync.isEnabled = enabled
        }
    }
}

// MARK: - Scroll Sync Manager
class ScrollSyncManager: ObservableObject {
    @Published var scrollPosition: CGFloat = 0
    @Published var isEnabled: Bool = true
    var activePane: String? = nil
    var isUpdating: Bool = false
}

// MARK: - Synced Document View
struct SyncedDocumentView: View {
    let title: String
    let image: NSImage?
    let zoom: Double
    @ObservedObject var scrollSync: ScrollSyncManager
    let paneId: String
    var showDiffOverlay: Bool = false
    var diffImage: NSImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.background)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DesignSystem.Colors.border),
                    alignment: .bottom
                )

            if let img = image {
                LinkedScrollView(
                    image: img,
                    zoom: zoom,
                    scrollSync: scrollSync,
                    paneId: paneId,
                    showDiffOverlay: showDiffOverlay,
                    diffImage: diffImage
                )
            } else {
                Text("No page available")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.background)
            }
        }
    }
}

// MARK: - Linked Scroll View
struct LinkedScrollView: NSViewRepresentable {
    let image: NSImage
    let zoom: Double
    @ObservedObject var scrollSync: ScrollSyncManager
    let paneId: String
    var showDiffOverlay: Bool = false
    var diffImage: NSImage? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .white
        scrollView.drawsBackground = true
        scrollView.autohidesScrollers = false

        // Create flipped document view for top-to-bottom layout
        let documentView = FlippedDocumentView()
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.white.cgColor
        scrollView.documentView = documentView

        // Main image view
        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.wantsLayer = true
        documentView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Diff overlay
        let diffView = NSImageView()
        diffView.imageScaling = .scaleNone
        diffView.wantsLayer = true
        diffView.alphaValue = 0.5
        documentView.addSubview(diffView)
        context.coordinator.diffView = diffView

        context.coordinator.scrollView = scrollView
        context.coordinator.documentView = documentView

        // Listen for scroll events
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let documentView = context.coordinator.documentView,
              let imageView = context.coordinator.imageView,
              let diffView = context.coordinator.diffView else { return }

        // Calculate sizes
        let scrollWidth = scrollView.bounds.width
        let scrollerWidth: CGFloat = 15
        let padding: CGFloat = 16
        let availableWidth = max(100, scrollWidth - scrollerWidth - padding * 2)

        let scale = (availableWidth / image.size.width) * zoom
        let scaledSize = NSSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Create scaled image
        let scaledImage = NSImage(size: scaledSize)
        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: scaledSize))
        scaledImage.unlockFocus()

        // Update document view size
        let docHeight = scaledSize.height + padding * 2
        documentView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: docHeight)

        // Update image view
        imageView.image = scaledImage
        imageView.frame = NSRect(
            x: padding,
            y: padding,
            width: scaledSize.width,
            height: scaledSize.height
        )

        // Update diff overlay
        if showDiffOverlay, let diff = diffImage {
            let scaledDiff = NSImage(size: scaledSize)
            scaledDiff.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            diff.draw(in: NSRect(origin: .zero, size: scaledSize))
            scaledDiff.unlockFocus()

            diffView.image = scaledDiff
            diffView.frame = imageView.frame
            diffView.isHidden = false
            diffView.layer?.compositingFilter = CIFilter(name: "CIMultiplyBlendMode")
        } else {
            diffView.isHidden = true
        }

        // Store values for scroll sync
        context.coordinator.contentHeight = docHeight
        context.coordinator.visibleHeight = scrollView.contentView.bounds.height
        context.coordinator.paneId = paneId
        context.coordinator.scrollSync = scrollSync

        // Sync scroll position from other pane
        if scrollSync.isEnabled && scrollSync.activePane != paneId && !context.coordinator.isSyncing {
            let maxScroll = max(0, docHeight - scrollView.contentView.bounds.height)
            if maxScroll > 0 {
                let targetY = scrollSync.scrollPosition * maxScroll
                let currentY = scrollView.contentView.bounds.origin.y

                if abs(targetY - currentY) > 1 {
                    context.coordinator.isSyncing = true
                    scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: targetY))
                    context.coordinator.isSyncing = false
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var scrollView: NSScrollView?
        weak var documentView: NSView?
        weak var imageView: NSImageView?
        weak var diffView: NSImageView?
        var scrollSync: ScrollSyncManager?
        var paneId: String = ""
        var contentHeight: CGFloat = 0
        var visibleHeight: CGFloat = 0
        var isSyncing: Bool = false

        @objc func boundsDidChange(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let scrollSync = scrollSync,
                  scrollSync.isEnabled,
                  !isSyncing else { return }

            let maxScroll = max(1, contentHeight - visibleHeight)
            let currentY = scrollView.contentView.bounds.origin.y
            let normalized = min(1.0, max(0.0, currentY / maxScroll))

            // Set this pane as active and update position
            scrollSync.activePane = paneId
            scrollSync.scrollPosition = normalized

            // Clear active pane after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                if scrollSync.activePane == self?.paneId {
                    scrollSync.activePane = nil
                }
            }
        }
    }
}

// MARK: - Flipped Document View
class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Single Document View
struct SingleDocumentView: View {
    let title: String?
    let image: NSImage?
    let zoom: Double
    var showDiffOverlay: Bool = false
    var diffImage: NSImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Only show header if title is provided
            if let title = title {
                Text(title)
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.background)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(DesignSystem.Colors.border),
                        alignment: .bottom
                    )
            }

            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    if let img = image {
                        let containerWidth = geometry.size.width
                        let padding: CGFloat = 16
                        let availableWidth = containerWidth - padding * 2
                        let scale = (availableWidth / img.size.width) * zoom
                        let scaledWidth = img.size.width * scale
                        let scaledHeight = img.size.height * scale

                        ZStack {
                            Image(nsImage: img)
                                .resizable()
                                .frame(width: scaledWidth, height: scaledHeight)

                            if showDiffOverlay, let diff = diffImage {
                                Image(nsImage: diff)
                                    .resizable()
                                    .frame(width: scaledWidth, height: scaledHeight)
                                    .opacity(0.5)
                                    .blendMode(.multiply)
                            }
                        }
                        .frame(width: containerWidth)
                        .padding(.vertical, padding)
                    } else {
                        Text("No page available")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Comparison Toolbar
struct ComparisonToolbar: View {
    @ObservedObject var viewModel: ComparisonViewModel
    @EnvironmentObject var mainViewModel: MainViewModel
    let isComparisonMode: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // View mode button - only show cycle in comparison mode
            if isComparisonMode {
                Button(action: {
                    viewModel.cycleViewMode()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModeIcon)
                            .font(.system(size: 12))
                        Text(viewModel.viewMode.rawValue)
                            .font(DesignSystem.Typography.body)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
                }
                .buttonStyle(.plain)
            } else {
                // Single document mode - show "Add a Document" button
                Button(action: {
                    mainViewModel.selectComparisonFile()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 12))
                        Text("Add a Document")
                            .font(DesignSystem.Typography.body)
                    }
                    .foregroundColor(.white)
                    .frame(width: 160)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Show Diff toggle for side-by-side and comparison modes (only in comparison mode)
            if isComparisonMode && (viewModel.viewMode == .sideBySide || viewModel.viewMode == .comparisonOnly) {
                Toggle("Show Diff", isOn: $viewModel.showDiffOverlay)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Divider()
                    .frame(height: 20)
            }

            // Sync Scroll toggle only for side-by-side (only in comparison mode)
            if isComparisonMode && viewModel.viewMode == .sideBySide {
                Toggle("Sync Scroll", isOn: $viewModel.scrollSyncEnabled)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Divider()
                    .frame(height: 20)
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                IconButton(systemName: "minus.magnifyingglass", action: viewModel.zoomOut)
                Text("\(viewModel.zoomPercentage)%")
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 50)
                IconButton(systemName: "plus.magnifyingglass", action: viewModel.zoomIn)
                IconButton(systemName: "1.magnifyingglass", action: viewModel.resetZoom)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }

    private var viewModeIcon: String {
        switch viewModel.viewMode {
        case .sideBySide: return "rectangle.split.2x1"
        case .originalOnly: return "doc"
        case .comparisonOnly: return "doc.fill"
        case .overlay: return "square.on.square"
        case .diffOnly: return "rectangle.dashed"
        }
    }
}

// MARK: - Overlay Page View
struct OverlayPageView: View {
    let original: NSImage?
    let comparison: NSImage?
    let zoom: Double
    @State private var overlayOpacity: Double = 0.5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("First Document")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Slider(value: $overlayOpacity, in: 0...1)
                    .accentColor(DesignSystem.Colors.accent)
                    .frame(width: 200)

                Text("Comparison")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.Colors.border),
                alignment: .bottom
            )

            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    if let img = original ?? comparison {
                        let containerWidth = geometry.size.width
                        let padding: CGFloat = 16
                        let availableWidth = containerWidth - padding * 2
                        let scale = (availableWidth / img.size.width) * zoom
                        let scaledWidth = img.size.width * scale
                        let scaledHeight = img.size.height * scale

                        ZStack {
                            if let orig = original {
                                Image(nsImage: orig)
                                    .resizable()
                                    .frame(width: scaledWidth, height: scaledHeight)
                                    .opacity(1 - overlayOpacity)
                            }
                            if let comp = comparison {
                                Image(nsImage: comp)
                                    .resizable()
                                    .frame(width: scaledWidth, height: scaledHeight)
                                    .opacity(overlayOpacity)
                            }
                        }
                        .frame(width: containerWidth)
                        .padding(.vertical, padding)
                    } else {
                        Text("No page available")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Diff Only View
struct DiffOnlyView: View {
    let diffImage: NSImage?
    let zoom: Double

    var body: some View {
        VStack(spacing: 0) {
            Text("Difference Visualization")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.background)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DesignSystem.Colors.border),
                    alignment: .bottom
                )

            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    if let img = diffImage {
                        let containerWidth = geometry.size.width
                        let padding: CGFloat = 16
                        let availableWidth = containerWidth - padding * 2
                        let scale = (availableWidth / img.size.width) * zoom
                        let scaledWidth = img.size.width * scale
                        let scaledHeight = img.size.height * scale

                        Image(nsImage: img)
                            .resizable()
                            .frame(width: scaledWidth, height: scaledHeight)
                            .frame(width: containerWidth)
                            .padding(.vertical, padding)
                    } else {
                        Text("No difference image available")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Page Navigation Bar
struct PageNavigationBar: View {
    @ObservedObject var viewModel: ComparisonViewModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            IconButton(systemName: "chevron.left.2", action: viewModel.goToFirstPage, isEnabled: viewModel.hasPreviousPage)
            IconButton(systemName: "chevron.left", action: viewModel.previousPage, isEnabled: viewModel.hasPreviousPage)
            IconButton(systemName: "exclamationmark.triangle", action: viewModel.goToPreviousDifference, isEnabled: viewModel.hasPreviousDifference)

            Spacer()

            Text("Page \(viewModel.currentPageDisplay) of \(viewModel.pageCount)")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let result = viewModel.currentPageResult {
                Text(String(format: "SSIM: %.1f%%", result.ssim * 100))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            IconButton(systemName: "exclamationmark.triangle.fill", action: viewModel.goToNextDifference, isEnabled: viewModel.hasNextDifference)
            IconButton(systemName: "chevron.right", action: viewModel.nextPage, isEnabled: viewModel.hasNextPage)
            IconButton(systemName: "chevron.right.2", action: viewModel.goToLastPage, isEnabled: viewModel.hasNextPage)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .top
        )
    }
}
