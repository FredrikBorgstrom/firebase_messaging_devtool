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
      // Load the new clearOnReload setting
      final clearOnReloadStr = web.window.localStorage.getItem(
        clearOnReloadKey,
      );
      // Load hideNullValues setting
      final hideNullValuesStr = web.window.localStorage.getItem(
        hideNullValuesKey,
      );

      final showNewestOnTop = showNewestOnTopStr == 'true';
      // Default clearOnReload to true if not found or invalid
      final clearOnReload = clearOnReloadStr != 'false';
      // Default hideNullValues to true if not found or invalid
      final hideNullValues = hideNullValuesStr != 'false';

      return {
        'showNewestOnTop': showNewestOnTop,
        'clearOnReload': clearOnReload, // Return the setting
        'hideNullValues': hideNullValues, // Return the setting
      };
    } catch (e, stackTrace) {
      // Return defaults
      return {
        'showNewestOnTop': false,
        'clearOnReload': true,
        'hideNullValues': false, // Default to false
      };
    }
  }

  /// Saves user settings to local storage
  static Future<void> saveSettings({
    required bool showNewestOnTop,
    required bool clearOnReload, // Add parameter
    required bool hideNullValues, // Add parameter
  }) async {
    try {
      web.window.localStorage.setItem(
        showNewestOnTopKey,
        showNewestOnTop.toString(),
      );
      // Save the new clearOnReload setting
      web.window.localStorage.setItem(
        clearOnReloadKey,
        clearOnReload.toString(),
      );
      // Save the hideNullValues setting
      web.window.localStorage.setItem(
        hideNullValuesKey,
        hideNullValues.toString(),
      );
    } catch (e, stackTrace) {}
  }
}
