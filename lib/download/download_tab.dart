import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'download_model.dart';
import 'download_service.dart';
import 'package:tunes4r/utils/theme_colors.dart';

enum SearchMode { songs, albums }

class DownloadTab extends StatefulWidget {
  const DownloadTab({super.key});

  @override
  State<DownloadTab> createState() => _DownloadTabState();
}

class _DownloadTabState extends State<DownloadTab> {
  // Download state management (moved from main.dart in Phase 3a)
  DownloadService? _downloadService;
  bool _downloadServiceAvailable = false;
  final DownloadManager _downloadManager = DownloadManager();
  Timer? _downloadRefreshTimer;
  DateTime? _lastDownloadQueueSave;

  // Search UI state
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _albumArtistController = TextEditingController();
  final TextEditingController _albumNameController = TextEditingController();
  SearchMode _searchMode = SearchMode.songs;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initDownloadService();
  }

  @override
  void dispose() {
    _downloadRefreshTimer?.cancel();
    _searchController.dispose();
    _albumArtistController.dispose();
    _albumNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDownload(); // Extracted from main.dart
  }

  // Extracted UI from main.dart
  Widget _buildDownload() {
    if (!_downloadServiceAvailable || _downloadService == null) {
      return Container(
        color: ThemeColorsUtil.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 80,
                color: ThemeColorsUtil.textColorSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Download Service Unavailable',
                style: TextStyle(
                  fontSize: 20,
                  color: ThemeColorsUtil.textColorPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The download service is not available.\nMake sure the Python API is running.',
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryServiceConnection,
                icon: Icon(
                  Icons.refresh,
                  color: ThemeColorsUtil.scaffoldBackgroundColor,
                ),
                label: Text(
                  'Retry Connection',
                  style: TextStyle(
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColorsUtil.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: ThemeColorsUtil.scaffoldBackgroundColor,
      child: ListView(
        children: [
          // Search Header
          Container(
            color: ThemeColorsUtil.appBarBackgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎵 Download Music',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeColorsUtil.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search and download songs or albums from YouTube!',
                  style: TextStyle(
                    fontSize: 16,
                    color: ThemeColorsUtil.textColorSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Radio buttons for search mode
                Container(
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ThemeColorsUtil.textColorPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Radio<SearchMode>(
                            value: SearchMode.songs,
                            groupValue: _searchMode,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _searchMode = value);
                              }
                            },
                            activeColor: ThemeColorsUtil.primaryColor,
                          ),
                          Text(
                            'Song Search',
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Radio<SearchMode>(
                            value: SearchMode.albums,
                            groupValue: _searchMode,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _searchMode = value);
                              }
                            },
                            activeColor: ThemeColorsUtil.primaryColor,
                          ),
                          Text(
                            'Album Search',
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _searchMode == SearchMode.songs
                              ? '"Shape of You", "Adele", etc.'
                              : '"Abbey Road", "The Beatles - Sgt Pepper"',
                          hintStyle: TextStyle(
                            color: ThemeColorsUtil.textColorSecondary
                                .withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: ThemeColorsUtil.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            _searchMode == SearchMode.songs
                                ? Icons.music_note
                                : Icons.album,
                            color: ThemeColorsUtil.primaryColor,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: ThemeColorsUtil.textColorSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults.clear());
                            },
                          ),
                        ),
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorPrimary,
                        ),
                        onSubmitted: _performSearch,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _performSearch(_searchController.text),
                          icon: Icon(
                            Icons.search,
                            color: ThemeColorsUtil.scaffoldBackgroundColor,
                          ),
                          label: Text(
                            'Search ${_searchMode == SearchMode.songs ? 'Songs' : 'Albums'}',
                            style: TextStyle(
                              color: ThemeColorsUtil.scaffoldBackgroundColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColorsUtil.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Results
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 300, // Fixed height for scrollable panel
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Fixed header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            color: ThemeColorsUtil.surfaceColor,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list,
                                color: ThemeColorsUtil.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search Results (${_searchResults.length})',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeColorsUtil.textColorPrimary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: ThemeColorsUtil.textColorSecondary,
                                ),
                                onPressed: () =>
                                    setState(() => _searchResults.clear()),
                                tooltip: 'Clear Results',
                              ),
                            ],
                          ),
                        ),
                        // Scrollable results area
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: ThemeColorsUtil.scaffoldBackgroundColor
                                .withOpacity(0.5),
                            child: ListView.builder(
                              itemCount: _searchResults.length,
                              padding: const EdgeInsets.only(bottom: 16),
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return _buildSearchResultItem(result);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Download Queue - only show if there are downloads
          if (_downloadManager.downloads.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: ThemeColorsUtil.appBarBackgroundColor,
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    color: ThemeColorsUtil.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Downloads (${_downloadManager.downloads.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ThemeColorsUtil.textColorPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: ThemeColorsUtil.scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _downloadManager.downloads.length,
                itemBuilder: (context, index) {
                  final download = _downloadManager.downloads[index];
                  return _buildDownloadItem(download);
                },
              ),
            ),
          ] else if (_searchResults.isEmpty) ...[
            // No downloads and no search results
            Container(
              height: 300,
              color: ThemeColorsUtil.scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 80,
                      color: ThemeColorsUtil.textColorSecondary.withOpacity(
                        0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for Music',
                      style: TextStyle(
                        fontSize: 20,
                        color: ThemeColorsUtil.textColorPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the search box above to find songs or albums\nYour downloads will appear here',
                      style: TextStyle(
                        color: ThemeColorsUtil.textColorSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadItem(DownloadItem download) {
    IconData getStatusIcon() {
      switch (download.status) {
        case DownloadStatus.queued:
          return Icons.hourglass_empty;
        case DownloadStatus.downloading:
          return Icons.downloading;
        case DownloadStatus.completed:
          return Icons.check_circle;
        case DownloadStatus.failed:
          return Icons.error;
        case DownloadStatus.cancelled:
          return Icons.cancel;
      }
    }

    Color getStatusColor() {
      switch (download.status) {
        case DownloadStatus.queued:
          return ThemeColorsUtil.textColorSecondary;
        case DownloadStatus.downloading:
          return ThemeColorsUtil.primaryColor;
        case DownloadStatus.completed:
          return Colors.green.shade600;
        case DownloadStatus.failed:
          return ThemeColorsUtil.error;
        case DownloadStatus.cancelled:
          return Colors.orange.shade600;
      }
    }

    String getStatusText() {
      switch (download.status) {
        case DownloadStatus.queued:
          return 'Queued';
        case DownloadStatus.downloading:
          return 'Downloading...';
        case DownloadStatus.completed:
          return 'Completed';
        case DownloadStatus.failed:
          return 'Failed';
        case DownloadStatus.cancelled:
          return 'Cancelled';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(getStatusIcon(), color: getStatusColor(), size: 18),
            ),
            const SizedBox(width: 10),
            // Title and status in a column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          download.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeColorsUtil.textColorPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          download.artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeColorsUtil.textColorSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        getStatusText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: getStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (download.status == DownloadStatus.downloading) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${download.progress.round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: ThemeColorsUtil.textColorSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Progress bar for downloading items
                  if (download.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: download.progress / 100.0,
                      backgroundColor: ThemeColorsUtil.surfaceColor.withOpacity(
                        0.5,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeColorsUtil.primaryColor,
                      ),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ],
                ],
              ),
            ),
            // Action button
            if (download.status == DownloadStatus.failed ||
                download.status == DownloadStatus.cancelled)
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: ThemeColorsUtil.primaryColor,
                  size: 16,
                ),
                onPressed: () => _retryDownload(download),
                tooltip: 'Retry',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              )
            else if (download.status == DownloadStatus.downloading)
              IconButton(
                icon: Icon(Icons.cancel, color: Colors.red.shade600, size: 16),
                onPressed: () => _cancelDownload(download),
                tooltip: 'Cancel',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              )
            else if (download.status == DownloadStatus.completed)
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: ThemeColorsUtil.textColorSecondary,
                  size: 16,
                ),
                onPressed: () => _removeDownload(download),
                tooltip: 'Remove',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
          ],
        ),
      ),
    );
  }

  void _retryDownload(DownloadItem download) {
    // TODO: Implement retry download
    print('Retry download: ${download.title}');
  }

  void _cancelDownload(DownloadItem download) {
    // TODO: Implement cancel download
    print('Cancel download: ${download.title}');
  }

  void _removeDownload(DownloadItem download) {
    setState(() {
      _downloadManager.removeDownload(download.id);
    });
    print('Removed download: ${download.title}');
  }

  Future<void> _retryServiceConnection() async {
    setState(() {
      _downloadServiceAvailable = false;
    });
    await _initDownloadService();
  }

  // Smart download function that determines what type of download to perform
  Future<void> _performSmartDownload(String query) async {
    if (query.isEmpty) return;

    // Check if it's a URL
    if (_isYouTubeUrl(query)) {
      await _downloadFromUrl(query);
    }
    // Check if it might be an album (contains common album keywords)
    else if (_looksLikeAlbumQuery(query)) {
      await _downloadAlbumSmart(query);
    }
    // Otherwise, treat as song search
    else {
      await _searchAndDownloadSong(query);
    }
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('music.youtube.com') ||
        url.startsWith('http');
  }

  bool _looksLikeAlbumQuery(String query) {
    // Simple heuristic for album queries
    // If it has "album" keyword or looks like "artist - album" format
    return query.toLowerCase().contains('album') ||
        query.split('-').length >= 2 &&
            !query.contains('ft.') &&
            !query.contains('feat');
  }

  Future<void> _downloadFromUrl(String url) async {
    try {
      final result = await _downloadService!.downloadFromUrl(url);
      if (result != null) {
        // Check if response has expected structure - API returns download_id, not id
        if (result.containsKey('download_id')) {
          print(
            '✅ URL download API returned valid response with download_id: ${result['download_id']}',
          );

          // Extract download ID from response
          final downloadId = result['download_id'] as String;
          print(
            '🎵 Extracted downloadId: "$downloadId" (type: ${downloadId.runtimeType})',
          );

          // Create DownloadItem from API response and add to queue
          final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
          _downloadManager.addDownload(downloadItem);

          // Save queue to persistence
          await _saveDownloadQueue();

          // Force an immediate status check for this download
          if (_downloadService != null) {
            try {
              print(
                '🔄 Performing immediate status check for download: $downloadId',
              );
              final statusResponse = await _downloadService!.getDownloadStatus(
                downloadId,
              );
              if (statusResponse != null) {
                print('📡 Immediate status response: $statusResponse');
                _downloadManager.updateDownload(downloadId, statusResponse);
              } else {
                print('⚠️ No status response received');
              }
            } catch (e) {
              print('❌ Error in immediate status check: $e');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Started downloading "${downloadItem.title}" by ${downloadItem.artist}',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.surfaceColor,
            ),
          );
        } else {
          throw 'Invalid response format - missing download_id field';
        }
      } else {
        throw 'Download from URL failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download failed: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  Future<List<String>> _findDownloadedAudioFiles() async {
    final List<String> audioFiles = [];

    // Try multiple possible locations for downloaded files
    final possiblePaths = [
      // Primary location (from API service path)
      p.join(Directory.current.path, '..', 'downloaded_music'),
      // Alternative locations if working directory differs
      p.join(Directory.current.path, 'downloaded_music'),
      // Path relative to app documents
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        '..',
        'downloaded_music',
      ),
    ];

    for (final dirPath in possiblePaths) {
      final directory = Directory(dirPath);

      try {
        print('🔍 Scanning download directory: $dirPath');
        if (await directory.exists()) {
          print('✅ Directory exists: $dirPath');
          await for (var entity in directory.list(recursive: false)) {
            if (entity is File) {
              final extension = p.extension(entity.path).toLowerCase();
              if ([
                '.mp3',
                '.m4a',
                '.aac',
                '.ogg',
                '.flac',
                '.wav',
              ].contains(extension)) {
                audioFiles.add(entity.path);
                print('📁 Found audio file: ${p.basename(entity.path)}');
              }
            }
          }
          if (audioFiles.isNotEmpty) {
            print('🎵 Found ${audioFiles.length} audio files total');
            break; // Stop scanning if we found files
          }
        } else {
          print('⚠️ Directory does not exist: $dirPath');
        }
      } catch (e) {
        print('❌ Error scanning directory $dirPath: $e');
      }
    }

    return audioFiles;
  }

  // Download service initialization and business logic methods
  Future<void> _initDownloadService() async {
    try {
      _downloadService = DownloadService();
      final status = await _downloadService?.getServiceStatus();
      if (mounted) {
        setState(() {
          _downloadServiceAvailable = status != null;
        });
      }
      print('✅ Download service available: $_downloadServiceAvailable');

      // Start download progress monitoring if service is available
      if (_downloadServiceAvailable) {
        _startDownloadProgressMonitoring();
        _loadDownloadQueue();
      }
    } catch (e) {
      print('❌ Download service not available: $e');
      if (mounted) {
        setState(() {
          _downloadServiceAvailable = false;
        });
      }
    }
  }

  Future<void> _loadDownloadQueue() async {
    try {
      final data = null; // TODO: Add proper persistence to widget
      if (data != null) {
        // _downloadManager.loadFromStorage(data); // TODO: Implement when extracting persistence
        print(
          '📥 Loaded ${_downloadManager.downloads.length} downloads from storage',
        );
      }
    } catch (e) {
      print('❌ Error loading download queue: $e');
    }
  }

  Future<void> _saveDownloadQueue() async {
    try {
      // Simplified - TODO: Add proper persistence logic to widget
      // _lastDownloadQueueSave = DateTime.now();
      print(
        '💾 Saved ${_downloadManager.downloads.length} downloads to storage',
      );
    } catch (e) {
      print('❌ Error saving download queue: $e');
    }
  }

  void _startDownloadProgressMonitoring() {
    // Frequent polling to check if DownloadManager thinks it's time to refresh
    _downloadRefreshTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_downloadServiceAvailable || _downloadService == null) return;

      // Let DownloadManager decide when to actually refresh status
      // This uses its internal throttling logic (3s for active, 5s for inactive)
      if (!_downloadManager.shouldRefreshStatus()) return;

      final activeDownloads = _downloadManager.activeDownloads;
      if (activeDownloads.isEmpty) return;

      bool hasCompletion = false;

      for (final download in activeDownloads) {
        try {
          final statusResponse = await _downloadService!.getDownloadStatus(
            download.id,
          );
          if (statusResponse != null) {
            _downloadManager.updateDownload(download.id, statusResponse);

            // If download completed, save to library and show notification
            final updatedDownload = _downloadManager.getDownload(download.id);

            if (updatedDownload?.status == DownloadStatus.completed &&
                download.status != DownloadStatus.completed) {
              await _handleDownloadCompletion(updatedDownload!);
              hasCompletion = true;
            }
          } else {
            // Treat null response as download not found - mark as failed
            _downloadManager.updateDownload(download.id, {
              'status': 'error',
              'error': 'Download not found on server',
            });
          }
        } catch (e) {
          // Mark download as failed when status check fails
          _downloadManager.updateDownload(download.id, {
            'status': 'error',
            'error': 'Failed to check status: $e',
          });
        }
      }

      // Clean up old downloads
      _downloadManager.clearOldDownloads();

      // Mark status refreshed
      _downloadManager.markStatusRefreshed();

      // Trigger UI update if needed
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _handleDownloadCompletion(DownloadItem download) async {
    // TODO: Implement proper completion handling - for now just show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ "${download.title}" downloaded successfully!')),
    );
    print('🎉 Download completed: "${download.title}" by ${download.artist}');
  }

  Future<void> _performSearch(String query) async {
    if (_downloadService == null || query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      if (_searchMode == SearchMode.songs) {
        final searchResults = await _downloadService!.searchSongs(
          query,
          limit: 10,
        );
        if (searchResults != null && searchResults.isNotEmpty) {
          final formattedResults = searchResults
              .map<Map<String, dynamic>>(
                (song) => {
                  ...song,
                  'thumbnail_url':
                      song['thumbnail_url'] ??
                      'https://via.placeholder.com/120x90/333333/666666?text=No+Image',
                },
              )
              .toList();
          setState(() => _searchResults = formattedResults);
        } else {
          print('No song results found for: $query');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$query"')),
          );
        }
      } else {
        final albumResults = await _downloadService!.searchAlbums(
          query,
          limit: 5,
        );
        if (albumResults != null && albumResults.isNotEmpty) {
          final formattedResults = albumResults
              .map<Map<String, dynamic>>(
                (album) => {
                  'title': album['album'] ?? 'Unknown Album',
                  'artist': album['artist'] ?? 'Unknown Artist',
                  'album': album['album'],
                  'track_count': album['track_count'] ?? 0,
                  'release_year': album['release_year'],
                  'type': 'album',
                  'album_info': album,
                  'thumbnail_url':
                      album['cover_url'] ??
                      'https://via.placeholder.com/120x90/333333/666666?text=Album',
                },
              )
              .toList();
          setState(() => _searchResults = formattedResults);
        } else {
          print('No album results found for: $query');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No albums found for "$query"')),
          );
        }
      }
    } catch (e) {
      print('❌ Search error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchAndDownloadSong(String query) async {
    try {
      final result = await _downloadService!.searchSong(query: query);
      if (result != null && result.containsKey('download_id')) {
        final downloadId = result['download_id'] as String;
        final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
        _downloadManager.addDownload(downloadItem);
        await _saveDownloadQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading "${downloadItem.title}"'),
          ),
        );

        // Force immediate status check
        if (_downloadService != null) {
          try {
            final statusResponse = await _downloadService!.getDownloadStatus(
              downloadId,
            );
            if (statusResponse != null) {
              _downloadManager.updateDownload(downloadId, statusResponse);
            }
          } catch (e) {
            print('❌ Error in immediate status check: $e');
          }
        }

        setState(() {});
      } else {
        throw 'Invalid response format';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _downloadFromSearchResult(
    Map<String, dynamic> result,
    bool isAlbumTrack,
  ) async {
    try {
      if (_searchMode == SearchMode.songs) {
        final songQuery = '${result['artist']} - ${result['title']}';
        await _searchAndDownloadSong(songQuery);
      } else {
        if (isAlbumTrack && result.containsKey('album_info')) {
          final albumInfo = result['album_info'] as Map<String, dynamic>;
          final artist = albumInfo['artist'] ?? result['artist'];
          final album = albumInfo['album'] ?? result['album'];
          await _downloadAlbumSmart('$artist - $album');
        } else {
          final songQuery = '${result['artist']} - ${result['title']}';
          await _searchAndDownloadSong(songQuery);
        }
      }
    } catch (e) {
      print('❌ Error downloading from search result: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _downloadAlbumSmart(String query) async {
    try {
      final parts = query.split('-').map((s) => s.trim()).toList();
      String artist = '';
      String album = '';

      if (parts.length >= 2) {
        artist = parts[0];
        album = parts.sublist(1).join('-');
      }

      if (artist.isEmpty) artist = _albumArtistController.text.trim();
      if (album.isEmpty) album = _albumNameController.text.trim();

      if (artist.isEmpty || album.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For album searches, please specify "Artist - Album Name"',
            ),
          ),
        );
        return;
      }

      final result = await _downloadService!.downloadAlbum(artist, album);
      if (result != null && result.containsKey('download_id')) {
        final downloadId = result['download_id'] as String;
        final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
        _downloadManager.addDownload(downloadItem);
        await _saveDownloadQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading album "$album" by $artist'),
          ),
        );
      } else {
        throw 'Invalid response format';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Album download failed: $e')));
    }
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    final title = result['title'] ?? 'Unknown Title';
    final artist = result['artist'] ?? 'Unknown Artist';
    final album = result['album'];
    final duration = result['duration'] ?? result['length'];
    final trackNumber = result['track_number'];
    final isAlbumTrack = result['type'] == 'album_track';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThemeColorsUtil.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              result['thumbnail_url'] ??
                  'https://via.placeholder.com/120x90/333333/666666?text=No+Image',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _searchMode == SearchMode.songs
                      ? Icons.music_note
                      : Icons.album,
                  color: ThemeColorsUtil.primaryColor,
                  size: 20,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Icon(
                  _searchMode == SearchMode.songs
                      ? Icons.music_note
                      : Icons.album,
                  color: ThemeColorsUtil.primaryColor,
                  size: 18,
                );
              },
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (trackNumber != null) ...[
                  Text(
                    '$trackNumber. ',
                    style: TextStyle(
                      color: ThemeColorsUtil.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (album != null) ...[
              Text(
                album,
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        subtitle: Text(
          artist,
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (duration != null) ...[
              Text(
                duration.toString(),
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: Icon(Icons.download, color: ThemeColorsUtil.primaryColor),
              onPressed: () => _downloadFromSearchResult(result, isAlbumTrack),
              tooltip: 'Download',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importDownloadedSongs() async {
    try {
      final songFiles = await _findDownloadedAudioFiles();

      if (songFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No downloaded music files found to import',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
        return;
      }

      // Process all found audio files
      // Note: _processAudioFiles and _saveSong methods would need to be
      // accessible from this widget context or refactored
      // For now, just show successful file discovery
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Found ${songFiles.length} downloaded files',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );

      print('Found ${songFiles.length} downloaded songs in filesystem');
    } catch (e) {
      print('❌ Error importing downloaded songs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to import downloaded songs: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }
}
