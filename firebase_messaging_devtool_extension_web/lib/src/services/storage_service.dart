import 'dart:async';

import 'package:web/web.dart' as web;

import '../constants.dart';

/// Service for handling local storage operations (Settings Only)
class StorageService {
  /// Loads user settings from local storage
  static Future<Map<String, bool>> loadSettings() async {
    try {
      // Only load showNewestOnTop
      final showNewestOnTopStr = web.window.localStorage.getItem(
        showNewestOnTopKey,
      );
      // Removed autoClearOnReload load

      final showNewestOnTop = showNewestOnTopStr == 'true';

      return {
        'showNewestOnTop': showNewestOnTop,
        // Removed autoClearOnReload return
      };
    } catch (e, stackTrace) {
      // Return defaults
      return {'showNewestOnTop': false};
    }
  }

  /// Saves user settings to local storage
  static Future<void> saveSettings({
    required bool showNewestOnTop,
    // Removed autoClearOnReload parameter
  }) async {
    try {
      web.window.localStorage.setItem(
        showNewestOnTopKey,
        showNewestOnTop.toString(),
      );
      // Removed autoClearOnReload save
    } catch (e, stackTrace) {}
  }
}
