<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Firebase Messaging DevTool

A Flutter DevTools extension to display Firebase Messaging (FCM) events received by a debugged application.

## Features

*   Displays incoming FCM messages sent from your app in real-time within a dedicated DevTools tab.
*   Formats message data as pretty-printed JSON for easy inspection.
*   Provides a button to clear the displayed message list.

## Setup

1.  **Add Dependency:** Add this package (`firebase_messaging_devtool`) as a `dev_dependency` in your application's `pubspec.yaml`:

    ```yaml
    dev_dependencies:
      firebase_messaging_devtool: ^0.0.1 # Use the actual version
      # ... other dev_dependencies
    ```

2.  **Run `flutter pub get`**.

## Usage

To send Firebase message data from your application to this DevTools extension, simply call the `postFirebaseMessageToDevTools` function provided by this package whenever your app handles an FCM message (e.g., via `FirebaseMessaging.onMessage`, `onBackgroundMessage`, etc.).

**Steps:**

1.  **Import the helper function:**

    ```dart
    import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';
    ```

2.  **Prepare your message data:** Create a `Map<String, dynamic>` containing the relevant information from the Firebase `RemoteMessage` that you want to inspect in DevTools. Ensure the values in the map are JSON-encodable (String, num, bool, null, List, Map<String, ...>). Complex objects within the message might need to be converted to a suitable format first.

3.  **Call the function:** Pass your prepared map to `postFirebaseMessageToDevTools`.

**Example Implementation:**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart'; // Import the helper

// Example integration with FirebaseMessaging.onMessage
void setupFirebaseMessagingListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message received: ${message.messageId}');

    // Prepare the data you want to send to DevTools
    final Map<String, dynamic> dataForDevTools = {
      'messageId': message.messageId,
      'sentTime': message.sentTime?.toIso8601String(), // Convert DateTime
      'from': message.from,
      'category': message.category,
      'collapseKey': message.collapseKey,
      'contentAvailable': message.contentAvailable,
      'data': message.data, // The data payload
      'notification': message.notification != null ? {
        'title': message.notification!.title,
        'body': message.notification!.body,
        // Add other relevant notification fields if needed
      } : null,
      'messageType': message.messageType,
      'ttl': message.ttl,
      // Add any other relevant fields from RemoteMessage
    };

    // Send the message data to the DevTools extension using the helper
    postFirebaseMessageToDevTools(dataForDevTools);

    // Your regular foreground message handling logic here...
  });

  // Remember to also call postFirebaseMessageToDevTools in your
  // onBackgroundMessage handler if you have one.
}

// Call this setup function when your app initializes
// setupFirebaseMessagingListener();

```

4.  **Run your application in debug mode.**
5.  **Open Flutter DevTools.** You should see a new tab with the message icon (or the icon you configure in `config.yaml`) labeled "firebase_messaging_devtool".
6.  **Enable the extension** when prompted by DevTools.
7.  Trigger FCM messages to your application. They should appear in the extension tab.

## Issue Tracker

Please report any issues or feature requests at: [TODO: Add your issue tracker URL here]

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
