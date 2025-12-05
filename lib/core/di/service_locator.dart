import 'package:get_it/get_it.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/file_import_service.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/services/permission_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Setup dependency injection container
Future<void> setupServiceLocator() async {
  // Services - infrastructure layer
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<PlaybackManager>(() => PlaybackManager());
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());

  // Wait for async initialization of database
  final db = getIt<DatabaseService>();
  await db.database;

  // Services that depend on database
  getIt.registerLazySingleton<FileImportService>(
    () => FileImportService(getIt<DatabaseService>()),
  );

  print('✅ Service locator initialized successfully');
}
