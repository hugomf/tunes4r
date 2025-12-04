import 'package:logging/logging.dart';

/// Logger for the Theme bounded context
/// Centralizes all theme-related logging with consistent formatting
class ThemeLogger {
  static final Logger _logger = Logger('ThemeContext');
  static bool _configured = false;

  /// Configure the logger for this bounded context
  static void configure({
    Level level = Level.INFO, // INFO for theme loading/switching, WARNING for errors
  }) {
    if (_configured) return;

    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      print('[${record.level.name}] [Theme] ${record.time}: ${record.message}');
      if (record.error != null) {
        print('[${record.level.name}] [Theme] Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        print('[${record.level.name}] [Theme] Stack trace:\n${record.stackTrace}');
      }
    });

    _configured = true;
    info('Theme logger configured at level: $level');
  }

  // Static methods for different log levels
  static void finest(String message) => _logger.finest(message);
  static void finer(String message) => _logger.finer(message);
  static void fine(String message) => _logger.fine(message);

  static void info(String message, {Object? details}) {
    if (details != null) {
      _logger.info('$message - $details');
    } else {
      _logger.info(message);
    }
  }

  static void warning(String message, {Object? error}) {
    if (error != null) {
      _logger.warning('$message: $error', error, error is Error ? error.stackTrace : null);
    } else {
      _logger.warning(message);
    }
  }

  static void severe(String message, {Object? error}) {
    if (error != null) {
      _logger.severe('$message: $error', error, error is Error ? error.stackTrace : null);
    } else {
      _logger.severe(message);
    }
  }

  static void shout(String message) => _logger.shout(message);
}
