import AppIntents
import CoreSpotlight
import Foundation

@available(iOS 27.0, *)
@AppEntity(schema: .audio.artist)
struct RecztArtistEntity {
    static let defaultQuery = ArtistQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Artist")

    let id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(name: String) {
        self.id = RecztHistorySong.stableID(title: "artist", artist: name)
        self.name = name
    }
    struct ArtistQuery: EntityQuery {
        func entities(for identifiers: [String]) async throws -> [RecztArtistEntity] {
            let idSet = Set(identifiers)
            return uniqueArtists().filter { idSet.contains($0.id) }
        }

        func suggestedEntities() async throws -> [RecztArtistEntity] {
            Array(uniqueArtists().prefix(30))
        }

        private func uniqueArtists() -> [RecztArtistEntity] {
            var seen = Set<String>()
            return RecztSharedStore.shared.history().compactMap { song in
                let entity = RecztArtistEntity(name: song.artist)
                guard seen.insert(entity.id).inserted else { return nil }
                return entity
            }
        }
    }
}

@available(iOS 27.0, *)
@AppEntity(schema: .audio.album)
struct RecztAlbumEntity {
    static let defaultQuery = AlbumQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Album")

    let id: String
    var title: String
    var artistName: String
    var artists: [RecztArtistEntity]
    var universalProductCode: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(artistName)")
    }

    struct AlbumQuery: EntityQuery {
        func entities(for identifiers: [String]) async throws -> [RecztAlbumEntity] {
            []
        }

        func suggestedEntities() async throws -> [RecztAlbumEntity] {
            []
        }
    }
}

@available(iOS 27.0, *)
@AppEntity(schema: .audio.song)
struct RecztSongEntity: IndexedEntity {
    static let defaultQuery = SongQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Song")
    
    let id: String
    var title: String
    var artistName: String
    var composerName: String?
    var albumTitle: String?
    var artists: [RecztArtistEntity]
    var album: RecztAlbumEntity?
    var composers: [RecztArtistEntity]
    var internationalStandardRecordingCode: String?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(artistName)",
            image: .init(systemName: "music.note")
        )
    }
    
    init(song: RecztHistorySong) {
        id = song.id
        title = song.title
        artistName = song.artist
        composerName = nil
        albumTitle = nil
        artists = [RecztArtistEntity(name: song.artist)]
        album = nil
        composers = []
        internationalStandardRecordingCode = nil
    }
    
    init(result: RecztRecognitionResult) {
        self.init(
            song: RecztHistorySong(
                title: result.title,
                artist: result.artist,
                albumCover: result.albumCover,
                genre: result.genre,
                emotion: result.emotion,
                spotifyURL: result.spotifyURL,
                appleMusicURL: result.appleMusicURL
            )
        )
    }
    
    struct SongQuery: IndexedEntityQuery {
        func entities(for identifiers: [String]) async throws -> [RecztSongEntity] {
            let idSet = Set(identifiers)
            return RecztSharedStore.shared.history()
                .filter { idSet.contains($0.id) }
                .map(RecztSongEntity.init(song:))
        }
        
        func suggestedEntities() async throws -> [RecztSongEntity] {
            Array(
                RecztSharedStore.shared.history()
                    .prefix(50)
                    .map(RecztSongEntity.init(song:))
            )
        }
        
        func reindexEntities(
            for identifiers: [String],
            indexDescription: CSSearchableIndexDescription
        ) async throws {
            let entities = try await entities(for: identifiers)
            try await CSSearchableIndex(name: "RecztSongs").indexAppEntities(entities)
        }
        
        func reindexAllEntities(
            indexDescription: CSSearchableIndexDescription
        ) async throws {
            try await RecztEntityIndexer.refresh(
                songs: RecztSharedStore.shared.history()
            )
        }
    }
}
    
    @available(iOS 27.0, *)
    enum RecztEntityIndexer {
        static func refresh(songs: [RecztHistorySong]) async throws {
            guard CSSearchableIndex.isIndexingAvailable() else { return }
            let index = CSSearchableIndex(name: "RecztSongs")
            try await index.deleteAppEntities(ofType: RecztSongEntity.self)
            let entities = songs.prefix(100).map(RecztSongEntity.init(song:))
            if !entities.isEmpty {
                try await index.indexAppEntities(entities, priority: 4)
            }
        }
    }

