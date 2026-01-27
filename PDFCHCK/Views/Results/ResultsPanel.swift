import SwiftUI

// MARK: - Results Panel
// 3-column layout: Summary | Findings | Metadata
struct ResultsPanel: View {
    let report: DetectionReport
    let originalAnalysis: PDFAnalysis?
    let comparisonAnalysis: PDFAnalysis?
    @State private var selectedTab: ResultsTab = .summary

    enum ResultsTab: String, CaseIterable {
        case summary = "Summary"
        case findings = "Findings"
        case security = "Security"
        case forensic = "Forensic"
        case metadata = "Metadata"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Missing tools notification banner
            if let message = report.externalToolsAnalysis?.toolsAvailable.missingToolsMessage {
                MissingToolsBanner(message: message)
            }

            // Tab bar
            HStack(spacing: 0) {
                ForEach(ResultsTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
            }
            .background(DesignSystem.Colors.background)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.Colors.border),
                alignment: .bottom
            )

            // Content
            switch selectedTab {
            case .summary:
                SummaryTab(report: report)
            case .findings:
                FindingsSection(findings: report.findings)
            case .security:
                SecurityTab(
                    originalAnalysis: originalAnalysis,
                    comparisonAnalysis: comparisonAnalysis,
                    findings: report.findings
                )
            case .forensic:
                ForensicTab(externalToolsAnalysis: report.externalToolsAnalysis)
            case .metadata:
                MetadataTab(
                    originalAnalysis: originalAnalysis,
                    comparisonAnalysis: comparisonAnalysis
                )
            }
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Missing Tools Banner
struct MissingToolsBanner: View {
    let message: String
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignSystem.Colors.accent)

                Text(message)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Button(action: { isDismissed = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.accent.opacity(0.05))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.Colors.border),
                alignment: .bottom
            )
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Rectangle()
                    .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Tab
struct SummaryTab: View {
    let report: DetectionReport

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Risk score
                RiskIndicator(riskLevel: report.riskLevel, score: report.riskScore)

                // File info
                HStack(spacing: DesignSystem.Spacing.md) {
                    FileInfoCard(title: "Original", file: report.originalFile)
                    FileInfoCard(title: "Comparison", file: report.comparisonFile)
                }

                // Similarity scores
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Similarity Analysis")
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    SimilarityBar(
                        label: "Text Similarity",
                        value: report.textComparison.overallSimilarity
                    )

                    SimilarityBar(
                        label: "Visual Similarity (SSIM)",
                        value: report.visualComparison.averageSSIM
                    )
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))

                // Summary statistics
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Summary")
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DesignSystem.Spacing.sm) {
                        StatCard(
                            title: "Total Findings",
                            value: "\(report.findings.count)"
                        )
                        StatCard(
                            title: "Critical",
                            value: "\(report.findings.criticalCount)"
                        )
                        StatCard(
                            title: "High",
                            value: "\(report.findings.highCount)"
                        )
                        StatCard(
                            title: "Pages Analyzed",
                            value: "\(report.textComparison.pageCount)"
                        )
                        StatCard(
                            title: "Pages with Text Diff",
                            value: "\(report.textComparison.pagesWithDifferences)"
                        )
                        StatCard(
                            title: "Pages with Visual Diff",
                            value: "\(report.visualComparison.pagesWithDifferences)"
                        )
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - File Info Card
struct FileInfoCard: View {
    let title: String
    let file: FileReference

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(file.name)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(file.formattedSize)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Metadata Tab
struct MetadataTab: View {
    let originalAnalysis: PDFAnalysis?
    let comparisonAnalysis: PDFAnalysis?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                if let orig = originalAnalysis, let comp = comparisonAnalysis {
                    // Side-by-side comparison
                    MetadataSideBySide(original: orig, comparison: comp)
                } else if let orig = originalAnalysis {
                    MetadataCard(title: "Original", analysis: orig)
                } else if let comp = comparisonAnalysis {
                    MetadataCard(title: "Comparison", analysis: comp)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Metadata Side By Side
struct MetadataSideBySide: View {
    let original: PDFAnalysis
    let comparison: PDFAnalysis

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header row
            HStack(spacing: 0) {
                Text("Field")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 140, alignment: .leading)

                Text("Original")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Comparison")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            // PDF Metadata section
            MetadataCompareSection(title: "PDF Metadata", rows: buildPDFMetadataRows())

            // PDF Internals section
            MetadataCompareSection(title: "PDF Internals", rows: buildInternalsRows())

            // Security & Content section
            MetadataCompareSection(title: "Security & Content", rows: buildSecurityRows())

            // Fonts section
            MetadataCompareSection(title: "Fonts", rows: buildFontRows())

            // File System section
            MetadataCompareSection(title: "File System", rows: buildFileSystemRows())

            // Extended Attributes section
            MetadataCompareSection(title: "Extended Attributes", rows: buildExtendedAttrRows())
        }
    }

    private func buildPDFMetadataRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let om = original.metadata
        let cm = comparison.metadata

        rows.append(CompareRow(label: "Title", original: om.title ?? "-", comparison: cm.title ?? "-"))
        rows.append(CompareRow(label: "Author", original: om.author ?? "-", comparison: cm.author ?? "-"))
        rows.append(CompareRow(label: "Subject", original: om.subject ?? "-", comparison: cm.subject ?? "-"))
        rows.append(CompareRow(label: "Creator", original: om.creator ?? "-", comparison: cm.creator ?? "-"))
        rows.append(CompareRow(label: "Producer", original: om.producer ?? "-", comparison: cm.producer ?? "-"))
        rows.append(CompareRow(label: "PDF Version", original: om.version ?? "-", comparison: cm.version ?? "-"))
        rows.append(CompareRow(label: "Created", original: om.creationDate?.formattedForDisplay ?? "-", comparison: cm.creationDate?.formattedForDisplay ?? "-"))
        rows.append(CompareRow(label: "Modified", original: om.modificationDate?.formattedForDisplay ?? "-", comparison: cm.modificationDate?.formattedForDisplay ?? "-"))
        rows.append(CompareRow(label: "Page Count", original: "\(original.pageCount)", comparison: "\(comparison.pageCount)"))
        rows.append(CompareRow(label: "Encrypted", original: om.isEncrypted ? "Yes" : "No", comparison: cm.isEncrypted ? "Yes" : "No"))
        rows.append(CompareRow(label: "Allows Printing", original: om.allowsPrinting ? "Yes" : "No", comparison: cm.allowsPrinting ? "Yes" : "No"))
        rows.append(CompareRow(label: "Allows Copying", original: om.allowsCopying ? "Yes" : "No", comparison: cm.allowsCopying ? "Yes" : "No"))

        return rows
    }

    private func buildInternalsRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let om = original.metadata
        let cm = comparison.metadata

        rows.append(CompareRow(label: "Document ID (Perm)", original: om.documentID?.permanent ?? "-", comparison: cm.documentID?.permanent ?? "-"))
        rows.append(CompareRow(label: "Document ID (Inst)", original: om.documentID?.changing ?? "-", comparison: cm.documentID?.changing ?? "-"))
        rows.append(CompareRow(label: "Linearized", original: om.isLinearized ? "Yes" : "No", comparison: cm.isLinearized ? "Yes" : "No"))
        rows.append(CompareRow(label: "Has XMP", original: om.hasXMPMetadata ? "Yes" : "No", comparison: cm.hasXMPMetadata ? "Yes" : "No"))
        rows.append(CompareRow(label: "Incremental Updates", original: "\(om.incrementalUpdates)", comparison: "\(cm.incrementalUpdates)"))
        rows.append(CompareRow(label: "Object Count", original: "\(om.objectCount)", comparison: "\(cm.objectCount)"))
        rows.append(CompareRow(label: "XRef Type", original: om.xrefType ?? "-", comparison: cm.xrefType ?? "-"))
        rows.append(CompareRow(label: "Tagged PDF", original: om.isTaggedPDF ? "Yes" : "No", comparison: cm.isTaggedPDF ? "Yes" : "No"))
        rows.append(CompareRow(label: "Conformance", original: om.pdfConformance ?? "-", comparison: cm.pdfConformance ?? "-"))

        return rows
    }

    private func buildSecurityRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let om = original.metadata
        let cm = comparison.metadata

        rows.append(CompareRow(label: "Has JavaScript", original: om.hasJavaScript ? "Yes" : "No", comparison: cm.hasJavaScript ? "Yes" : "No"))
        rows.append(CompareRow(label: "Digital Signature", original: om.hasDigitalSignature ? "Yes" : "No", comparison: cm.hasDigitalSignature ? "Yes" : "No"))
        rows.append(CompareRow(label: "Embedded Files", original: "\(om.embeddedFileCount)", comparison: "\(cm.embeddedFileCount)"))
        rows.append(CompareRow(label: "Annotations", original: "\(om.annotationCount)", comparison: "\(cm.annotationCount)"))
        rows.append(CompareRow(label: "Form Fields", original: "\(om.formFieldCount)", comparison: "\(cm.formFieldCount)"))

        return rows
    }

    private func buildFontRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let om = original.metadata
        let cm = comparison.metadata

        rows.append(CompareRow(label: "Total Fonts", original: "\(om.fontCount)", comparison: "\(cm.fontCount)"))

        // Get all unique font names
        let origFonts = Set(om.fonts.map { $0.name })
        let compFonts = Set(cm.fonts.map { $0.name })
        let allFonts = origFonts.union(compFonts).sorted()

        for fontName in allFonts {
            let origFont = om.fonts.first { $0.name == fontName }
            let compFont = cm.fonts.first { $0.name == fontName }

            let origDesc = origFont.map { formatFont($0) } ?? "-"
            let compDesc = compFont.map { formatFont($0) } ?? "-"

            rows.append(CompareRow(label: fontName, original: origDesc, comparison: compDesc))
        }

        return rows
    }

    private func formatFont(_ font: PDFAnalysis.PDFMetadata.FontInfo) -> String {
        var parts: [String] = []
        if let type = font.type { parts.append(type) }
        parts.append(font.isEmbedded ? "embedded" : "not embedded")
        if font.isSubset { parts.append("subset") }
        return parts.joined(separator: ", ")
    }

    private func buildFileSystemRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let of = original.fileInfo
        let cf = comparison.fileInfo

        rows.append(CompareRow(label: "File Name", original: of.fileName, comparison: cf.fileName))
        rows.append(CompareRow(label: "File Size", original: of.formattedSize, comparison: cf.formattedSize))
        rows.append(CompareRow(label: "Created", original: of.creationDate?.formattedForDisplay ?? "-", comparison: cf.creationDate?.formattedForDisplay ?? "-"))
        rows.append(CompareRow(label: "Modified", original: of.modificationDate?.formattedForDisplay ?? "-", comparison: cf.modificationDate?.formattedForDisplay ?? "-"))

        return rows
    }

    private func buildExtendedAttrRows() -> [CompareRow] {
        var rows: [CompareRow] = []
        let of = original.fileInfo
        let cf = comparison.fileInfo

        rows.append(CompareRow(label: "Was Quarantined", original: of.wasQuarantined ? "Yes" : "No", comparison: cf.wasQuarantined ? "Yes" : "No"))
        rows.append(CompareRow(label: "Quarantine Agent", original: of.quarantineSource ?? "-", comparison: cf.quarantineSource ?? "-"))

        let origUrls = of.downloadedFrom?.joined(separator: ", ") ?? "-"
        let compUrls = cf.downloadedFrom?.joined(separator: ", ") ?? "-"
        rows.append(CompareRow(label: "Downloaded From", original: origUrls, comparison: compUrls))

        return rows
    }
}

// MARK: - Compare Row Model
struct CompareRow: Identifiable {
    let id = UUID()
    let label: String
    let original: String
    let comparison: String

    var isDifferent: Bool {
        original != comparison
    }
}

// MARK: - Metadata Compare Section
struct MetadataCompareSection: View {
    let title: String
    let rows: [CompareRow]
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 12)

                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    // Difference count badge
                    let diffCount = rows.filter { $0.isDifferent }.count
                    if diffCount > 0 {
                        Text("\(diffCount) diff")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.border)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        CompareRowView(row: row)
                    }
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Compare Row View
struct CompareRowView: View {
    let row: CompareRow

    var body: some View {
        HStack(spacing: 0) {
            // Label
            Text(row.label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)

            // Original value
            Text(row.original)
                .font(DesignSystem.Typography.label)
                .foregroundColor(row.isDifferent ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .fontWeight(row.isDifferent ? .medium : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            // Comparison value
            Text(row.comparison)
                .font(DesignSystem.Typography.label)
                .foregroundColor(row.isDifferent ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .fontWeight(row.isDifferent ? .medium : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 4)
        .background(row.isDifferent ? DesignSystem.Colors.border.opacity(0.3) : Color.clear)
    }
}

// MARK: - Metadata Card
struct MetadataCard: View {
    let title: String
    let analysis: PDFAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                MetadataRow(label: "File Name", value: analysis.fileInfo.fileName)
                MetadataRow(label: "File Size", value: analysis.fileInfo.formattedSize)
                MetadataRow(label: "Pages", value: "\(analysis.pageCount)")

                Divider()
                    .background(DesignSystem.Colors.border)

                if let title = analysis.metadata.title {
                    MetadataRow(label: "Title", value: title)
                }
                if let author = analysis.metadata.author {
                    MetadataRow(label: "Author", value: author)
                }
                if let creator = analysis.metadata.creator {
                    MetadataRow(label: "Creator", value: creator)
                }
                if let producer = analysis.metadata.producer {
                    MetadataRow(label: "Producer", value: producer)
                }
                if let version = analysis.metadata.version {
                    MetadataRow(label: "PDF Version", value: version)
                }
                if let created = analysis.metadata.creationDate {
                    MetadataRow(label: "Created", value: created.formattedForDisplay)
                }
                if let modified = analysis.metadata.modificationDate {
                    MetadataRow(label: "Modified", value: modified.formattedForDisplay)
                }
                MetadataRow(label: "Encrypted", value: analysis.metadata.isEncrypted ? "Yes" : "No")
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Metadata Row
struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Security Tab
struct SecurityTab: View {
    let originalAnalysis: PDFAnalysis?
    let comparisonAnalysis: PDFAnalysis?
    let findings: [Finding]

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Digital Signatures
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Digital Signatures",
                        icon: "signature",
                        items: buildSignatureItems(from: comp)
                    )
                }

                // Hidden Content
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Hidden Content",
                        icon: "eye.slash",
                        items: buildHiddenContentItems(from: comp)
                    )
                }

                // Layers
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "PDF Layers (OCG)",
                        icon: "square.3.layers.3d",
                        items: buildLayerItems(from: comp)
                    )
                }

                // Links & Actions
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Links & Actions",
                        icon: "link",
                        items: buildLinkItems(from: comp)
                    )
                }

                // Redactions
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Redactions",
                        icon: "rectangle.on.rectangle.slash",
                        items: buildRedactionItems(from: comp)
                    )
                }

                // Suspicious Elements
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Suspicious Elements",
                        icon: "exclamationmark.triangle",
                        items: buildSuspiciousItems(from: comp)
                    )
                }

                // XMP Modification History
                if let comp = comparisonAnalysis {
                    SecuritySection(
                        title: "Modification History",
                        icon: "clock.arrow.circlepath",
                        items: buildHistoryItems(from: comp)
                    )
                }

                // Security-related findings
                let securityFindings = findings.filter {
                    $0.category == .security || $0.category == .signatures ||
                    $0.category == .hidden || $0.category == .forensic
                }
                if !securityFindings.isEmpty {
                    SecurityFindingsSection(findings: securityFindings)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }

    private func buildSignatureItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.signatures.isEmpty {
            return [SecurityItem(label: "No digital signatures", value: "", status: .neutral)]
        }

        return analysis.signatures.map { sig in
            let status: SecurityStatus = sig.isValid ? .good : .bad
            let value = sig.signerName ?? "Unknown signer"
            return SecurityItem(
                label: sig.coversWholeDocument ? "Full document signature" : "Partial signature",
                value: value,
                status: status
            )
        }
    }

    private func buildHiddenContentItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.hiddenContent.isEmpty {
            return [SecurityItem(label: "No hidden content detected", value: "", status: .good)]
        }

        return analysis.hiddenContent.map { hidden in
            SecurityItem(
                label: hidden.type.rawValue,
                value: "Page \(hidden.pageNumber)",
                status: .warning
            )
        }
    }

    private func buildLayerItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.layers.isEmpty {
            return [SecurityItem(label: "No layers", value: "", status: .neutral)]
        }

        return analysis.layers.map { layer in
            let status: SecurityStatus = layer.isVisible ? .neutral : .warning
            return SecurityItem(
                label: layer.name,
                value: layer.isVisible ? "Visible" : "Hidden",
                status: status
            )
        }
    }

    private func buildLinkItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.links.isEmpty {
            return [SecurityItem(label: "No links", value: "", status: .neutral)]
        }

        var items: [SecurityItem] = []
        items.append(SecurityItem(label: "Total links", value: "\(analysis.links.count)", status: .neutral))

        // Show suspicious links
        for link in analysis.links.prefix(5) {
            if let url = link.url {
                let isSuspicious = url.contains("bit.ly") || url.contains("tinyurl")
                items.append(SecurityItem(
                    label: "Page \(link.pageNumber)",
                    value: String(url.prefix(50)),
                    status: isSuspicious ? .warning : .neutral
                ))
            }
        }

        return items
    }

    private func buildRedactionItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.redactions.isEmpty {
            return [SecurityItem(label: "No redactions", value: "", status: .neutral)]
        }

        return analysis.redactions.map { redaction in
            let status: SecurityStatus = redaction.hasHiddenContent ? .bad : .good
            return SecurityItem(
                label: "Page \(redaction.pageNumber)",
                value: redaction.hasHiddenContent ? "IMPROPER - Content recoverable" : "Properly applied",
                status: status
            )
        }
    }

    private func buildSuspiciousItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.suspiciousElements.isEmpty {
            return [SecurityItem(label: "No suspicious elements", value: "", status: .good)]
        }

        return analysis.suspiciousElements.map { element in
            let status: SecurityStatus
            switch element.severity {
            case .critical: status = .bad
            case .high: status = .bad
            case .medium: status = .warning
            default: status = .neutral
            }

            return SecurityItem(
                label: element.type.rawValue,
                value: element.description,
                status: status
            )
        }
    }

    private func buildHistoryItems(from analysis: PDFAnalysis) -> [SecurityItem] {
        if analysis.xmpHistory.isEmpty {
            return [SecurityItem(label: "No modification history", value: "", status: .neutral)]
        }

        return analysis.xmpHistory.map { entry in
            SecurityItem(
                label: entry.action,
                value: entry.softwareAgent ?? "Unknown tool",
                status: .neutral
            )
        }
    }
}

// MARK: - Security Section
struct SecuritySection: View {
    let title: String
    let icon: String
    let items: [SecurityItem]
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 20)

                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        SecurityItemRow(item: items[index])
                    }
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Security Item
struct SecurityItem {
    let label: String
    let value: String
    let status: SecurityStatus
}

enum SecurityStatus {
    case good
    case warning
    case bad
    case neutral

    var color: Color {
        switch self {
        case .good: return Color.green
        case .warning: return Color.orange
        case .bad: return Color.red
        case .neutral: return DesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Security Item Row
struct SecurityItemRow: View {
    let item: SecurityItem

    var body: some View {
        HStack {
            Circle()
                .fill(item.status.color)
                .frame(width: 6, height: 6)

            Text(item.label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Text(item.value)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 4)
    }
}

// MARK: - Security Findings Section
struct SecurityFindingsSection: View {
    let findings: [Finding]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Security Findings")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.sm)

            ForEach(findings) { finding in
                FindingCard(finding: finding)
            }
        }
    }
}

// MARK: - Finding Card (for security tab)
struct FindingCard: View {
    let finding: Finding

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(finding.severity.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(severityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text(finding.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }

            Text(finding.description)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            if let page = finding.pageNumber {
                Text("Page \(page)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }

    private var severityColor: Color {
        switch finding.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .gray
        case .info: return .blue
        }
    }
}

// MARK: - Forensic Tab (External Tools)
struct ForensicTab: View {
    let externalToolsAnalysis: ExternalToolsComparisonSummary?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                if let analysis = externalToolsAnalysis {
                    // Tool availability status
                    ToolAvailabilitySection(availability: analysis.toolsAvailable)

                    // Suspicious findings summary
                    if !analysis.suspiciousFindings.isEmpty {
                        SuspiciousFindingsSection(findings: analysis.suspiciousFindings)
                    }

                    // Font comparison
                    if let fontComp = analysis.fontComparison {
                        FontComparisonSection(comparison: fontComp)
                    }

                    // Resource comparison
                    if let resourceComp = analysis.resourceComparison {
                        ResourceComparisonSection(comparison: resourceComp)
                    }

                    // Incremental updates
                    IncrementalUpdatesSection(
                        original: analysis.originalAnalysis?.pdfObjectInfo,
                        comparison: analysis.comparisonAnalysis?.pdfObjectInfo
                    )

                    // XMP Metadata
                    if let origXMP = analysis.originalAnalysis?.xmpMetadata,
                       let compXMP = analysis.comparisonAnalysis?.xmpMetadata {
                        XMPMetadataSection(original: origXMP, comparison: compXMP)
                    }

                    // Version history
                    if let origHistory = analysis.originalAnalysis?.versionHistory,
                       let compHistory = analysis.comparisonAnalysis?.versionHistory {
                        VersionHistorySection(original: origHistory, comparison: compHistory)
                    }

                    // GPS locations
                    GPSLocationSection(
                        originalLocations: analysis.originalAnalysis?.gpsLocations ?? [],
                        comparisonLocations: analysis.comparisonAnalysis?.gpsLocations ?? []
                    )

                    // Embedded documents
                    EmbeddedDocumentsSection(
                        originalDocs: analysis.originalAnalysis?.embeddedDocuments ?? [],
                        comparisonDocs: analysis.comparisonAnalysis?.embeddedDocuments ?? []
                    )
                } else {
                    // No external tools analysis available
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("External Tools Not Available")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Install mutool and exiftool for enhanced forensic analysis")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("brew install mupdf-tools exiftool")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.border.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Tool Availability Section
struct ToolAvailabilitySection: View {
    let availability: ToolAvailabilityInfo

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("External Tools Status")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.lg) {
                ToolStatusBadge(name: "mutool", isAvailable: availability.mutoolAvailable)
                ToolStatusBadge(name: "exiftool", isAvailable: availability.exiftoolAvailable)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Tool Status Badge
struct ToolStatusBadge: View {
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAvailable ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(name)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(isAvailable ? "Available" : "Not found")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Suspicious Findings Section
struct SuspiciousFindingsSection: View {
    let findings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Suspicious Findings")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            ForEach(findings, id: \.self) { finding in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(finding)
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Font Comparison Section
struct FontComparisonSection: View {
    let comparison: FontComparisonResult
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Font Analysis")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if comparison.hasDifferences {
                        Text("Differences found")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Summary
                    HStack {
                        StatMini(label: "Original", value: "\(comparison.originalFonts.count) fonts")
                        StatMini(label: "Comparison", value: "\(comparison.comparisonFonts.count) fonts")
                        StatMini(label: "Common", value: "\(comparison.commonFonts.count)")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)

                    // Added fonts
                    if !comparison.addedFonts.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Added in Comparison:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            ForEach(comparison.addedFonts, id: \.self) { font in
                                Text("+ \(font)")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                    }

                    // Removed fonts
                    if !comparison.removedFonts.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Removed from Original:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            ForEach(comparison.removedFonts, id: \.self) { font in
                                Text("- \(font)")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Resource Comparison Section
struct ResourceComparisonSection: View {
    let comparison: ResourceComparisonResult
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.richtext")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Page Resources")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if comparison.hasDifferences {
                        Text("\(comparison.pagesWithDifferentResources.count) pages differ")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded && comparison.hasDifferences {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Pages with different resources: \(comparison.pagesWithDifferentResources.map { String($0) }.joined(separator: ", "))")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Incremental Updates Section
struct IncrementalUpdatesSection: View {
    let original: PDFObjectInfo?
    let comparison: PDFObjectInfo?
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Incremental Updates")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if original?.hasIncrementalUpdates == true || comparison?.hasIncrementalUpdates == true {
                        Text("Updates detected")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    if let orig = original {
                        HStack {
                            Text("Original:")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 80, alignment: .leading)

                            if orig.hasIncrementalUpdates {
                                Text("\(orig.updateCount) updates, \(orig.freeObjects) deleted objects")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.orange)
                            } else {
                                Text("No incremental updates")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    if let comp = comparison {
                        HStack {
                            Text("Comparison:")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 80, alignment: .leading)

                            if comp.hasIncrementalUpdates {
                                Text("\(comp.updateCount) updates, \(comp.freeObjects) deleted objects")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.orange)
                            } else {
                                Text("No incremental updates")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - XMP Metadata Section
struct XMPMetadataSection: View {
    let original: XMPMetadata
    let comparison: XMPMetadata
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("XMP Metadata")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    let totalHistory = original.editHistory.count + comparison.editHistory.count
                    if totalHistory > 0 {
                        Text("\(totalHistory) history entries")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    if original.hasEditHistory {
                        Text("Original Edit History:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(original.editHistory) { entry in
                            HStack {
                                Text(entry.action)
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(entry.softwareAgent)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    if comparison.hasEditHistory {
                        Text("Comparison Edit History:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(comparison.editHistory) { entry in
                            HStack {
                                Text(entry.action)
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(entry.softwareAgent)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    if !original.hasEditHistory && !comparison.hasEditHistory {
                        Text("No edit history found in XMP metadata")
                            .font(DesignSystem.Typography.label)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Version History Section
struct VersionHistorySection: View {
    let original: PDFVersionHistory
    let comparison: PDFVersionHistory
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Version History")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if original.dateDiscrepancy || comparison.dateDiscrepancy {
                        Text("Date discrepancy")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Original
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Original:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(original.toolChain, id: \.self) { tool in
                            Text(tool)
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        if let version = original.pdfVersion {
                            Text("PDF Version: \(version)")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    // Comparison
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comparison:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(comparison.toolChain, id: \.self) { tool in
                            Text(tool)
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        if let version = comparison.pdfVersion {
                            Text("PDF Version: \(version)")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - GPS Location Section
struct GPSLocationSection: View {
    let originalLocations: [GPSLocation]
    let comparisonLocations: [GPSLocation]
    @State private var isExpanded = false

    var totalLocations: Int {
        originalLocations.count + comparisonLocations.count
    }

    var body: some View {
        if totalLocations > 0 {
            VStack(spacing: 0) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("GPS Locations")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Text("\(totalLocations) location(s)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ForEach(originalLocations) { location in
                            GPSLocationRow(location: location, source: "Original")
                        }
                        ForEach(comparisonLocations) { location in
                            GPSLocationRow(location: location, source: "Comparison")
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }
            }
            .background(DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
        }
    }
}

// MARK: - GPS Location Row
struct GPSLocationRow: View {
    let location: GPSLocation
    let source: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(location.coordinateString)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Spacer()

            if let url = location.mapsURL {
                Link(destination: url) {
                    Image(systemName: "map")
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Embedded Documents Section
struct EmbeddedDocumentsSection: View {
    let originalDocs: [EmbeddedDocument]
    let comparisonDocs: [EmbeddedDocument]
    @State private var isExpanded = false

    var totalDocs: Int {
        originalDocs.count + comparisonDocs.count
    }

    var body: some View {
        if totalDocs > 0 {
            VStack(spacing: 0) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Embedded Documents")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Text("\(totalDocs) document(s)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        if !originalDocs.isEmpty {
                            Text("In Original:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            ForEach(originalDocs) { doc in
                                EmbeddedDocumentRow(document: doc)
                            }
                        }

                        if !comparisonDocs.isEmpty {
                            Text("In Comparison:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            ForEach(comparisonDocs) { doc in
                                EmbeddedDocumentRow(document: doc)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }
            }
            .background(DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
        }
    }
}

// MARK: - Embedded Document Row
struct EmbeddedDocumentRow: View {
    let document: EmbeddedDocument

    var body: some View {
        HStack {
            Image(systemName: iconForMimeType(document.mimeType))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(document.filename)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Text(document.sizeFormatted)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private func iconForMimeType(_ mimeType: String) -> String {
        if mimeType.contains("image") { return "photo" }
        if mimeType.contains("pdf") { return "doc.fill" }
        if mimeType.contains("word") { return "doc.text.fill" }
        if mimeType.contains("excel") || mimeType.contains("spreadsheet") { return "tablecells" }
        if mimeType.contains("text") { return "doc.plaintext" }
        return "doc"
    }
}

// MARK: - Stat Mini
struct StatMini: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

