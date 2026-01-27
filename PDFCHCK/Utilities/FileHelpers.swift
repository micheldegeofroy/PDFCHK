import Foundation
import CryptoKit

// MARK: - File Helpers
enum FileHelpers {

    // MARK: - File Info Extraction
    static func getFileInfo(for url: URL) throws -> PDFAnalysis.FileInfo {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date
        let modificationDate = attributes[.modificationDate] as? Date
        let contentModDate = modificationDate

        // Extract extended attributes
        let extAttrs = getExtendedAttributes(for: url)
        let quarantineInfo = parseQuarantineAttribute(for: url)
        let downloadedFrom = getWhereFromAttribute(for: url)

        return PDFAnalysis.FileInfo(
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            creationDate: creationDate,
            modificationDate: modificationDate,
            contentModificationDate: contentModDate,
            filePath: url.path,
            wasQuarantined: quarantineInfo.wasQuarantined,
            quarantineSource: quarantineInfo.source,
            downloadedFrom: downloadedFrom,
            extendedAttributes: extAttrs
        )
    }

    // MARK: - Extended Attributes
    static func getExtendedAttributes(for url: URL) -> [String: String] {
        var result: [String: String] = [:]
        let path = url.path

        // List all extended attribute names
        let bufferSize = listxattr(path, nil, 0, 0)
        guard bufferSize > 0 else { return result }

        var nameBuffer = [CChar](repeating: 0, count: bufferSize)
        let actualSize = listxattr(path, &nameBuffer, bufferSize, 0)
        guard actualSize > 0 else { return result }

        // Parse attribute names (null-separated)
        var attrNames: [String] = []
        var current = ""
        for char in nameBuffer.prefix(actualSize) {
            if char == 0 {
                if !current.isEmpty {
                    attrNames.append(current)
                    current = ""
                }
            } else {
                current.append(Character(UnicodeScalar(UInt8(bitPattern: char))))
            }
        }

        // Get value for each attribute (limit to safe displayable ones)
        for name in attrNames {
            // Skip binary/large attributes, just note their presence
            let valueSize = getxattr(path, name, nil, 0, 0, 0)
            if valueSize > 0 && valueSize < 4096 {
                var valueBuffer = [UInt8](repeating: 0, count: valueSize)
                let read = getxattr(path, name, &valueBuffer, valueSize, 0, 0)
                if read > 0 {
                    if let stringValue = String(bytes: valueBuffer.prefix(read), encoding: .utf8) {
                        result[name] = stringValue.trimmingCharacters(in: .controlCharacters)
                    } else {
                        result[name] = "<binary data: \(read) bytes>"
                    }
                }
            } else if valueSize > 0 {
                result[name] = "<large data: \(valueSize) bytes>"
            }
        }

        return result
    }

    // MARK: - Quarantine Attribute
    static func parseQuarantineAttribute(for url: URL) -> (wasQuarantined: Bool, source: String?) {
        let path = url.path
        let attrName = "com.apple.quarantine"

        let valueSize = getxattr(path, attrName, nil, 0, 0, 0)
        guard valueSize > 0 else { return (false, nil) }

        var valueBuffer = [UInt8](repeating: 0, count: valueSize)
        let read = getxattr(path, attrName, &valueBuffer, valueSize, 0, 0)
        guard read > 0 else { return (false, nil) }

        if let quarantineString = String(bytes: valueBuffer.prefix(read), encoding: .utf8) {
            // Quarantine format: flags;timestamp;agent;uuid
            let components = quarantineString.components(separatedBy: ";")
            let agent = components.count > 2 ? components[2] : nil
            return (true, agent)
        }

        return (true, nil)
    }

    // MARK: - Where From Attribute (Download Source)
    static func getWhereFromAttribute(for url: URL) -> [String]? {
        let path = url.path
        let attrName = "com.apple.metadata:kMDItemWhereFroms"

        let valueSize = getxattr(path, attrName, nil, 0, 0, 0)
        guard valueSize > 0 else { return nil }

        var valueBuffer = [UInt8](repeating: 0, count: valueSize)
        let read = getxattr(path, attrName, &valueBuffer, valueSize, 0, 0)
        guard read > 0 else { return nil }

        // This is a binary plist, try to decode it
        let data = Data(valueBuffer.prefix(read))
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let urls = plist as? [String] {
            return urls
        }

        return nil
    }

    // MARK: - Checksum Calculation
    static func calculateSHA256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - File Validation
    static func isPDF(at url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func isReadable(at url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    // MARK: - Temporary Files
    static func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFCHCK-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    static func cleanupTemporaryDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Date Formatting
extension Date {
    var formattedForDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - URL Extension
extension URL {
    var isPDF: Bool {
        pathExtension.lowercased() == "pdf"
    }

    var fileSize: Int64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int64
    }
}
