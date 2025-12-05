import 'dart:async';

/// Base class for all use cases
///
/// A use case represents a specific business operation that encapsulates
/// business logic while keeping the UI layer clean and focused on presentation.
///
/// Use cases follow the Command pattern and are:
//   - Single Responsibility: Each use case does one specific thing
//   - Dependency Injection: Receive dependencies through constructor
//   - Pure Functions: No side effects except through injected dependencies
//   - Testable: Easy to unit test with mocked dependencies
abstract class BaseUseCase<Input, Output> {
  /// Execute the use case with the given input
  ///
  /// Should return a Future with either success data or throw an exception
  /// Error handling should be consistent across all use cases
  Future<Output> execute(Input input);

  /// Optional: Execute with progress tracking for long-running operations
  /// Returns a stream that emits progress updates alongside the final result
  Stream<UseCaseProgress<Output>> executeWithProgress(Input input) {
    return _executeWithProgress(input);
  }

  Stream<UseCaseProgress<Output>> _executeWithProgress(Input input) async* {
    try {
      yield UseCaseProgress.initial('Starting...');

      final result = await execute(input);

      yield UseCaseProgress.completed(result);
    } catch (error, stackTrace) {
      yield UseCaseProgress.failed(error.toString());
      rethrow;
    }
  }

  /// Optional: Cancel the operation if supported
  /// Returns true if cancellation was successful
  Future<bool> cancel() async => false;
}

/// Progress information for long-running use cases
class UseCaseProgress<T> {
  final ProgressStatus status;
  final int? percentage;
  final String? message;
  final T? result;
  final String? error;

  const UseCaseProgress._({
    required this.status,
    this.percentage,
    this.message,
    this.result,
    this.error,
  });

  factory UseCaseProgress.initial([String message = 'Initializing...']) {
    return UseCaseProgress._(
      status: ProgressStatus.initial,
      message: message,
      percentage: 0,
    );
  }

  factory UseCaseProgress.running(int percentage, [String? message]) {
    return UseCaseProgress._(
      status: ProgressStatus.running,
      message: message,
      percentage: percentage.clamp(0, 100),
    );
  }

  factory UseCaseProgress.completed(T result) {
    return UseCaseProgress._(
      status: ProgressStatus.completed,
      result: result,
      percentage: 100,
      message: 'Completed successfully',
    );
  }

  factory UseCaseProgress.failed(String error) {
    return UseCaseProgress._(
      status: ProgressStatus.failed,
      error: error,
      message: 'Operation failed',
    );
  }

  bool get isCompleted => status == ProgressStatus.completed;
  bool get isFailed => status == ProgressStatus.failed;
  bool get isRunning => status == ProgressStatus.running;
}

/// Status values for progress tracking
enum ProgressStatus {
  initial,
  running,
  completed,
  failed,
}

/// Specialized base class for use cases that don't require input parameters
/// Common for operations like "GetAllSongs" or "RefreshData"
abstract class NoInputUseCase<Output> extends BaseUseCase<void, Output> {
  @override
  Future<Output> execute([void input]) {
    return executeImpl();
  }

  /// Implementation method that subclasses should override
  Future<Output> executeImpl();
}

/// Specialized base class for use cases that don't return output
/// Common for operations like "DeleteSong" that just need success confirmation
abstract class NoOutputUseCase<Input> extends BaseUseCase<Input, void> {
  @override
  Future<void> execute(Input input) {
    return executeImpl(input);
  }

  /// Implementation method that subclasses should override
  Future<void> executeImpl(Input input);
}

/// Type alias for void inputs (makes intent clearer in use case definitions)
typedef VoidInput = void;
