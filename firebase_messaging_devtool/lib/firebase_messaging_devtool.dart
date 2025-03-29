import 'dart:developer' as developer;

/// The event kind used to send Firebase message data to the DevTools extension.
///
/// Users of this package should not need to reference this directly if using
/// the [postFirebaseMessageToDevTools] helper function.
const String firebaseMessagingDevToolsEventKind =
    'ext.firebase_messaging.message';

/// Posts Firebase message data to the Firebase Messaging DevTools extension.
///
/// This function simplifies sending message data from your application to the
/// DevTools extension by handling the necessary `dart:developer` `postEvent` call.
///
/// Args:
///   [messageData]: A `Map<String, dynamic>` containing the Firebase message
///                  payload you want to display in DevTools. Ensure the map
///                  contains JSON-encodable values (String, num, bool, null,
///                  List<JSON-encodable>, Map<String, JSON-encodable>).
///                  Complex objects should be converted beforehand.
///
/// Example:
/// ```dart
/// import 'package:firebase_messaging/firebase_messaging.dart';
/// import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';
///
/// void handleMessage(RemoteMessage message) {
///   final Map<String, dynamic> dataForDevTools = {
///     'messageId': message.messageId,
///     'sentTime': message.sentTime?.toIso8601String(),
///     'data': message.data,
///     'notification': message.notification != null ? {
///       'title': message.notification!.title,
///       'body': message.notification!.body,
///     } : null,
///     // Add other relevant fields...
///   };
///
///   postFirebaseMessageToDevTools(dataForDevTools);
/// }
/// ```
void postFirebaseMessageToDevTools(Map<String, dynamic> messageData) {
  // TODO: Consider adding checks here to ensure messageData is JSON-encodable
  // before sending, although postEvent might handle non-serializable data gracefully
  // by converting to strings.
  developer.postEvent(firebaseMessagingDevToolsEventKind, messageData);
}
