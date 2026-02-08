import Foundation
import GRDB

// MARK: - SQLite Database Manager (GRDB)
// Type-safe wrapper using GRDB.swift over SQLite.
// Stores movies and people locally for offline access.

@MainActor
@Observable
final class DatabaseManager {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue
    private(set) var cachedMovies: [CachedMovie] = []
    private(set) var cachedPeople: [CachedPerson] = []

    // MARK: - Records

    struct CachedMovie: Identifiable, Hashable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "movies"

        let id: Int
        let tmdbId: Int
        let title: String
        let posterPath: String?
        let status: String
        let myRating: Int?
        let dateWatched: String?
        let cachedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, tmdbId = "tmdb_id", title, posterPath = "poster_path"
            case status, myRating = "my_rating", dateWatched = "date_watched"
            case cachedAt = "cached_at"
        }
    }
    
    struct CachedPerson: Identifiable, Hashable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "people"
        
        let name: String
        let isTrusted: Bool
        let movieCount: Int
        let cachedAt: Date
        
        var id: String { name }
        
        enum CodingKeys: String, CodingKey {
            case name, isTrusted = "is_trusted", movieCount = "movie_count"
            case cachedAt = "cached_at"
        }
    }

    // MARK: - Lifecycle

    private init() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("moviemanager.sqlite3")

        do {
            dbQueue = try DatabaseQueue(path: fileURL.path)
            try migrate()
            loadCache()
            logDebug("[GRDB] Database opened at \(fileURL.path)")
        } catch {
            fatalError("[GRDB] Failed to open database: \(error)")
        }
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_movies") { db in
            try db.create(table: "movies", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey()
                t.column("tmdb_id", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("poster_path", .text)
                t.column("status", .text).notNull()
                t.column("my_rating", .integer)
                t.column("date_watched", .text)
                t.column("cached_at", .double).notNull()
            }
        }
        
        migrator.registerMigration("v1_people") { db in
            try db.create(table: "people", ifNotExists: true) { t in
                t.column("name", .text).primaryKey()
                t.column("is_trusted", .boolean).notNull()
                t.column("movie_count", .integer).notNull()
                t.column("cached_at", .double).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - CRUD

    func cacheMovie(id: Int, tmdbId: Int, title: String, posterPath: String?, 
                    status: String, myRating: Int?, dateWatched: String?) {
        let movie = CachedMovie(
            id: id, tmdbId: tmdbId, title: title, posterPath: posterPath,
            status: status, myRating: myRating, dateWatched: dateWatched,
            cachedAt: .now
        )
        do {
            try dbQueue.write { db in
                try movie.save(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Insert error: \(error)")
        }
    }
    
    func cachePerson(name: String, isTrusted: Bool, movieCount: Int) {
        let person = CachedPerson(
            name: name, isTrusted: isTrusted, movieCount: movieCount,
            cachedAt: .now
        )
        do {
            try dbQueue.write { db in
                try person.save(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Insert error: \(error)")
        }
    }

    func clearAll() {
        do {
            try dbQueue.write { db in
                _ = try CachedMovie.deleteAll(db)
                _ = try CachedPerson.deleteAll(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Clear error: \(error)")
        }
    }

    func loadCache() {
        do {
            cachedMovies = try dbQueue.read { db in
                try CachedMovie
                    .order(Column("cached_at").desc)
                    .fetchAll(db)
            }
            cachedPeople = try dbQueue.read { db in
                try CachedPerson
                    .order(Column("name"))
                    .fetchAll(db)
            }
        } catch {
            logDebug("[GRDB] Fetch error: \(error)")
        }
    }

    var movieCount: Int { cachedMovies.count }
    var peopleCount: Int { cachedPeople.count }

    private func logDebug(_ message: @autoclosure () -> String) {
        let value = message()
        if value.localizedCaseInsensitiveContains("error") {
            AppLog.error(value, category: .database)
        } else {
            AppLog.debug(value, category: .database)
        }
    }
}
