import 'dart:async'; // Import for StreamSubscription
import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' show Event; // Import for Event

void main() {
  runApp(const FirebaseMessagingDevToolsExtension());
}

// The main extension widget wrapper
class FirebaseMessagingDevToolsExtension extends StatelessWidget {
  const FirebaseMessagingDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    // The DevToolsExtension widget provides services available to extensions
    return const DevToolsExtension(
      child: MessageDisplayScreen(), // Your extension's UI
    );
  }
}

// The screen that displays the incoming Firebase messages
class MessageDisplayScreen extends StatefulWidget {
  const MessageDisplayScreen({super.key});

  @override
  State<MessageDisplayScreen> createState() => _MessageDisplayScreenState();
}

class _MessageDisplayScreenState extends State<MessageDisplayScreen> {
  // List to store the received messages
  final List<Map<String, dynamic>> _messages = [];
  // Keep track of the subscription to cancel it later
  StreamSubscription<Event>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    // Call the async function to set up the listener
    _initServiceListener();
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the widget is disposed
    _eventSubscription?.cancel();
    super.dispose();
  }

  // Async function to wait for the service and set up the listener
  Future<void> _initServiceListener() async {
    // Wait for the VM service connection to become available.
    final vmService = await serviceManager.onServiceAvailable;

    // Listen for events posted by the debugged application
    _eventSubscription = vmService.onExtensionEvent.listen(
      (event) {
        if (event.extensionKind == 'ext.firebase_messaging.message') {
          try {
            // Assuming the event data is a Map
            final messageData = event.extensionData?.data;
            if (messageData != null && messageData is Map) {
              // Convert the data (which might have non-JSON-primitive types)
              // to a JSON-encodable map.
              final jsonEncodableMap = _convertToJsonEncodable(messageData);

              // Use setState to update the UI
              if (mounted) {
                // Check if the widget is still in the tree
                setState(() {
                  _messages.insert(
                    0,
                    jsonEncodableMap,
                  ); // Add newest messages first
                });
              }
            }
          } catch (e) {
            // Log errors during message processing
            // Consider showing an error in the DevTools UI as well
            print('Error processing Firebase message event: $e');
            print('Received data: ${event.extensionData?.data}');
          }
        }
      },
      onError: (error) {
        // Handle stream errors
        print('Error listening to extension events: $error');
      },
      onDone: () {
        // Handle stream closing (optional)
        print('Extension event stream closed.');
      },
    );

    // Example: Post an event *from* the extension to the app (if needed)
    // You might use this for requesting data or controlling the app
    // serviceManager.postEventToClient(
    //   'ext.firebase_messaging.command', // Use your specific event kind
    //   {'command': 'requestData'},
    // );
  }

  // Helper to convert potentially complex map data to something JSON encodable
  Map<String, dynamic> _convertToJsonEncodable(
    Map<dynamic, dynamic> originalMap,
  ) {
    final Map<String, dynamic> newMap = {};
    originalMap.forEach((key, value) {
      final String stringKey = key.toString();
      if (value == null || value is String || value is num || value is bool) {
        newMap[stringKey] = value;
      } else if (value is Map) {
        newMap[stringKey] = _convertToJsonEncodable(
          value,
        ); // Recurse for nested maps
      } else if (value is List) {
        newMap[stringKey] = _convertListToJsonEncodable(value); // Handle lists
      } else {
        newMap[stringKey] = value.toString(); // Convert other types to string
      }
    });
    return newMap;
  }

  List<dynamic> _convertListToJsonEncodable(List<dynamic> originalList) {
    final List<dynamic> newList = [];
    for (var item in originalList) {
      if (item == null || item is String || item is num || item is bool) {
        newList.add(item);
      } else if (item is Map) {
        newList.add(_convertToJsonEncodable(item)); // Recurse for maps in lists
      } else if (item is List) {
        newList.add(
          _convertListToJsonEncodable(item),
        ); // Recurse for lists in lists
      } else {
        newList.add(item.toString()); // Convert other types to string
      }
    }
    return newList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Messages'),
        backgroundColor: Colors.blueGrey[700], // Darker theme for DevTools
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          // Use JsonEncoder for pretty printing
          const encoder = JsonEncoder.withIndent('  ');
          final prettyPrintedJson = encoder.convert(message);

          return Card(
            margin: const EdgeInsets.all(8.0),
            color: Colors.blueGrey[800], // Darker card background
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SelectableText(
                prettyPrintedJson,
                style: const TextStyle(
                  fontFamily: 'monospace', // Use monospace for JSON
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _messages.clear(); // Clear the message list
          });
        },
        tooltip: 'Clear Messages',
        backgroundColor: Colors.blue,
        child: const Icon(Icons.delete_sweep),
      ),
    );
  }
}
