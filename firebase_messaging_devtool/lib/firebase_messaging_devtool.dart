import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// The event kind used to send Firebase message data to the DevTools extension.
///
/// Users of this package should not need to reference this directly if using
/// the [postFirebaseMessageToDevTools] helper function.
const String firebaseMessagingDevToolsEventKind =
    'ext.firebase_messaging.message';

/// Posts a Firebase message to the Firebase Messaging DevTools extension.
///
/// This function simplifies sending Firebase Cloud Messages from your application
/// to the DevTools extension by handling all the necessary conversion and event posting.
///
/// Args:
///   [message]: The Firebase `RemoteMessage` object received by your app.
///              The function will automatically extract all relevant information
///              and convert it to a format suitable for display in DevTools.
///
/// Example:
/// ```dart
/// import 'package:firebase_messaging/firebase_messaging.dart';
/// import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';
///
/// void setupFirebaseMessagingListener() {
///   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
///     // Just pass the RemoteMessage directly to DevTools
///     postFirebaseMessageToDevTools(message);
///
///     // Continue with your normal message handling...
///   });
/// }
/// ```
void postFirebaseMessageToDevTools(RemoteMessage message) {
  // Debug log
  developer.log(
    'Firebase Messaging DevTool: Sending message to DevTools',
    name: 'FirebaseMessagingDevTool',
    error: {
      'messageId': message.messageId,
      'notification': message.notification?.toMap(),
      'data': message.data,
    },
  );

  try {
    // Extract all useful information from the RemoteMessage
    final Map<String, dynamic> messageData = {
      // Basic message identification
      'messageId': message.messageId,
      'sentTime': message.sentTime?.toIso8601String(),

      // Device identifier - use the actual platform information
      'deviceId':
          '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      'deviceName': Platform.localHostname,

      // Data payload (custom key-value pairs)
      'data': message.data,

      // Notification details
      'notification':
          message.notification != null
              ? {
                'title': message.notification!.title,
                'body': message.notification!.body,
                'android':
                    message.notification!.android != null
                        ? {
                          'channelId': message.notification!.android!.channelId,
                          'clickAction':
                              message.notification!.android!.clickAction,
                          'color': message.notification!.android!.color,
                          'count': message.notification!.android!.count,
                          'imageUrl': message.notification!.android!.imageUrl,
                          'link': message.notification!.android!.link,
                          // Convert enum to string to avoid serialization issues
                          'priority':
                              message.notification!.android!.priority
                                  .toString(),
                          'smallIcon': message.notification!.android!.smallIcon,
                          'sound': message.notification!.android!.sound,
                          'tag': message.notification!.android!.tag,
                          'ticker': message.notification!.android!.ticker,
                          // Convert enum to string to avoid serialization issues
                          'visibility':
                              message.notification!.android!.visibility
                                  .toString(),
                        }
                        : null,
                'apple':
                    message.notification!.apple != null
                        ? {
                          'badge': message.notification!.apple!.badge,
                          'subtitle': message.notification!.apple!.subtitle,
                          'sound':
                              message.notification!.apple!.sound != null
                                  ? {
                                    'critical':
                                        message
                                            .notification!
                                            .apple!
                                            .sound!
                                            .critical,
                                    'name':
                                        message
                                            .notification!
                                            .apple!
                                            .sound!
                                            .name,
                                    'volume':
                                        message
                                            .notification!
                                            .apple!
                                            .sound!
                                            .volume,
                                  }
                                  : null,
                          'imageUrl': message.notification!.apple!.imageUrl,
                        }
                        : null,
                'web':
                    message.notification!.web != null
                        ? {
                          'analyticsLabel':
                              message.notification!.web!.analyticsLabel,
                          'image': message.notification!.web!.image,
                          'link': message.notification!.web!.link,
                        }
                        : null,
              }
              : null,

      // Message metadata
      'category': message.category,
      'collapseKey': message.collapseKey,
      'contentAvailable': message.contentAvailable,
      'from': message.from,
      'messageType': message.messageType,
      'mutableContent': message.mutableContent,
      'threadId': message.threadId,
      'ttl': message.ttl,

      // Timestamp information
      'receivedAt':
          DateTime.now().toIso8601String(), // When the app received the message
    };

    print(
      'Firebase Messaging DevTool: Posting event with kind: $firebaseMessagingDevToolsEventKind',
    );
    developer.postEvent(firebaseMessagingDevToolsEventKind, messageData);
    print('Firebase Messaging DevTool: Event posted successfully');
  } catch (e) {
    print('Firebase Messaging DevTool: Error posting event: $e');

    // Try to send a simplified version of the message if the detailed version fails
    try {
      // Create a simplified version with just the basic fields
      final Map<String, dynamic> simplifiedMessage = {
        'messageId': message.messageId,
        'sentTime': message.sentTime?.toIso8601String(),
        'data': message.data,
        'notification':
            message.notification != null
                ? {
                  'title': message.notification!.title,
                  'body': message.notification!.body,
                }
                : null,
        'error': 'Original message contained non-serializable types: $e',
        'receivedAt': DateTime.now().toIso8601String(),
      };

      print('Firebase Messaging DevTool: Trying simplified message instead');
      developer.postEvent(
        firebaseMessagingDevToolsEventKind,
        simplifiedMessage,
      );
      print('Firebase Messaging DevTool: Simplified message sent successfully');
    } catch (fallbackError) {
      print(
        'Firebase Messaging DevTool: Even simplified message failed: $fallbackError',
      );
    }
  }
}
