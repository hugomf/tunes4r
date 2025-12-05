import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Global exception handler for the Library bounded context
/// Handles all unhandled exceptions and provides consistent error handling
class LibraryExceptionHandler {
  static final Logger _logger = Logger('LibraryExceptionHandler');
  static LibraryExceptionHandler? _instance;

  /// Get singleton instance
  static LibraryExceptionHandler get instance {
    _instance ??= LibraryExceptionHandler._();
    return _instance!;
  }

  LibraryExceptionHandler._() {
    _setupGlobalErrorHandling();
  }

  /// Setup global error handling for the app
  void _setupGlobalErrorHandling() {
    // Handle Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Handle platform errors (mobile/desktop)
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true; // Prevent the framework from dumping to console
    };

    // Handle uncaught async errors
    runZonedGuarded(
      () {}, // Empty function since initialization is handled elsewhere
      _handleZoneError,
    );
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    _logger.severe(
      'Flutter Error: ${details.exception}',
      details.exception,
      details.stack,
    );

    // In production, you might want to send this to an error reporting service
    // like Sentry, Firebase Crashlytics, etc.
  }

  /// Handle platform-specific errors
  void _handlePlatformError(Object error, StackTrace stack) {
    _logger.severe('Platform Error', error, stack);
  }

  /// Handle uncaught async errors from zones
  void _handleZoneError(Object error, StackTrace stack) {
    _logger.severe('Uncaught Async Error', error, stack);
  }

  /// Handle domain-specific errors with user-friendly messaging
  AppError handleDomainError(dynamic error, [String? context]) {
    final errorMessage = error.toString();
    final contextInfo = context != null ? ' in $context' : '';

    _logger.warning('Domain Error$contextInfo: $errorMessage', error);

    // Map different error types to user-friendly messages
    if (error is DatabaseException) {
      return AppError.database(
        userMessage: 'Unable to access music library. Please try refreshing.',
        technicalMessage: errorMessage,
      );
    }

    if (error is FileSystemException) {
      return AppError.fileSystem(
        userMessage: 'Unable to access music files. Please check file permissions.',
        technicalMessage: errorMessage,
      );
    }

    if (error is NetworkException) {
      return AppError.network(
        userMessage: 'Unable to connect. Please check your internet connection.',
        technicalMessage: errorMessage,
      );
    }

    if (error is ValidationException) {
      return AppError.validation(
        userMessage: error.userMessage,
        technicalMessage: errorMessage,
      );
    }

    // Generic error handling
    return AppError.unknown(
      userMessage: 'Something went wrong. Please try again.',
      technicalMessage: errorMessage,
    );
  }

  /// Report error to external error tracking service
  /// In production, integrate with services like Sentry, Crashlytics, etc.
  void reportError(AppError error) {
    _logger.info('Reporting error to external service: ${error.userMessage}');
    // TODO: Implement external error reporting
  }
}

/// Structured error information for consistent error handling
class AppError {
  final ErrorType type;
  final String userMessage;
  final String technicalMessage;
  final DateTime timestamp;
  final String? operationContext;

  const AppError._({
    required this.type,
    required this.userMessage,
    required this.technicalMessage,
    required this.timestamp,
    this.operationContext,
  });

  /// Database-related errors
  factory AppError.database({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.database,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// File system related errors
  factory AppError.fileSystem({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.fileSystem,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// Network related errors
  factory AppError.network({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.network,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// Validation related errors
  factory AppError.validation({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.validation,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// Business logic errors
  factory AppError.businessLogic({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.businessLogic,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// Unknown/unexpected errors
  factory AppError.unknown({
    required String userMessage,
    required String technicalMessage,
    String? context,
  }) {
    return AppError._(
      type: ErrorType.unknown,
      userMessage: userMessage,
      technicalMessage: technicalMessage,
      timestamp: DateTime.now(),
      operationContext: context,
    );
  }

  /// Check if this error is recoverable
  bool get isRecoverable {
    switch (type) {
      case ErrorType.network:
      case ErrorType.database:
        return true;
      case ErrorType.fileSystem:
      case ErrorType.businessLogic:
      case ErrorType.validation:
      case ErrorType.unknown:
        return false;
    }
  }

  /// Get suggested recovery action
  String get recoveryAction {
    switch (type) {
      case ErrorType.network:
        return 'Check your internet connection and try again';
      case ErrorType.database:
        return 'Try refreshing the app or restarting';
      case ErrorType.fileSystem:
        return 'Check file permissions and try a different location';
      case ErrorType.businessLogic:
      case ErrorType.validation:
        return 'Please correct the input and try again';
      case ErrorType.unknown:
        return 'Please contact support if this persists';
    }
  }

  @override
  String toString() {
    return 'AppError($type): $userMessage (${timestamp.toIso8601String()})';
  }

  /// Convert to map for logging/analytics
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'userMessage': userMessage,
      'technicalMessage': technicalMessage,
      'timestamp': timestamp.toIso8601String(),
      'operationContext': operationContext,
      'isRecoverable': isRecoverable,
    };
  }
}

/// Types of errors that can occur in the app
enum ErrorType {
  database,
  fileSystem,
  network,
  validation,
  businessLogic,
  unknown,
}

/// Custom exceptions for domain-specific errors
class DatabaseException implements Exception {
  final String message;
  final dynamic originalError;

  DatabaseException(this.message, [this.originalError]);

  @override
  String toString() => 'DatabaseException: $message';
}

class FileSystemException implements Exception {
  final String message;
  final String? path;

  FileSystemException(this.message, [this.path]);

  @override
  String toString() => 'FileSystemException: $message${path != null ? " (path: $path)" : ""}';
}

class NetworkException implements Exception {
  final String message;
  final String? url;

  NetworkException(this.message, [this.url]);

  @override
  String toString() => 'NetworkException: $message${url != null ? " (url: $url)" : ""}';
}

class ValidationException implements Exception {
  final String userMessage;
  final String technicalMessage;

  ValidationException({
    required this.userMessage,
    required this.technicalMessage,
  });

  @override
  String toString() => 'ValidationException: $userMessage';
}

class BusinessLogicException implements Exception {
  final String message;
  final String operation;

  BusinessLogicException(this.message, this.operation);

  @override
  String toString() => 'BusinessLogicException in $operation: $message';
}
