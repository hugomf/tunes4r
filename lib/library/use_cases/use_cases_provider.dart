import '../repositories/repository_provider.dart';
import '../services/media_scan_service.dart';
import '../services/metadata_extraction_service.dart';
import 'abstracts/base_use_case.dart';
import 'implementations/import_songs_use_case.dart';
import 'implementations/search_library_use_case.dart';
import 'implementations/toggle_favorite_use_case.dart';

/// Provider class that creates and manages use case instances
/// Handles dependency injection and provides easy access to business logic
class UseCasesProvider {
  final RepositoryProvider _repositoryProvider;
  final MediaScanService _mediaScanService;
  final MetadataExtractionService _metadataExtractionService;

  // Cached use case instances (can be made configurable later)
  ImportSongsUseCase? _importSongsUseCase;
  SearchLibraryUseCase? _searchLibraryUseCase;
  ToggleFavoriteUseCase? _toggleFavoriteUseCase;

  UseCasesProvider({
    required RepositoryProvider repositoryProvider,
    required MediaScanService mediaScanService,
    required MetadataExtractionService metadataExtractionService,
  })  : _repositoryProvider = repositoryProvider,
        _mediaScanService = mediaScanService,
        _metadataExtractionService = metadataExtractionService;

  /// Factory constructor for convenience
  static UseCasesProvider create({
    required RepositoryProvider repositoryProvider,
    required MediaScanService mediaScanService,
    required MetadataExtractionService metadataExtractionService,
  }) {
    return UseCasesProvider(
      repositoryProvider: repositoryProvider,
      mediaScanService: mediaScanService,
      metadataExtractionService: metadataExtractionService,
    );
  }

  /// Song import operations
  ImportSongsUseCase get importSongsUseCase {
    _importSongsUseCase ??= ImportSongsUseCase(
      repositoryProvider: _repositoryProvider,
      mediaScanService: _mediaScanService,
      metadataExtractionService: _metadataExtractionService,
    );
    return _importSongsUseCase!;
  }

  /// Library search operations
  SearchLibraryUseCase get searchLibraryUseCase {
    _searchLibraryUseCase ??= SearchLibraryUseCase(
      repositoryProvider: _repositoryProvider,
    );
    return _searchLibraryUseCase!;
  }

  /// Favorite management operations
  ToggleFavoriteUseCase get toggleFavoriteUseCase {
    _toggleFavoriteUseCase ??= ToggleFavoriteUseCase(
      repositoryProvider: _repositoryProvider,
    );
    return _toggleFavoriteUseCase!;
  }

  /// Convenience method for importing files
  Future<int> importMusicFiles(List<String> filePaths) async {
    final input = ImportSongsInput.multipleFiles(filePaths);
    final result = await importSongsUseCase.execute(input);
    return result;
  }

  /// Convenience method for importing a single file
  Future<int> importSingleFile(String filePath) async {
    final input = ImportSongsInput.singleFile(filePath);
    final result = await importSongsUseCase.execute(input);
    return result;
  }

  /// Convenience method for importing a directory
  Future<int> importDirectory(String directoryPath) async {
    final input = ImportSongsInput.directory(directoryPath);
    final result = await importSongsUseCase.execute(input);
    return result;
  }

  /// Convenience method for searching the library
  Future<SearchLibraryResult> searchLibrary(String query, {
    int? limit,
    double? minRelevance,
  }) async {
    final input = SearchLibraryInput.advanced(
      query: query,
      limit: limit,
      minRelevance: minRelevance,
    );
    return await searchLibraryUseCase.execute(input);
  }

  /// Convenience method for basic search
  Future<SearchLibraryResult> basicSearch(String query) async {
    final input = SearchLibraryInput.basic(query);
    return await searchLibraryUseCase.execute(input);
  }

  /// Convenience method for toggling favorites
  Future<ToggleFavoriteResult> toggleFavorite(
    // Note: We could import Song here, but letting callers pass the song directly
    dynamic song, // Using dynamic to avoid circular import
  ) async {
    // This would need the Song type, but we'll handle through the use case
    throw UnimplementedError('Use ToggleFavoriteInput.fromSong(song) instead');
  }

  /// Clean up resources
  void dispose() {
    _importSongsUseCase = null;
    _searchLibraryUseCase = null;
    _toggleFavoriteUseCase = null;
  }
}

/// Extension methods for easier use case access throughout the Library bounded context
extension UseCasesProviderExtensions on UseCasesProvider {
  /// Import operations with progress tracking
  Stream<UseCaseProgress<int>> importFilesWithProgress(List<String> filePaths) {
    final input = ImportSongsInput.multipleFiles(filePaths);
    return importSongsUseCase.executeWithProgress(input);
  }

  /// Search with advanced options
  Future<SearchLibraryResult> advancedSearch({
    required String query,
    int? limit,
    double? minRelevance,
    SearchScope scope = SearchScope.all,
  }) async {
    final input = SearchLibraryInput.advanced(
      query: query,
      limit: limit,
      minRelevance: minRelevance,
      scope: scope,
    );
    return await searchLibraryUseCase.execute(input);
  }
}
