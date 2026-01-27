import SwiftUI

// MARK: - Metadata Tree View
struct MetadataTreeView: View {
    let originalTree: MetadataTreeNode?
    let comparisonTree: MetadataTreeNode?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Metadata")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if let original = originalTree {
                        MetadataSection(title: "Original", node: original)
                    }

                    if let comparison = comparisonTree {
                        MetadataSection(title: "Comparison", node: comparison)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Metadata Section
struct MetadataSection: View {
    let title: String
    let node: MetadataTreeNode
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Section header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 12)

                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children) { child in
                        MetadataNodeView(node: child, level: 0)
                    }
                }
                .padding(.leading, DesignSystem.Spacing.md)
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

// MARK: - Metadata Node View
struct MetadataNodeView: View {
    let node: MetadataTreeNode
    let level: Int
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Expand/collapse for non-leaf nodes
                if !node.isLeaf {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 10)
                }

                // Name
                Text(node.name)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(node.isLeaf ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)

                // Value (for leaf nodes)
                if let value = node.value {
                    Text(":")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(value)
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.leading, CGFloat(level) * DesignSystem.Spacing.md)

            // Children
            if isExpanded && !node.isLeaf {
                ForEach(node.children) { child in
                    MetadataNodeView(node: child, level: level + 1)
                }
            }
        }
    }
}

// MARK: - Metadata Comparison View
struct MetadataComparisonView: View {
    let differences: [MetadataDifference]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Differences")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if differences.isEmpty {
                Text("No metadata differences found")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DesignSystem.Spacing.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(differences) { diff in
                            MetadataDiffRow(difference: diff)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Metadata Diff Row
struct MetadataDiffRow: View {
    let difference: MetadataDifference

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text(difference.field)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if difference.isSignificant {
                    Text("Significant")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.border)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(difference.originalValue ?? "(none)")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Comparison")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(difference.comparisonValue ?? "(none)")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
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

