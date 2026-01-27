import Foundation

// MARK: - External Tools Service
/// Service for detecting and calling external tools (mutool, exiftool)
actor ExternalToolsService {

    // MARK: - Tool Availability
    struct ToolAvailability {
        var mutoolAvailable: Bool = false
        var mutoolPath: String?
        var exiftoolAvailable: Bool = false
        var exiftoolPath: String?

        var anyToolAvailable: Bool {
            mutoolAvailable || exiftoolAvailable
        }

        var missingToolsMessage: String? {
            var missing: [String] = []
            if !mutoolAvailable { missing.append("mutool (from mupdf)") }
            if !exiftoolAvailable { missing.append("exiftool") }

            if missing.isEmpty { return nil }

            return "Install \(missing.joined(separator: " and ")) for enhanced forensic analysis. Use: brew install \(missing.map { $0.contains("mutool") ? "mupdf-tools" : "exiftool" }.joined(separator: " "))"
        }
    }

    // MARK: - Properties
    private var toolAvailability: ToolAvailability?

    // MARK: - Check Tool Availability
    func checkToolAvailability() async -> ToolAvailability {
        if let cached = toolAvailability {
            return cached
        }

        var availability = ToolAvailability()

        // Check mutool
        if let path = findTool("mutool") {
            availability.mutoolAvailable = true
            availability.mutoolPath = path
        }

        // Check exiftool
        if let path = findTool("exiftool") {
            availability.exiftoolAvailable = true
            availability.exiftoolPath = path
        }

        toolAvailability = availability
        return availability
    }

    private func findTool(_ name: String) -> String? {
        let commonPaths = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)",
            "/opt/local/bin/\(name)"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try which command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Tool not found
        }

        return nil
    }

    // MARK: - Run External Command
    private func runCommand(executable: String, arguments: [String], timeout: TimeInterval = 30) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                // Set timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: ExternalToolError.commandFailed(errorOutput))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Mutool Operations

    /// Extract embedded fonts information
    func extractFonts(from pdfPath: String) async throws -> [EmbeddedFont] {
        let availability = await checkToolAvailability()
        guard let mutoolPath = availability.mutoolPath else {
            throw ExternalToolError.toolNotAvailable("mutool")
        }

        // mutool info -F shows fonts
        let output = try await runCommand(executable: mutoolPath, arguments: ["info", "-F", pdfPath])
        return parseFontsOutput(output)
    }

    /// Get page resources (fonts, images, shadings per page)
    func getPageResources(from pdfPath: String) async throws -> [PageResources] {
        let availability = await checkToolAvailability()
        guard let mutoolPath = availability.mutoolPath else {
            throw ExternalToolError.toolNotAvailable("mutool")
        }

        // mutool info shows all resources
        let output = try await runCommand(executable: mutoolPath, arguments: ["info", pdfPath])
        return parsePageResourcesOutput(output)
    }

    /// Extract embedded images
    func extractImages(from pdfPath: String, to outputDir: String) async throws -> [ExtractedImage] {
        let availability = await checkToolAvailability()
        guard let mutoolPath = availability.mutoolPath else {
            throw ExternalToolError.toolNotAvailable("mutool")
        }

        // Create output directory
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // mutool extract extracts images and fonts
        let output = try await runCommand(executable: mutoolPath, arguments: ["extract", "-o", outputDir, pdfPath])
        return parseExtractedImages(output, outputDir: outputDir)
    }

    /// Show PDF objects for incremental update detection
    func showPDFObjects(from pdfPath: String) async throws -> PDFObjectInfo {
        let availability = await checkToolAvailability()
        guard let mutoolPath = availability.mutoolPath else {
            throw ExternalToolError.toolNotAvailable("mutool")
        }

        // mutool show trailer shows xref and trailer
        let trailerOutput = try await runCommand(executable: mutoolPath, arguments: ["show", pdfPath, "trailer"])
        let xrefOutput = try await runCommand(executable: mutoolPath, arguments: ["show", pdfPath, "xref"])

        return parsePDFObjects(trailer: trailerOutput, xref: xrefOutput)
    }

    /// Inspect stream content
    func inspectStream(from pdfPath: String, objectNumber: Int) async throws -> StreamContent {
        let availability = await checkToolAvailability()
        guard let mutoolPath = availability.mutoolPath else {
            throw ExternalToolError.toolNotAvailable("mutool")
        }

        // mutool show -b shows raw stream, -e shows decoded
        let rawOutput = try await runCommand(executable: mutoolPath, arguments: ["show", "-b", pdfPath, "\(objectNumber)"])
        let decodedOutput = try await runCommand(executable: mutoolPath, arguments: ["show", "-e", pdfPath, "\(objectNumber)"])

        return StreamContent(
            objectNumber: objectNumber,
            rawContent: rawOutput,
            decodedContent: decodedOutput,
            isCompressed: rawOutput != decodedOutput
        )
    }

    // MARK: - Exiftool Operations

    /// Extract full XMP metadata
    func extractXMPMetadata(from pdfPath: String) async throws -> XMPMetadata {
        let availability = await checkToolAvailability()
        guard let exiftoolPath = availability.exiftoolPath else {
            throw ExternalToolError.toolNotAvailable("exiftool")
        }

        // Get XMP data in JSON format
        let output = try await runCommand(executable: exiftoolPath, arguments: ["-json", "-XMP:all", "-G1", pdfPath])
        return parseXMPMetadata(output)
    }

    /// Extract PDF version history (incremental saves)
    func extractVersionHistory(from pdfPath: String) async throws -> PDFVersionHistory {
        let availability = await checkToolAvailability()
        guard let exiftoolPath = availability.exiftoolPath else {
            throw ExternalToolError.toolNotAvailable("exiftool")
        }

        // Get all metadata including history
        let output = try await runCommand(executable: exiftoolPath, arguments: ["-json", "-all", "-G1", pdfPath])
        return parseVersionHistory(output)
    }

    /// Extract embedded documents/attachments
    func extractEmbeddedDocuments(from pdfPath: String, to outputDir: String) async throws -> [EmbeddedDocument] {
        let availability = await checkToolAvailability()
        guard let exiftoolPath = availability.exiftoolPath else {
            throw ExternalToolError.toolNotAvailable("exiftool")
        }

        // Create output directory
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // Extract embedded files
        let output = try await runCommand(executable: exiftoolPath, arguments: ["-b", "-EmbeddedFile", "-W", "\(outputDir)/%f_%t.%s", pdfPath])
        return parseEmbeddedDocuments(output, outputDir: outputDir)
    }

    /// Extract GPS/location data from embedded images
    func extractGPSData(from pdfPath: String) async throws -> [GPSLocation] {
        let availability = await checkToolAvailability()
        guard let exiftoolPath = availability.exiftoolPath else {
            throw ExternalToolError.toolNotAvailable("exiftool")
        }

        // Extract GPS data
        let output = try await runCommand(executable: exiftoolPath, arguments: ["-json", "-GPS:all", "-ee", pdfPath])
        return parseGPSData(output)
    }

    /// Get comprehensive forensic metadata
    func getForensicMetadata(from pdfPath: String) async throws -> ForensicMetadata {
        let availability = await checkToolAvailability()
        guard let exiftoolPath = availability.exiftoolPath else {
            throw ExternalToolError.toolNotAvailable("exiftool")
        }

        // Get all metadata in JSON format with groups
        let output = try await runCommand(executable: exiftoolPath, arguments: ["-json", "-all", "-G1", "-struct", pdfPath])
        return parseForensicMetadata(output)
    }

    // MARK: - Parsing Functions

    private func parseFontsOutput(_ output: String) -> [EmbeddedFont] {
        var fonts: [EmbeddedFont] = []
        let lines = output.components(separatedBy: .newlines)

        var currentPage = 0
        for line in lines {
            if line.contains("Page") {
                if let pageNum = line.components(separatedBy: " ").last.flatMap({ Int($0) }) {
                    currentPage = pageNum
                }
            } else if line.contains("Font") || line.contains("Type") {
                // Parse font info: typically "Name: FontName Type: TrueType Encoding: WinAnsiEncoding"
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let font = EmbeddedFont(
                        name: extractValue(from: trimmed, key: "Name") ?? "Unknown",
                        type: extractValue(from: trimmed, key: "Type") ?? "Unknown",
                        encoding: extractValue(from: trimmed, key: "Encoding"),
                        embedded: line.contains("embedded") || line.contains("Embedded"),
                        subset: line.contains("subset") || line.contains("Subset"),
                        pageNumber: currentPage
                    )
                    fonts.append(font)
                }
            }
        }

        return fonts
    }

    private func parsePageResourcesOutput(_ output: String) -> [PageResources] {
        var pageResources: [PageResources] = []
        let lines = output.components(separatedBy: .newlines)

        var currentPage = 0
        var fonts: [String] = []
        var images: [String] = []
        var shadings: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Page ") {
                // Save previous page if exists
                if currentPage > 0 {
                    pageResources.append(PageResources(
                        pageNumber: currentPage,
                        fonts: fonts,
                        images: images,
                        shadings: shadings
                    ))
                }

                // Start new page
                if let pageNum = trimmed.replacingOccurrences(of: "Page ", with: "").components(separatedBy: ":").first.flatMap({ Int($0) }) {
                    currentPage = pageNum
                }
                fonts = []
                images = []
                shadings = []
            } else if trimmed.contains("Font") {
                fonts.append(trimmed)
            } else if trimmed.contains("Image") || trimmed.contains("XObject") {
                images.append(trimmed)
            } else if trimmed.contains("Shading") {
                shadings.append(trimmed)
            }
        }

        // Add last page
        if currentPage > 0 {
            pageResources.append(PageResources(
                pageNumber: currentPage,
                fonts: fonts,
                images: images,
                shadings: shadings
            ))
        }

        return pageResources
    }

    private func parseExtractedImages(_ output: String, outputDir: String) -> [ExtractedImage] {
        var images: [ExtractedImage] = []

        // List files in output directory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: outputDir) {
            for file in files {
                let path = (outputDir as NSString).appendingPathComponent(file)
                let attributes = try? FileManager.default.attributesOfItem(atPath: path)

                images.append(ExtractedImage(
                    filename: file,
                    path: path,
                    size: attributes?[.size] as? Int64 ?? 0,
                    format: (file as NSString).pathExtension
                ))
            }
        }

        return images
    }

    private func parsePDFObjects(trailer: String, xref: String) -> PDFObjectInfo {
        var info = PDFObjectInfo()

        // Parse trailer for incremental update info
        let trailerLines = trailer.components(separatedBy: .newlines)
        for line in trailerLines {
            if line.contains("/Prev") {
                info.hasIncrementalUpdates = true
                if let offset = extractNumber(from: line) {
                    info.previousXRefOffsets.append(offset)
                }
            }
            if line.contains("/Size") {
                if let size = extractNumber(from: line) {
                    info.objectCount = size
                }
            }
        }

        // Parse xref for object info
        let xrefLines = xref.components(separatedBy: .newlines)
        for line in xrefLines {
            if line.contains(" n") {
                // Object in use
                info.activeObjects += 1
            } else if line.contains(" f") {
                // Free object (deleted)
                info.freeObjects += 1
            }
        }

        return info
    }

    private func parseXMPMetadata(_ output: String) -> XMPMetadata {
        var metadata = XMPMetadata()

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else {
            return metadata
        }

        for (key, value) in first {
            if key.hasPrefix("XMP-") {
                let namespace = String(key.dropFirst(4).prefix(while: { $0 != ":" }))
                let property = String(key.drop(while: { $0 != ":" }).dropFirst())

                if metadata.namespaces[namespace] == nil {
                    metadata.namespaces[namespace] = [:]
                }
                metadata.namespaces[namespace]?[property] = "\(value)"
            }
        }

        // Extract edit history if available
        if let history = first["XMP-xmpMM:History"] as? [[String: Any]] {
            for entry in history {
                let historyEntry = XMPHistoryEntry(
                    action: entry["Action"] as? String ?? "",
                    when: entry["When"] as? String ?? "",
                    softwareAgent: entry["SoftwareAgent"] as? String ?? "",
                    instanceID: entry["InstanceID"] as? String
                )
                metadata.editHistory.append(historyEntry)
            }
        }

        return metadata
    }

    private func parseVersionHistory(_ output: String) -> PDFVersionHistory {
        var history = PDFVersionHistory()

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else {
            return history
        }

        // Extract creation/modification dates
        if let createDate = first["PDF:CreateDate"] as? String ?? first["XMP-xmp:CreateDate"] as? String {
            history.createDate = createDate
        }
        if let modifyDate = first["PDF:ModifyDate"] as? String ?? first["XMP-xmp:ModifyDate"] as? String {
            history.modifyDate = modifyDate
        }
        if let metadataDate = first["XMP-xmp:MetadataDate"] as? String {
            history.metadataDate = metadataDate
        }

        // Producer/Creator history
        if let producer = first["PDF:Producer"] as? String {
            history.producer = producer
        }
        if let creator = first["PDF:Creator"] as? String {
            history.creator = creator
        }

        // PDF version
        if let version = first["PDF:PDFVersion"] as? String {
            history.pdfVersion = version
        }

        // Incremental save indicator
        if let linearized = first["PDF:Linearized"] as? String {
            history.isLinearized = linearized.lowercased() == "yes" || linearized.lowercased() == "true"
        }

        return history
    }

    private func parseEmbeddedDocuments(_ output: String, outputDir: String) -> [EmbeddedDocument] {
        var documents: [EmbeddedDocument] = []

        // List extracted files
        if let files = try? FileManager.default.contentsOfDirectory(atPath: outputDir) {
            for file in files {
                let path = (outputDir as NSString).appendingPathComponent(file)
                let attributes = try? FileManager.default.attributesOfItem(atPath: path)

                documents.append(EmbeddedDocument(
                    filename: file,
                    path: path,
                    size: attributes?[.size] as? Int64 ?? 0,
                    mimeType: guessMimeType(for: file)
                ))
            }
        }

        return documents
    }

    private func parseGPSData(_ output: String) -> [GPSLocation] {
        var locations: [GPSLocation] = []

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return locations
        }

        for item in json {
            if let lat = item["GPS:GPSLatitude"] as? Double,
               let lon = item["GPS:GPSLongitude"] as? Double {
                let location = GPSLocation(
                    latitude: lat,
                    longitude: lon,
                    altitude: item["GPS:GPSAltitude"] as? Double,
                    timestamp: item["GPS:GPSDateTime"] as? String,
                    source: item["SourceFile"] as? String ?? "Unknown"
                )
                locations.append(location)
            }
        }

        return locations
    }

    private func parseForensicMetadata(_ output: String) -> ForensicMetadata {
        var metadata = ForensicMetadata()

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else {
            return metadata
        }

        // Organize by group
        for (key, value) in first {
            let parts = key.components(separatedBy: ":")
            let group = parts.first ?? "Other"
            let property = parts.count > 1 ? parts[1] : key

            if metadata.groups[group] == nil {
                metadata.groups[group] = [:]
            }
            metadata.groups[group]?[property] = "\(value)"
        }

        return metadata
    }

    // MARK: - Helper Functions

    private func extractValue(from string: String, key: String) -> String? {
        guard let range = string.range(of: "\(key):") ?? string.range(of: "\(key) :") else {
            return nil
        }

        let afterKey = string[range.upperBound...]
        let value = afterKey.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
            .first

        return value?.isEmpty == true ? nil : value
    }

    private func extractNumber(from string: String) -> Int? {
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers)
    }

    private func guessMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "txt": return "text/plain"
        case "xml": return "application/xml"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Error Types
enum ExternalToolError: Error, LocalizedError {
    case toolNotAvailable(String)
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .toolNotAvailable(let tool):
            return "\(tool) is not installed or not found in PATH"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse output: \(message)"
        }
    }
}
