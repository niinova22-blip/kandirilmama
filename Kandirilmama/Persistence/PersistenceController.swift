import Foundation
import SwiftData

enum PersistenceController {
    /// Tamamen yerel SwiftData deposu.
    /// - `cloudKitDatabase: .none` → iCloud/CloudKit senkronizasyonu kapalı.
    /// - Klasör iCloud/iTunes yedeklerinden hariç tutulur; transkriptler cihazdan hiç çıkmaz.
    static func makeContainer() throws -> ModelContainer {
        do {
            return try openContainer()
        } catch {
            // Depo bozulmuşsa her açılışta çökmek yerine yerel kayıtları sıfırla.
            if let directory = try? storeDirectory() {
                try? FileManager.default.removeItem(at: directory)
            }
            return try openContainer()
        }
    }

    private static func openContainer() throws -> ModelContainer {
        let directory = try storeDirectory()
        let configuration = ModelConfiguration(
            "Kandirilmama",
            schema: Schema([ConversationRecord.self]),
            url: directory.appendingPathComponent("Kandirilmama.store"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: ConversationRecord.self, configurations: configuration)
    }

    private static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var directory = base.appendingPathComponent("LocalStore", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }
}
