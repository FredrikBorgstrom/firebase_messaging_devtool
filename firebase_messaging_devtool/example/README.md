# Firebase Messaging DevTool Example

This example demonstrates how to integrate the Firebase Messaging DevTool package into a Flutter application.

## Getting Started

1. Update the Firebase configuration in `lib/main.dart` with your own Firebase project details:

```dart
const firebaseOptions = FirebaseOptions(
  apiKey: 'your-api-key',
  appId: 'your-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
);
```

2. Run the app:

```bash
flutter run
```

3. Open DevTools while the app is running (either via VS Code, Android Studio, or by running `flutter devtools` in a separate terminal and connecting to the app).

4. Navigate to the Firebase Messaging extension in DevTools.

5. Send a test message to your device using Firebase Console, and watch it appear in DevTools.

## Implementation Details

The integration with Firebase Messaging DevTool is simple:

```dart
// Set up the message handler with DevTools integration
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Forward the message to DevTools for inspection
  postFirebaseMessageToDevTools(message);
  
  // Continue with your normal message handling...
  print('Received message: ${message.notification?.title}');
});
```

That's it! Just call `postFirebaseMessageToDevTools(message)` whenever you receive a message and want to inspect it in DevTools. 