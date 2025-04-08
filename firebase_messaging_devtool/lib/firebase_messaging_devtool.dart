import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// The event kind used to send Firebase message data to the DevTools extension.
///
/// Users of this package should not need to reference this directly if using
/// the [postFirebaseMessageToDevTools] helper function.
const String firebaseMessagingDevToolsEventKind = 'FirebaseMessage';

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
///     if (kDebugMode) {
///       postFirebaseMessageToDevTools(message);
///     }
///   });
/// }
/// ```
Future<void> postFirebaseMessageToDevTools(RemoteMessage message) async {
  if (!kDebugMode) return;
  try {
    // Get device information using device_info_plus
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = 'unknown-device';
    String deviceName = 'Unknown Device';

    if (kIsWeb) {
      // Web platform
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      deviceId = 'web-${webInfo.browserName.toString().toLowerCase()}';
      deviceName = '${webInfo.browserName} on ${webInfo.platform}';
    } else if (Platform.isAndroid) {
      // Android platform
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      // iOS platform
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      deviceName = iosInfo.utsname.machine;
    } else if (Platform.isMacOS) {
      // macOS platform
      final macOsInfo = await deviceInfoPlugin.macOsInfo;
      deviceId = macOsInfo.systemGUID ?? 'unknown-macos';
      deviceName = '${macOsInfo.computerName} (macOS ${macOsInfo.osRelease})';
    } else if (Platform.isWindows) {
      // Windows platform
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      deviceId = windowsInfo.deviceId;
      deviceName = '${windowsInfo.computerName} (Windows)';
    } else if (Platform.isLinux) {
      // Linux platform
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      deviceId = linuxInfo.machineId ?? 'unknown-linux';
      deviceName = linuxInfo.prettyName;
    } else {
      // Fallback for other platforms
      deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      deviceName = 'Unknown Platform';
    }

    final messageData = {
      'notification': message.notification?.toMap(),
      'data': message.data,
      'from': message.from,
      'messageId': message.messageId,
      'sentTime': message.sentTime?.millisecondsSinceEpoch,
      'ttl': message.ttl,
      'collapseKey': message.collapseKey,
      'deviceId': deviceId,
      'deviceName': deviceName,
    };

    developer.postEvent(firebaseMessagingDevToolsEventKind, messageData);
    developer.log(
      'Firebase Messaging DevTool: Message posted to DevTools with event kind: $firebaseMessagingDevToolsEventKind',
      name: 'FirebaseMessagingDevTool',
    );
    developer.log(
      'Device info: $deviceName ($deviceId)',
      name: 'FirebaseMessagingDevTool',
    );
  } catch (e) {
    developer.log(
      'Error posting message to DevTools: $e',
      name: 'FirebaseMessagingDevTool',
      error: e,
    );
  }
}
