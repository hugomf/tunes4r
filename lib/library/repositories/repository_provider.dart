import '../../../services/database_service.dart';
import 'abstracts/i_song_repository.dart';
import 'abstracts/i_album_repository.dart';
import 'implementations/database_song_repository.dart';
import 'implementations/database_album_repository.dart';

/// Provider class that creates and manages repository instances
/// Handles dependency injection for the repository layer
class RepositoryProvider {
  final DatabaseService _databaseService;

  // Cached repository instances (singleton pattern)
  ISongRepository? _songRepository;
  IAlbumRepository? _albumRepository;

  RepositoryProvider(this._databaseService);

  /// Gets or creates the song repository instance
  ISongRepository get songRepository {
    _songRepository ??= DatabaseSongRepository(_databaseService);
    return _songRepository!;
  }

  /// Gets or creates the album repository instance
  IAlbumRepository get albumRepository {
    _albumRepository ??= DatabaseAlbumRepository(songRepository);
    return _albumRepository!;
  }

  /// Creates a new RepositoryProvider instance with the given database service
  static RepositoryProvider create(DatabaseService databaseService) {
    return RepositoryProvider(databaseService);
  }

  /// Dispose of any resources held by repositories
  void dispose() {
    // Currently no resources to dispose, but this method is here for future use
    _songRepository = null;
    _albumRepository = null;
  }
}
