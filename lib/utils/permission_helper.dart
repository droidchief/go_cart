import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // Get Android version
      final androidVersion = await _getAndroidVersion();
      debugPrint('Android API level: $androidVersion');

      if (androidVersion >= 33) {
        // Android 13+ (API 33+) - Use scoped storage permissions
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();
        
        debugPrint('Photos permission: $photos');
        debugPrint('Videos permission: $videos');
        debugPrint('Audio permission: $audio');
        
        return photos.isGranted || videos.isGranted || audio.isGranted;
      } else if (androidVersion >= 30) {
        // Android 11-12 (API 30-32) - Try manage external storage
        final manageStorage = await Permission.manageExternalStorage.request();
        debugPrint('Manage external storage permission: $manageStorage');
        
        if (manageStorage.isGranted) return true;
        
        // Fallback to regular storage
        final storage = await Permission.storage.request();
        debugPrint('Storage permission: $storage');
        return storage.isGranted;
      } else {
        // Android 10 and below - Use regular storage permission
        final storage = await Permission.storage.request();
        debugPrint('Storage permission: $storage');
        return storage.isGranted;
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Fallback - try basic storage permission
      try {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      } catch (e2) {
        debugPrint('Fallback permission request failed: $e2');
        return false;
      }
    }
  }

  static Future<int> _getAndroidVersion() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('Error getting Android version: $e');
      return 29; // Default to Android 10
    }
  }
}