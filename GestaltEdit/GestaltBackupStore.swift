import Foundation

struct GestaltBackup: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let byteCount: Int64

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum GestaltBackupStore {
    static func create(from data: Data) throws -> GestaltBackup {
        let directory = try backupDirectory()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let url = directory
            .appendingPathComponent("MobileGestalt_\(formatter.string(from: Date()))_\(UUID().uuidString)")
            .appendingPathExtension("plist")
        let stagingURL = url.appendingPathExtension("partial")
        // Only publish a complete, verified file; moveItem refuses an existing destination.
        defer { try? FileManager.default.removeItem(at: stagingURL) }
        try data.write(to: stagingURL, options: [.atomic, .completeFileProtection])
        guard try Data(contentsOf: stagingURL) == data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.moveItem(at: stagingURL, to: url)
        return try metadata(for: url)
    }

    static func list() throws -> [GestaltBackup] {
        let directory = try backupDirectory()
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "plist" }
        .map { try metadata(for: $0) }
        .sorted { $0.createdAt > $1.createdAt }
    }

    static func data(for backup: GestaltBackup) throws -> Data {
        try Data(contentsOf: backup.url)
    }

    static func delete(_ backup: GestaltBackup) throws {
        try FileManager.default.removeItem(at: backup.url)
    }

    private static func backupDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var directory = documents.appendingPathComponent("MobileGestalt Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if GestaltAccess.isReadOnlyProbeBuild() {
            // Diagnostic copies are sensitive and are not an entire-device backup.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        }
        return directory
    }

    private static func metadata(for url: URL) throws -> GestaltBackup {
        let values = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        return GestaltBackup(
            url: url,
            createdAt: values.creationDate ?? .distantPast,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }
}
