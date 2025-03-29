<!--
For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Firebase Messaging DevTool

A Flutter DevTools extension that displays Firebase Cloud Messaging (FCM) events in real-time, making it easier to debug and develop push notification functionality in your Flutter applications.

## Features

* **Real-time Monitoring**: View incoming FCM messages sent to your app as they arrive
* **Structured Viewing**: Messages are formatted as pretty-printed JSON for easy inspection
* **Message History**: Track all received messages during your debug session
* **Clear Functionality**: Reset the message list when needed
* **Simple Integration**: Just add the package and a single line of code to your message handlers

## Screenshots

![Firebase Messaging DevTool Extension Screenshot](https://github.com/abcx3/firebase_messaging_devtool/raw/main/screenshots/extension_screenshot.png)

## Setup

1. **Add Dependency**: Add this package as a `dev_dependency` in your application's `pubspec.yaml`:

   ```yaml
   dev_dependencies:
     firebase_messaging_devtool: ^0.0.1
     # ... other dev_dependencies
   ```

2. **Enable the Extension**: Add the extension configuration to your `pubspec.yaml`:

   ```yaml
   # Add this at the top level, not nested under dependencies
   devtools:
     extensions:
       - firebase_messaging_devtool
   ```

3. **Run `flutter pub get`**

## Usage

To send Firebase message data from your application to this DevTools extension:

1. **Import the helper function**:

   ```dart
   import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';
   ```

2. **Add the function call** to your Firebase message handlers:

   ```dart
   import 'package:firebase_messaging/firebase_messaging.dart';
   import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';

   void setupFirebaseMessagingListener() {
     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       print('Foreground message received: ${message.messageId}');

       // Prepare the data you want to send to DevTools
       final Map<String, dynamic> dataForDevTools = {
         'messageId': message.messageId,
         'sentTime': message.sentTime?.toIso8601String(),
         'from': message.from,
         'data': message.data,
         'notification': message.notification != null ? {
           'title': message.notification!.title,
           'body': message.notification!.body,
         } : null,
         // Add any other fields you want to display
       };

       // Send the message data to the extension with one line!
       postFirebaseMessageToDevTools(dataForDevTools);

       // Continue with your normal message handling...
     });

     // Don't forget to also add to onBackgroundMessage handler if applicable
   }
   ```

3. **View messages in DevTools**:
   * Run your application in debug mode
   * Open Flutter DevTools 
   * Navigate to the "firebase_messaging_devtool" tab
   * Enable the extension if prompted
   * Trigger FCM messages to your app and watch them appear in real-time

## Configuring Firebase Cloud Messaging

This extension works with any properly configured Firebase Cloud Messaging implementation. If you haven't set up FCM yet, follow these steps:

1. Set up a Firebase project and add your Flutter app following the [FlutterFire documentation](https://firebase.flutter.dev/docs/overview)
2. Add the `firebase_messaging` package to your app
3. Configure platform-specific settings (notification channels for Android, capabilities for iOS, etc.)
4. Request notification permissions in your app
5. Set up your message handlers where you'll call `postFirebaseMessageToDevTools`

## Testing with FCM messages

To test your Firebase messages and verify the extension is working:

1. Use the Firebase Console to send test messages
2. Use the Firebase CLI to send messages programmatically
3. Set up a simple backend with the Firebase Admin SDK to send test messages
4. For local testing, use the `FirebaseMessaging.onMessage` stream in combination with a local notification package

## Troubleshooting

**Extension not appearing in DevTools?**
* Ensure the package is in `dev_dependencies` not `dependencies`
* Verify you've added the `devtools: extensions:` section to your `pubspec.yaml`
* Check that you're running in debug mode
* Restart DevTools completely

**Messages not showing up?**
* Verify your FCM configuration is working correctly by checking logs
* Ensure you're calling `postFirebaseMessageToDevTools` with valid data
* Check that you've enabled the extension in DevTools when prompted

## Contributing

Contributions to improve the extension are welcome! Please feel free to submit issues or pull requests to the [GitHub repository](https://github.com/abcx3/firebase_messaging_devtool).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
