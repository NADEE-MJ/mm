import Foundation
import GRDB

// MARK: - SQLite Database Manager (GRDB)
// Type-safe wrapper using GRDB.swift over SQLite.
// Stores bookmarked repos locally for offline access.

@MainActor
@Observable
final class DatabaseManager {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue
    private(set) var bookmarks: [Bookmark] = []

    // MARK: - Record

    struct Bookmark: Identifiable, Hashable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "bookmarks"

        let id: String
        let name: String
        let owner: String
        let language: String
        let stars: Int
        let bookmarkedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, owner, language, stars
            case bookmarkedAt = "created_at"
        }
    }

    // MARK: - Lifecycle

    private init() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app.sqlite3")

        do {
            dbQueue = try DatabaseQueue(path: fileURL.path)
            try migrate()
            loadBookmarks()
            print("[GRDB] Database opened at \(fileURL.path)")
        } catch {
            fatalError("[GRDB] Failed to open database: \(error)")
        }
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_bookmarks") { db in
            try db.create(table: "bookmarks", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("owner", .text).notNull()
                t.column("language", .text).notNull().defaults(to: "")
                t.column("stars", .integer).notNull().defaults(to: 0)
                t.column("created_at", .double).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - CRUD

    func addBookmark(id: String, name: String, owner: String, language: String, stars: Int) {
        let bookmark = Bookmark(
            id: id, name: name, owner: owner,
            language: language, stars: stars,
            bookmarkedAt: .now
        )
        do {
            try dbQueue.write { db in
                try bookmark.save(db)
            }
            loadBookmarks()
        } catch {
            print("[GRDB] Insert error: \(error)")
        }
    }

    func removeBookmark(id: String) {
        do {
            try dbQueue.write { db in
                _ = try Bookmark.deleteOne(db, key: id)
            }
            loadBookmarks()
        } catch {
            print("[GRDB] Delete error: \(error)")
        }
    }

    func clearAll() {
        do {
            try dbQueue.write { db in
                _ = try Bookmark.deleteAll(db)
            }
            loadBookmarks()
        } catch {
            print("[GRDB] Clear error: \(error)")
        }
    }

    func loadBookmarks() {
        do {
            bookmarks = try dbQueue.read { db in
                try Bookmark
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            }
        } catch {
            print("[GRDB] Fetch error: \(error)")
        }
    }

    var bookmarkCount: Int { bookmarks.count }
}
