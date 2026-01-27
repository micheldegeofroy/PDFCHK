import SwiftUI

// MARK: - Findings Section
struct FindingsSection: View {
    let findings: [Finding]
    @State private var selectedCategory: FindingCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header
            Text("Findings")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    CategoryPill(
                        title: "All",
                        count: findings.count,
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(FindingCategory.allCases, id: \.self) { category in
                        let count = findings.filter { $0.category == category }.count
                        if count > 0 {
                            CategoryPill(
                                title: category.rawValue,
                                count: count,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                }
            }

            // Findings list
            if filteredFindings.isEmpty {
                Text("No findings")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DesignSystem.Spacing.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(filteredFindings) { finding in
                            FindingRow(finding: finding)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    private var filteredFindings: [Finding] {
        if let category = selectedCategory {
            return findings.filter { $0.category == category }
        }
        return findings
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.caption)

                Text("\(count)")
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.2) : DesignSystem.Colors.border)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Finding Row
struct FindingRow: View {
    let finding: Finding
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                SeverityBadge(severity: finding.severity)

                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(finding.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer()

                if finding.details != nil || finding.pageNumber != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    if let page = finding.pageNumber {
                        DetailRow(label: "Page", value: "\(page)")
                    }

                    if let details = finding.details {
                        ForEach(Array(details.keys.sorted()), id: \.self) { key in
                            if let value = details[key] {
                                DetailRow(label: key, value: value)
                            }
                        }
                    }
                }
                .padding(.leading, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xxs)
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

// MARK: - Severity Badge
struct SeverityBadge: View {
    let severity: Severity

    var body: some View {
        Text(severity.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(label + ":")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(value)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

