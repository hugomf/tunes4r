import 'package:logging/logging.dart';

/// Simple logger for the Audio Player Bounded Context
/// Provides standard logging levels: finest, info, warning, severe
class AudioPlayerLogger {
  static final Logger logger = Logger('AudioPlayer');

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


  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    logger.info(message, error, stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    logger.warning(message, error, stackTrace);
  }

  static void trace(String message, {Object? error, StackTrace? stackTrace}) {
    logger.finest(message, error, stackTrace);
  }

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    logger.fine(message, error, stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    logger.severe(message, error, stackTrace);
  }
}
