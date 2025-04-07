import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_devtool/firebase_messaging_devtool.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Firebase configuration placeholder - replace with your actual config
const firebaseOptions = FirebaseOptions(
  apiKey: 'your-api-key',
  appId: 'your-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
);

String _getDefaultDeviceId() {
  return Platform.isAndroid ? 'android-device' : 'ios-device';
}

String _getDefaultDeviceName() {
  return Platform.isAndroid ? 'Android Device' : 'iOS Device';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  // Request permission for notifications (iOS)
  await FirebaseMessaging.instance.requestPermission();

  // Get device information
  final deviceId = const String.fromEnvironment(
    'FLUTTER_DEVICE_ID',
    defaultValue: 'unknown',
  );
  final deviceName = const String.fromEnvironment(
    'FLUTTER_DEVICE_NAME',
    defaultValue: 'Unknown Device',
  );

  // Set up the message handler with DevTools integration
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    // Forward the message to DevTools for inspection
    if (kDebugMode) {
      await postFirebaseMessageToDevTools(message);
    }

    // Continue with your normal message handling...
    print('Received message: ${message.notification?.title}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Messaging DevTool Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _getToken();
  }

  Future<void> _getToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    setState(() {
      _token = token;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Messaging DevTool Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Firebase Cloud Messaging is set up with DevTools integration!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your FCM Token:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _token ?? 'Loading token...',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Send a test message to this device using Firebase Console \n'
                'and watch it appear in DevTools!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
