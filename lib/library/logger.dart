import 'package:logging/logging.dart';

/// Logger for the Library bounded context
/// Provides structured logging for library operations
class LibraryLogger {
  static final Logger logger = Logger('Library');

  /// Configure the logger for the bounded context
  static void configure({
    Level level = Level.INFO,
    void Function(LogRecord record)? onRecord,
  }) {
    Logger.root.level = level;
    Logger.root.onRecord.listen(onRecord ??
        (record) {
          print('${record.level.name}: ${record.time}: ${record.message}');
          if (record.error != null) {
            print('  Error: ${record.error}');
            if (record.stackTrace != null) {
              print('  StackTrace: ${record.stackTrace}');
            }
          }
        });
  }

  static void finest(String message, {Object? error, StackTrace? stackTrace}) {
    logger.finest(message, error, stackTrace);
  }

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    logger.fine(message, error, stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    logger.info(message, error, stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    logger.warning(message, error, stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    logger.severe(message, error, stackTrace);
  }

  /// Convenience methods for library operations
  static void libraryOperation(String operation, {Object? details}) {
    logger.info('Library: $operation${details != null ? ' ($details)' : ''}');
  }

  static void songOperation(String operation, String songTitle, {Object? details}) {
    logger.info('Song: $operation "$songTitle"${details != null ? ' ($details)' : ''}');
  }

  static void searchOperation(String query, int results) {
    logger.info('Search: "$query" → $results results');
  }

  static void selectionOperation(String operation, int songCount) {
    logger.info('Selection: $operation ($songCount songs)');
  }

  static void databaseOperation(String operation, {Object? details}) {
    logger.fine('Database: $operation${details != null ? ' ($details)' : ''}');
  }
}
