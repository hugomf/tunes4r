import 'package:flutter/material.dart';
import '../../../utils/theme_colors.dart';
import 'exception_handler.dart';

/// Error boundary widget that catches and handles exceptions in the UI tree
/// Provides graceful error handling and recovery options for users
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String boundaryName;
  final Widget Function(BuildContext, AppError)? errorBuilder;
  final VoidCallback? onError;
  final bool showRetryButton;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.boundaryName = 'Unknown',
    this.errorBuilder,
    this.onError,
    this.showRetryButton = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Initialize error handler
    LibraryExceptionHandler.instance;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      // Use custom error builder if provided
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!);
      }

      // Default error UI
      return _buildErrorUI();
    }

    // Wrap child in error zone to catch errors
    return _ErrorZone(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(dynamic error, StackTrace stackTrace) {
    final appError = LibraryExceptionHandler.instance.handleDomainError(
      error,
      widget.boundaryName,
    );

    // Report error to external service if available
    LibraryExceptionHandler.instance.reportError(appError);

    // Notify parent if callback provided
    widget.onError?.call();

    setState(() {
      _error = appError;
      _hasError = true;
    });
  }

  Widget _buildErrorUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeColorsUtil.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon
          Icon(
            Icons.error_outline,
            color: ThemeColorsUtil.error,
            size: 48,
          ),

          const SizedBox(height: 16),

          // Error title
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              color: ThemeColorsUtil.textColorPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Error message
          Text(
            _error!.userMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeColorsUtil.textColorSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 8),

          // Recovery suggestion
          Text(
            _error!.recoveryAction,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeColorsUtil.primaryColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showRetryButton) ...[
                TextButton(
                  onPressed: _retry,
                  style: TextButton.styleFrom(
                    foregroundColor: ThemeColorsUtil.primaryColor,
                  ),
                  child: const Text('Try Again'),
                ),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: _dismiss,
                style: TextButton.styleFrom(
                  foregroundColor: ThemeColorsUtil.textColorSecondary,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),

          // Debug info (only in debug mode)
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColorsUtil.surfaceColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info:',
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Boundary: ${widget.boundaryName}',
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Type: ${_error!.type.name}',
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Time: ${_error!.timestamp.toIso8601String()}',
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _error = null;
    });
  }

  void _dismiss() {
    setState(() {
      _hasError = false;
      _error = null;
    });
  }
}

/// Internal widget that creates an error zone to catch exceptions
class _ErrorZone extends StatelessWidget {
  final Widget child;
  final Function(dynamic error, StackTrace stack) onError;

  const _ErrorZone({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Extension to add error boundary wrapper method
extension ErrorBoundaryExtension on Widget {
  /// Wraps this widget in an error boundary
  Widget withErrorBoundary({
    String name = 'Widget',
    bool showRetryButton = true,
  }) {
    return ErrorBoundary(
      boundaryName: name,
      showRetryButton: showRetryButton,
      child: this,
    );
  }
}

/// Use case execution wrapper with error boundary
/// Provides a way to execute use cases with built-in error handling
class UseCaseExecutor {
  static Future<T> execute<T>(
    Future<T> Function() useCaseFunction,
    String operationName, {
    T Function(dynamic error)? onError,
  }) async {
    try {
      return await useCaseFunction();
    } catch (error, stackTrace) {
      final appError = LibraryExceptionHandler.instance.handleDomainError(
        error,
        operationName,
      );

      // Report error
      LibraryExceptionHandler.instance.reportError(appError);

      // Return custom error result or rethrow
      if (onError != null) {
        return onError(error);
      }

      rethrow;
    }
  }

  /// Execute use case with progress tracking and error handling
  static Stream<UseCaseExecutionResult<T>> executeWithProgress<T>(
    Stream Function() useCaseFunction,
    String operationName,
  ) async* {
    try {
      await for (final progress in useCaseFunction()) {
        if (progress is Exception) {
          final appError = LibraryExceptionHandler.instance.handleDomainError(
            progress,
            operationName,
          );
          LibraryExceptionHandler.instance.reportError(appError);
          yield UseCaseExecutionResult.error(appError);
          return;
        }
        yield UseCaseExecutionResult.success(progress);
      }
    } catch (error, stackTrace) {
      final appError = LibraryExceptionHandler.instance.handleDomainError(
        error,
        operationName,
      );
      LibraryExceptionHandler.instance.reportError(appError);
      yield UseCaseExecutionResult.error(appError);
    }
  }
}

/// Result wrapper for use case executions
class UseCaseExecutionResult<T> {
  final bool success;
  final T? result;
  final AppError? error;

  const UseCaseExecutionResult._({
    required this.success,
    this.result,
    this.error,
  });

  factory UseCaseExecutionResult.success(T result) {
    return UseCaseExecutionResult._(success: true, result: result);
  }

  factory UseCaseExecutionResult.error(AppError error) {
    return UseCaseExecutionResult._(success: false, error: error);
  }

  bool get hasError => !success;
}
