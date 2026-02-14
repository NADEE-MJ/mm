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
        let imdbId: String
        let title: String
        let posterPath: String?
        let mediaType: String
        let status: String
        let myRating: Int?
        let dateWatched: String?
        let cachedAt: Date
        let jsonData: String

        enum CodingKeys: String, CodingKey {
            case id, tmdbId = "tmdb_id", imdbId = "imdb_id", title, posterPath = "poster_path"
            case mediaType = "media_type"
            case status, myRating = "my_rating", dateWatched = "date_watched"
            case cachedAt = "cached_at", jsonData = "json_data"
        }

        func toMovie() -> Movie? {
            guard let data = jsonData.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(MovieSnapshot.self, from: data)
            else {
                return Movie(
                    id: id,
                    imdbId: imdbId,
                    tmdbId: tmdbId,
                    title: title,
                    posterPath: posterPath,
                    overview: nil,
                    releaseDate: nil,
                    voteAverage: nil,
                    imdbRating: nil,
                    rottenTomatoesRating: nil,
                    metacriticScore: nil,
                    status: status,
                    myRating: myRating,
                    dateWatched: dateWatched,
                    mediaType: mediaType,
                    recommendations: []
                )
            }

            return snapshot.toMovie()
        }

        static func from(_ movie: Movie) -> CachedMovie {
            let snapshot = MovieSnapshot(movie: movie)
            let jsonData: String
            if let encoded = try? JSONEncoder().encode(snapshot), let text = String(data: encoded, encoding: .utf8) {
                jsonData = text
            } else {
                jsonData = "{}"
            }

            return CachedMovie(
                id: movie.id,
                tmdbId: movie.tmdbId ?? movie.id,
                imdbId: movie.imdbId,
                title: movie.title,
                posterPath: movie.posterPath,
                mediaType: movie.mediaType,
                status: movie.status,
                myRating: movie.myRating,
                dateWatched: movie.dateWatched,
                cachedAt: .now,
                jsonData: jsonData
            )
        }

        private struct MovieSnapshot: Codable {
            let id: Int
            let imdbId: String
            let tmdbId: Int?
            let title: String
            let posterPath: String?
            let overview: String?
            let releaseDate: String?
            let voteAverage: Double?
            let imdbRating: Double?
            let rottenTomatoesRating: Int?
            let metacriticScore: Int?
            let genres: [String]
            let director: String?
            let actors: [String]?
            let status: String
            let myRating: Int?
            let dateWatched: String?
            let mediaType: String
            let recommendations: [RecommendationSnapshot]

            init(movie: Movie) {
                id = movie.id
                imdbId = movie.imdbId
                tmdbId = movie.tmdbId
                title = movie.title
                posterPath = movie.posterPath
                overview = movie.overview
                releaseDate = movie.releaseDate
                voteAverage = movie.voteAverage
                imdbRating = movie.imdbRating
                rottenTomatoesRating = movie.rottenTomatoesRating
                metacriticScore = movie.metacriticScore
                genres = movie.genres
                director = movie.director
                actors = movie.actors
                status = movie.status
                myRating = movie.myRating
                dateWatched = movie.dateWatched
                mediaType = movie.mediaType
                recommendations = movie.recommendations.map {
                    RecommendationSnapshot(
                        recommender: $0.recommender,
                        dateRecommended: $0.dateRecommended,
                        voteType: $0.voteType
                    )
                }
            }

            func toMovie() -> Movie {
                Movie(
                    id: id,
                    imdbId: imdbId,
                    tmdbId: tmdbId,
                    title: title,
                    posterPath: posterPath,
                    overview: overview,
                    releaseDate: releaseDate,
                    voteAverage: voteAverage,
                    imdbRating: imdbRating,
                    rottenTomatoesRating: rottenTomatoesRating,
                    metacriticScore: metacriticScore,
                    genres: genres,
                    director: director,
                    actors: actors ?? [],
                    status: status,
                    myRating: myRating,
                    dateWatched: dateWatched,
                    mediaType: mediaType,
                    recommendations: recommendations.map { $0.toRecommendation() }
                )
            }
        }

        private struct RecommendationSnapshot: Codable {
            let recommender: String
            let dateRecommended: String
            let voteType: String

            enum CodingKeys: String, CodingKey {
                case recommender
                case dateRecommended
                case voteType
            }

            init(recommender: String, dateRecommended: String, voteType: String = "upvote") {
                self.recommender = recommender
                self.dateRecommended = dateRecommended
                self.voteType = voteType
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                recommender = try c.decode(String.self, forKey: .recommender)
                dateRecommended = try c.decode(String.self, forKey: .dateRecommended)
                voteType = (try? c.decode(String.self, forKey: .voteType)) ?? "upvote"
            }

            func toRecommendation() -> Recommendation {
                Recommendation(
                    recommender: recommender,
                    dateRecommended: dateRecommended,
                    voteType: voteType
                )
            }
        }
    }

    struct CachedPerson: Identifiable, Hashable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "people"

        let name: String
        let isTrusted: Bool
        let movieCount: Int
        let quickKey: String?
        let color: String?
        let emoji: String?
        let cachedAt: Date

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, isTrusted = "is_trusted", movieCount = "movie_count"
            case quickKey = "quick_key"
            case color
            case emoji
            case cachedAt = "cached_at"
        }

        func toPerson() -> Person {
            Person(
                name: name,
                isTrusted: isTrusted,
                movieCount: movieCount,
                color: color,
                emoji: emoji,
                quickKey: quickKey
            )
        }

        static func from(_ person: Person) -> CachedPerson {
            CachedPerson(
                name: person.name,
                isTrusted: person.isTrusted,
                movieCount: person.movieCount,
                quickKey: person.quickKey,
                color: person.color,
                emoji: person.emoji,
                cachedAt: .now
            )
        }
    }

    struct PendingOperation: Identifiable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "pending_operations"

        let id: String
        let type: String
        let payload: String
        let createdAt: Date
        let retryCount: Int

        enum CodingKeys: String, CodingKey {
            case id, type, payload
            case createdAt = "created_at"
            case retryCount = "retry_count"
        }
    }

    struct PendingMovie: Identifiable, Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "pending_movies"

        let id: String
        let title: String
        let recommender: String
        let createdAt: Date
        let needsEnrichment: Bool

        enum CodingKeys: String, CodingKey {
            case id, title, recommender
            case createdAt = "created_at"
            case needsEnrichment = "needs_enrichment"
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
                t.column("imdb_id", .text).notNull().defaults(to: "")
                t.column("title", .text).notNull()
                t.column("poster_path", .text)
                t.column("media_type", .text).notNull().defaults(to: "movie")
                t.column("status", .text).notNull()
                t.column("my_rating", .integer)
                t.column("date_watched", .text)
                t.column("cached_at", .double).notNull()
                t.column("json_data", .text).notNull().defaults(to: "{}")
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

        migrator.registerMigration("v2_full_movie_cache") { db in
            let existingColumns = try db.columns(in: "movies").map(\.name)
            if !existingColumns.contains("imdb_id") {
                try db.alter(table: "movies") { t in
                    t.add(column: "imdb_id", .text).notNull().defaults(to: "")
                }
            }
            if !existingColumns.contains("json_data") {
                try db.alter(table: "movies") { t in
                    t.add(column: "json_data", .text).notNull().defaults(to: "{}")
                }
            }

            // Existing cache rows do not include full metadata, so rebuild from API.
            try db.execute(sql: "DELETE FROM movies")
        }

        migrator.registerMigration("v2_pending_operations") { db in
            try db.create(table: "pending_operations", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("payload", .text).notNull()
                t.column("created_at", .double).notNull()
                t.column("retry_count", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v2_pending_movies") { db in
            try db.create(table: "pending_movies", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("recommender", .text).notNull()
                t.column("created_at", .double).notNull()
                t.column("needs_enrichment", .boolean).notNull().defaults(to: true)
            }
        }

        migrator.registerMigration("v3_people_quick_key_color_emoji") { db in
            let columns = try db.columns(in: "people").map(\.name)
            if !columns.contains("quick_key") {
                try db.alter(table: "people") { t in
                    t.add(column: "quick_key", .text)
                }
            }
            if !columns.contains("color") {
                try db.alter(table: "people") { t in
                    t.add(column: "color", .text)
                }
            }
            if !columns.contains("emoji") {
                try db.alter(table: "people") { t in
                    t.add(column: "emoji", .text)
                }
            }
        }

        migrator.registerMigration("addMediaTypeToMovies") { db in
            let columns = try db.columns(in: "movies").map(\.name)
            if !columns.contains("media_type") {
                try db.alter(table: "movies") { t in
                    t.add(column: "media_type", .text).notNull().defaults(to: "movie")
                }
            }
            try db.execute(sql: "UPDATE movies SET media_type = 'movie' WHERE media_type IS NULL")
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Cache CRUD

    func cacheMovie(
        id: Int,
        tmdbId: Int,
        title: String,
        posterPath: String?,
        status: String,
        myRating: Int?,
        dateWatched: String?,
        mediaType: String = "movie"
    ) {
        let movie = Movie(
            id: id,
            imdbId: String(id),
            tmdbId: tmdbId,
            title: title,
            posterPath: posterPath,
            overview: nil,
            releaseDate: nil,
            voteAverage: nil,
            status: status,
            myRating: myRating,
            dateWatched: dateWatched,
            mediaType: mediaType,
            recommendations: []
        )
        cacheMovie(movie)
    }

    func cacheMovie(_ movie: Movie) {
        let cached = CachedMovie.from(movie)
        do {
            try dbQueue.write { db in
                try cached.save(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Insert movie error: \(error)")
        }
    }

    func cacheMovies(_ movies: [Movie]) {
        let mapped = movies.map(CachedMovie.from)
        do {
            try dbQueue.write { db in
                _ = try CachedMovie.deleteAll(db)
                for movie in mapped {
                    try movie.save(db)
                }
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Batch cache movies error: \(error)")
        }
    }

    func cachePerson(
        name: String,
        isTrusted: Bool,
        movieCount: Int,
        quickKey: String? = nil,
        color: String? = nil,
        emoji: String? = nil
    ) {
        let person = CachedPerson(
            name: name,
            isTrusted: isTrusted,
            movieCount: movieCount,
            quickKey: quickKey,
            color: color,
            emoji: emoji,
            cachedAt: .now
        )
        do {
            try dbQueue.write { db in
                try person.save(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Insert person error: \(error)")
        }
    }

    func cachePeople(_ people: [Person]) {
        let mapped = people.map(CachedPerson.from)
        do {
            try dbQueue.write { db in
                _ = try CachedPerson.deleteAll(db)
                for person in mapped {
                    try person.save(db)
                }
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Batch cache people error: \(error)")
        }
    }

    func clearAll() {
        do {
            try dbQueue.write { db in
                _ = try CachedMovie.deleteAll(db)
                _ = try CachedPerson.deleteAll(db)
                _ = try PendingOperation.deleteAll(db)
                _ = try PendingMovie.deleteAll(db)
            }
            loadCache()
        } catch {
            logDebug("[GRDB] Clear error: \(error)")
        }
    }

    // MARK: - Pending Operations

    func enqueuePendingOperation(type: String, payload: String) {
        let op = PendingOperation(
            id: UUID().uuidString,
            type: type,
            payload: payload,
            createdAt: .now,
            retryCount: 0
        )

        do {
            try dbQueue.write { db in
                try op.save(db)
            }
        } catch {
            logDebug("[GRDB] Enqueue pending op error: \(error)")
        }
    }

    func fetchPendingOperations() -> [PendingOperation] {
        do {
            return try dbQueue.read { db in
                try PendingOperation
                    .order(Column("created_at").asc)
                    .fetchAll(db)
            }
        } catch {
            logDebug("[GRDB] Fetch pending ops error: \(error)")
            return []
        }
    }

    func deletePendingOperation(id: String) {
        do {
            try dbQueue.write { db in
                _ = try PendingOperation.deleteOne(db, key: id)
            }
        } catch {
            logDebug("[GRDB] Delete pending op error: \(error)")
        }
    }

    func incrementRetryCount(id: String) {
        do {
            try dbQueue.write { db in
                if var op = try PendingOperation.fetchOne(db, key: id) {
                    op = PendingOperation(
                        id: op.id,
                        type: op.type,
                        payload: op.payload,
                        createdAt: op.createdAt,
                        retryCount: op.retryCount + 1
                    )
                    try op.update(db)
                }
            }
        } catch {
            logDebug("[GRDB] Increment pending op retry error: \(error)")
        }
    }

    // MARK: - Pending Movies

    func addPendingMovie(title: String, recommender: String) -> String {
        let id = UUID().uuidString
        let movie = PendingMovie(
            id: id,
            title: title,
            recommender: recommender,
            createdAt: .now,
            needsEnrichment: true
        )

        do {
            try dbQueue.write { db in
                try movie.save(db)
            }
        } catch {
            logDebug("[GRDB] Add pending movie error: \(error)")
        }

        return id
    }

    func fetchPendingMovies() -> [PendingMovie] {
        do {
            return try dbQueue.read { db in
                try PendingMovie
                    .filter(Column("needs_enrichment") == true)
                    .order(Column("created_at").asc)
                    .fetchAll(db)
            }
        } catch {
            logDebug("[GRDB] Fetch pending movies error: \(error)")
            return []
        }
    }

    func deletePendingMovie(id: String) {
        do {
            try dbQueue.write { db in
                _ = try PendingMovie.deleteOne(db, key: id)
            }
        } catch {
            logDebug("[GRDB] Delete pending movie error: \(error)")
        }
    }

    // MARK: - Reads

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
            logDebug("[GRDB] Fetch cache error: \(error)")
        }
    }

    var movieCount: Int { cachedMovies.count }
    var peopleCount: Int { cachedPeople.count }

    var pendingOperationsCount: Int {
        fetchPendingOperations().count
    }

    var pendingMoviesCount: Int {
        fetchPendingMovies().count
    }

    private func logDebug(_ message: @autoclosure () -> String) {
        let value = message()
        if value.localizedCaseInsensitiveContains("error") {
            AppLog.error(value, category: .database)
        } else {
            AppLog.debug(value, category: .database)
        }
    }
}
