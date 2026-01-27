import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop Zone View
struct DropZoneView: View {
    let label: String
    let fileName: String?
    let onTap: () -> Void
    let onFileDrop: (URL) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: fileName != nil ? "doc.fill" : "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(fileName != nil ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

            Text(label)
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let name = fileName {
                Text(name)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Drop PDF or click to select")
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .strokeBorder(
                    isTargeted ? DesignSystem.Colors.accent : DesignSystem.Colors.border,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
        .onTapGesture(perform: onTap)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       url.pathExtension.lowercased() == "pdf" {
                        DispatchQueue.main.async {
                            onFileDrop(url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - File Card View
struct FileCardView: View {
    let label: String
    let fileName: String?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(fileName ?? "No file selected")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if fileName != nil {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
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
