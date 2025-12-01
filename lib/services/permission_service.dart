import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests audio and photos permissions with error dialogs
  Future<bool> requestMediaPermissions({
    required Function(BuildContext) showPermissionDialog,
  }) async {
    try {
      // Step 1: Request modern granular media permissions (Android 13+)
      print('🎵 Checking granular media permissions...');
      final audioPermission = await Permission.audio.status;
      final imagePermission = await Permission.photos.status;

      bool hasPermissions = audioPermission.isGranted && imagePermission.isGranted;
      print('🎵 Media permissions - Audio: ${audioPermission.isGranted}, Images: ${imagePermission.isGranted}');

      if (!hasPermissions) {
        print('🎵 Requesting granular media permissions...');
        final audioResult = await Permission.audio.request();
        final imageResult = await Permission.photos.request();

        hasPermissions = audioResult.isGranted && imageResult.isGranted;
        print('🎵 Permission results - Audio: ${audioResult.isGranted}, Images: ${imageResult.isGranted}');
      }

      return hasPermissions;
    } catch (e) {
      print('🎵 Permission service error (plugin not available): $e');
      // Return true to allow file picker to work without permissions on macOS
      return true;
    }
  }

  /// Opens app settings to manually grant permissions
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      print('🎵 Failed to open app settings (plugin not available): $e');
      // Gracefully handle the error - settings can't be opened on this platform
    }
  }
}
