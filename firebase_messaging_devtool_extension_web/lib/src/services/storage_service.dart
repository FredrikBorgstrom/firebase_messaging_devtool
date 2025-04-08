import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web/web.dart' as web;

import '../constants.dart';
import '../models/firebase_message.dart';

/// Service for handling all local storage operations
class StorageService {
  /// Forcefully clears message data using multiple methods, prioritizing standard web APIs.
  /// Does NOT call setState directly for memory clear, handled by caller.
  static Future<void> forceClearMessageStorage() async {
    final key = messagesStorageKey;
    developer.log(
      '[Force Clear] Attempting web API clear for key: $key',
      name: 'FirebaseMessagingDevTool',
    );
    bool cleared = false;
    try {
      // Log value BEFORE attempting clear
      var valueBefore = web.window.localStorage.getItem(key);
      developer.log(
        '[Force Clear] Value BEFORE clear attempts: "$valueBefore"',
        name: 'FirebaseMessagingDevTool',
      );
      if (valueBefore == null) {
        developer.log(
          '[Force Clear] Storage was already null before clearing.',
          name: 'FirebaseMessagingDevTool',
        );
        cleared = true; // Already clear
      } else {
        // Method 1: Standard web API removeItem
        web.window.localStorage.removeItem(key);
        developer.log(
          '[Force Clear] Executed web localStorage.removeItem("$key")',
          name: 'FirebaseMessagingDevTool',
        );
        var valueAfterRemove = web.window.localStorage.getItem(key);
        developer.log(
          '[Force Clear] Value immediately AFTER removeItem: "$valueAfterRemove"',
          name: 'FirebaseMessagingDevTool',
        );

        // Verification 1
        if (valueAfterRemove == null) {
          developer.log(
            '[Force Clear] VERIFIED: web removeItem successful. Key is null.',
            name: 'FirebaseMessagingDevTool',
          );
          cleared = true;
        } else {
          developer.log(
            '[Force Clear] web removeItem failed or key persisted. Trying web setItem...',
            name: 'FirebaseMessagingDevTool',
          );

          // Method 2: Standard web API setItem to empty array
          web.window.localStorage.setItem(key, '[]');
          developer.log(
            '[Force Clear] Executed web localStorage.setItem("$key", "[]")',
            name: 'FirebaseMessagingDevTool',
          );
          var valueAfterSetEmpty = web.window.localStorage.getItem(key);
          developer.log(
            '[Force Clear] Value immediately AFTER setItem([]): "$valueAfterSetEmpty"',
            name: 'FirebaseMessagingDevTool',
          );

          // Verification 2
          if (valueAfterSetEmpty == '[]') {
            developer.log(
              '[Force Clear] VERIFIED: web setItem to [] successful.',
              name: 'FirebaseMessagingDevTool',
            );
            cleared = true;
          } else {
            developer.log(
              '[Force Clear] FATAL: ALL web API CLEARING METHODS FAILED! Final getItem value: "$valueAfterSetEmpty"',
              name: 'FirebaseMessagingDevTool',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        '[Force Clear] Error during web API storage clear: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      // Add a small delay to potentially allow storage persistence
      await Future.delayed(const Duration(milliseconds: 100));
      developer.log(
        '[Force Clear] Completed (cleared=$cleared) after delay.',
        name: 'FirebaseMessagingDevTool',
      );
    }
  }

  /// Loads user settings from local storage
  static Future<Map<String, bool>> loadSettings() async {
    try {
      // Load settings state from localStorage
      final showNewestOnTopStr = web.window.localStorage.getItem(
        showNewestOnTopKey,
      );
      final autoClearOnReloadStr = web.window.localStorage.getItem(
        autoClearOnReloadKey,
      );

      final showNewestOnTop = showNewestOnTopStr == 'true';
      final autoClearOnReload = autoClearOnReloadStr == 'true';

      developer.log(
        'Settings loaded: showNewest=$showNewestOnTop, autoClear=$autoClearOnReload',
        name: 'FirebaseMessagingDevTool',
      );

      return {
        'showNewestOnTop': showNewestOnTop,
        'autoClearOnReload': autoClearOnReload,
      };
    } catch (e, stackTrace) {
      developer.log(
        'Error loading settings: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
      // Return defaults
      return {'showNewestOnTop': false, 'autoClearOnReload': false};
    }
  }

  /// Saves user settings to local storage
  static Future<void> saveSettings({
    required bool showNewestOnTop,
    required bool autoClearOnReload,
  }) async {
    try {
      web.window.localStorage.setItem(
        showNewestOnTopKey,
        showNewestOnTop.toString(),
      );
      web.window.localStorage.setItem(
        autoClearOnReloadKey,
        autoClearOnReload.toString(),
      );

      developer.log(
        'Settings saved to localStorage: showNewestOnTop=$showNewestOnTop, autoClearOnReload=$autoClearOnReload',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error saving settings: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks if auto-clear is enabled in local storage
  static bool isAutoClearEnabled() {
    try {
      final autoClearOnReloadStr = web.window.localStorage.getItem(
        autoClearOnReloadKey,
      );
      return autoClearOnReloadStr == 'true';
    } catch (e) {
      developer.log(
        'Error checking auto-clear setting: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
      );
      return false;
    }
  }

  /// Sets a flag for auto-clear in the next session
  static void forceAutoClearNextSession() {
    try {
      web.window.localStorage.setItem(autoClearOnReloadKey, 'true');
      developer.log(
        'Set auto-clear flag in storage to TRUE for next session',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e) {
      developer.log(
        'Error setting auto-clear flag for next session: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
      );
    }
  }

  /// Loads messages from local storage
  static Future<List<FirebaseMessage>> loadMessages() async {
    developer.log(
      '[LoadMessages] Starting load process',
      name: 'FirebaseMessagingDevTool',
    );

    try {
      // Double-check auto-clear just in case
      if (isAutoClearEnabled()) {
        developer.log(
          '[LoadMessages] Auto-clear is ON. Aborting load.',
          name: 'FirebaseMessagingDevTool',
        );
        return [];
      }

      final messagesJson = web.window.localStorage.getItem(messagesStorageKey);
      if (messagesJson == null ||
          messagesJson.isEmpty ||
          messagesJson == '[]') {
        developer.log(
          '[LoadMessages] No message JSON found in storage or empty array.',
          name: 'FirebaseMessagingDevTool',
        );
        return [];
      }

      // Log full JSON for debugging
      developer.log(
        '[LoadMessages] Found JSON string in storage (full): $messagesJson',
        name: 'FirebaseMessagingDevTool',
      );

      // Deserialize messages with extra validation
      try {
        final List<dynamic> decodedList = json.decode(messagesJson);
        developer.log(
          '[LoadMessages] Raw decoded list size: ${decodedList.length}',
          name: 'FirebaseMessagingDevTool',
        );

        // Check for duplicate message IDs
        final Set<String> messageIds = {};
        final List<dynamic> uniqueJsonList = [];

        for (final jsonItem in decodedList) {
          final String? messageId = jsonItem['messageId'] as String?;
          if (messageId != null && !messageIds.contains(messageId)) {
            messageIds.add(messageId);
            uniqueJsonList.add(jsonItem);
          } else {
            developer.log(
              '[LoadMessages] Found duplicate or null message ID, skipping: ${messageId ?? 'null'}',
              name: 'FirebaseMessagingDevTool',
            );
          }
        }

        developer.log(
          '[LoadMessages] After deduplication: ${uniqueJsonList.length} messages (removed ${decodedList.length - uniqueJsonList.length} duplicates)',
          name: 'FirebaseMessagingDevTool',
        );

        final List<FirebaseMessage> loadedMessages =
            uniqueJsonList
                .map((jsonData) => FirebaseMessage.fromJson(jsonData))
                .toList();

        developer.log(
          '[LoadMessages] Final parsed unique messages: ${loadedMessages.length}',
          name: 'FirebaseMessagingDevTool',
        );

        return loadedMessages;
      } catch (e, stackTrace) {
        developer.log(
          '[LoadMessages] Error during deserialization: $e',
          name: 'FirebaseMessagingDevTool',
          error: e,
          stackTrace: stackTrace,
        );
        // Clear potentially corrupted storage on error
        await forceClearMessageStorage();
        return [];
      }
    } catch (e, stackTrace) {
      developer.log(
        '[LoadMessages] Outer error: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Saves messages to local storage
  static Future<void> saveMessages(
    List<FirebaseMessage> messages, {
    bool isClearing = false,
  }) async {
    // Prevent saving during or immediately after a clear
    if (isClearing) {
      developer.log(
        '[SaveMessages] Skipping save because clear operation is in progress.',
        name: 'FirebaseMessagingDevTool',
      );
      return;
    }

    try {
      // Don't save messages if auto-clear is enabled
      if (isAutoClearEnabled()) {
        developer.log(
          '[SaveMessages] Skipping message save because auto-clear is enabled',
          name: 'FirebaseMessagingDevTool',
        );
        return;
      }

      // First, completely remove the existing messages to ensure we don't mix with old data
      await forceClearMessageStorage();
      developer.log(
        '[SaveMessages] Cleared previous storage data to prevent duplication',
        name: 'FirebaseMessagingDevTool',
      );

      // Extract only unique messages by messageId
      final Map<String, FirebaseMessage> uniqueMessages = {};
      for (final message in messages) {
        if (message.messageId.isNotEmpty) {
          uniqueMessages[message.messageId] = message;
        }
      }

      // Convert unique messages back to list
      final List<FirebaseMessage> deduplicatedMessages =
          uniqueMessages.values.toList();
      developer.log(
        '[SaveMessages] After deduplication: ${deduplicatedMessages.length} messages (removed ${messages.length - deduplicatedMessages.length} duplicates)',
        name: 'FirebaseMessagingDevTool',
      );

      // Encode the deduplicated messages
      final messagesJson = json.encode(
        deduplicatedMessages.map((msg) => msg.originalJson).toList(),
      );

      // For debugging
      developer.log(
        '[SaveMessages] Serialized JSON (first 100 chars): ${messagesJson.substring(0, messagesJson.length > 100 ? 100 : messagesJson.length)}...',
        name: 'FirebaseMessagingDevTool',
      );

      // Save to localStorage
      web.window.localStorage.setItem(messagesStorageKey, messagesJson);

      developer.log(
        '[SaveMessages] Saved ${deduplicatedMessages.length} unique messages to localStorage',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e, stackTrace) {
      developer.log(
        '[SaveMessages] Error saving messages to localStorage: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
