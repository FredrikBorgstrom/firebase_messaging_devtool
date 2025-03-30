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

// Message model to better organize the data
class FirebaseMessage {
  final String messageId;
  final DateTime? sentTime;
  final Map<String, dynamic> notification;
  final Map<String, dynamic> data;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> originalJson;

  FirebaseMessage({
    required this.messageId,
    this.sentTime,
    required this.notification,
    required this.data,
    required this.metadata,
    required this.originalJson,
  });

  factory FirebaseMessage.fromJson(Map<String, dynamic> json) {
    final notification = <String, dynamic>{};
    final data = <String, dynamic>{};
    final metadata = <String, dynamic>{};

    try {
      // Extract notification
      if (json.containsKey('notification') && json['notification'] != null) {
        final notificationData = json['notification'];
        if (notificationData is Map) {
          notification.addAll(Map<String, dynamic>.from(notificationData));
        } else {
          print(
            'Firebase Messaging DevTool: notification is not a Map: $notificationData',
          );
        }
      }

      // Extract data payload
      if (json.containsKey('data') && json['data'] != null) {
        final dataPayload = json['data'];
        if (dataPayload is Map) {
          data.addAll(Map<String, dynamic>.from(dataPayload));
        } else {
          print('Firebase Messaging DevTool: data is not a Map: $dataPayload');
        }
      }

      // Extract metadata (everything that's not notification or data)
      for (final entry in json.entries) {
        if (entry.key != 'notification' && entry.key != 'data') {
          if (entry.key == 'sentTime' && entry.value is String) {
            // Don't add sentTime to metadata as we handle it separately
          } else {
            metadata[entry.key] = entry.value;
          }
        }
      }

      // Parse sentTime if available
      DateTime? sentTime;
      if (json.containsKey('sentTime') && json['sentTime'] != null) {
        try {
          if (json['sentTime'] is String) {
            sentTime = DateTime.parse(json['sentTime'] as String);
          }
        } catch (e) {
          print(
            'Firebase Messaging DevTool: Failed to parse sentTime: ${json['sentTime']}',
          );
          // Leave sentTime as null if parsing fails
        }
      }

      final String messageId = (json['messageId'] as String?) ?? 'unknown';
      print('Firebase Messaging DevTool: Creating message with ID: $messageId');
      print('Firebase Messaging DevTool: notification: $notification');
      print('Firebase Messaging DevTool: data: $data');
      print('Firebase Messaging DevTool: metadata: $metadata');

      return FirebaseMessage(
        messageId: messageId,
        sentTime: sentTime,
        notification: notification,
        data: data,
        metadata: metadata,
        originalJson: json,
      );
    } catch (e) {
      print(
        'Firebase Messaging DevTool: Error in FirebaseMessage.fromJson: $e',
      );
      // Return a fallback message if parsing fails
      return FirebaseMessage(
        messageId: 'error_parsing',
        sentTime: DateTime.now(),
        notification: {'error': 'Failed to parse notification data'},
        data: {'error': 'Failed to parse message data'},
        metadata: {'error': e.toString(), 'json': json.toString()},
        originalJson: json,
      );
    }
  }
}

// The screen that displays the incoming Firebase messages
class MessageDisplayScreen extends StatefulWidget {
  const MessageDisplayScreen({super.key});

  @override
  State<MessageDisplayScreen> createState() => _MessageDisplayScreenState();
}

class _MessageDisplayScreenState extends State<MessageDisplayScreen>
    with SingleTickerProviderStateMixin {
  // List to store the received messages
  final List<FirebaseMessage> _messages = [];
  // Keep track of the subscription to cancel it later
  StreamSubscription<Event>? _eventSubscription;
  // Tab controller for the main tabs
  late TabController _tabController;
  // Setting for message order preference
  bool _showNewestOnTop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Call the async function to set up the listener
    _initServiceListener();
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the widget is disposed
    _eventSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // Async function to wait for the service and set up the listener
  Future<void> _initServiceListener() async {
    // Wait for the VM service connection to become available.
    print('Firebase Messaging DevTool: Setting up event listener...');
    final vmService = await serviceManager.onServiceAvailable;
    print('Firebase Messaging DevTool: VM service is available');

    // Listen for events posted by the debugged application
    _eventSubscription = vmService.onExtensionEvent.listen(
      (event) {
        print(
          'Firebase Messaging DevTool: Received event kind: ${event.extensionKind}',
        );

        if (event.extensionKind == 'ext.firebase_messaging.message') {
          print('Firebase Messaging DevTool: Received firebase message event!');
          try {
            // Assuming the event data is a Map
            final messageData = event.extensionData?.data;
            print('Firebase Messaging DevTool: Message data: $messageData');

            if (messageData != null && messageData is Map) {
              // Convert the data (which might have non-JSON-primitive types)
              // to a JSON-encodable map.
              final jsonEncodableMap = _convertToJsonEncodable(messageData);
              print('Firebase Messaging DevTool: Converted JSON map');

              // Create a message object
              final message = FirebaseMessage.fromJson(jsonEncodableMap);
              print(
                'Firebase Messaging DevTool: Created message object with ID: ${message.messageId}',
              );

              // Use setState to update the UI
              if (mounted) {
                // Check if the widget is still in the tree
                setState(() {
                  // Add message based on user preference setting
                  if (_showNewestOnTop) {
                    _messages.insert(0, message); // Add newest messages first
                  } else {
                    _messages.add(message); // Add newest messages at the end
                  }
                  print(
                    'Firebase Messaging DevTool: Added message to list, total count: ${_messages.length}',
                  );
                });
              }
            } else {
              print(
                'Firebase Messaging DevTool: Message data is null or not a Map: $messageData',
              );
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
    // Detect the current theme brightness for proper styling
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Messages'),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_list), text: 'Messages'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMessagesTab(), _buildSettingsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _messages.clear(); // Clear the message list
          });
        },
        tooltip: 'Clear Messages',
        backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.delete_sweep),
      ),
    );
  }

  Widget _buildMessagesTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages received yet',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Firebase messages will appear here when received',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder:
          (context, index) =>
              _buildMessageCard(_messages[index], index, _messages.length),
    );
  }

  Widget _buildMessageCard(
    FirebaseMessage message,
    int index,
    int totalMessages,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate the display index based on the selected order
    final displayIndex =
        _showNewestOnTop
            ? totalMessages -
                index // For newest on top, newest = 1, 2, 3...
            : index + 1; // For newest at bottom, oldest = 1, 2, 3...

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      color: isDarkMode ? Colors.grey[800] : null,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isDarkMode ? Colors.lightBlue[700] : Colors.blue[700],
                radius: 14,
                child: Text(
                  '$displayIndex',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message ID: ${message.messageId}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.sentTime != null)
                      Text(
                        'Sent: ${_formatDateTime(message.sentTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          initiallyExpanded:
              index == totalMessages - 1, // Expand all messages by default
          iconColor: isDarkMode ? Colors.lightBlue : Colors.blue,
          collapsedIconColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          children: [_buildMessageDetails(message)],
        ),
      ),
    );
  }

  Widget _buildMessageDetails(FirebaseMessage message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table-like layout with columns for each section
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Message Details Column
                  _buildTableColumn('Message Details', Icons.info_outline, [
                    _buildTableRow('Message ID', message.messageId),
                    _buildTableRow(
                      'Received At',
                      _formatDateTime(
                        message.metadata['receivedAt'] != null
                            ? DateTime.parse(
                              message.metadata['receivedAt'] as String,
                            )
                            : DateTime.now(),
                      ),
                    ),
                    if (message.sentTime != null)
                      _buildTableRow(
                        'Sent At',
                        _formatDateTime(message.sentTime!),
                      ),
                  ], flex: 2),

                  // Vertical divider
                  _buildVerticalDivider(isDarkMode),

                  // Notification Column
                  _buildTableColumn(
                    'Notification',
                    Icons.notifications,
                    _buildMapDataRows(message.notification),
                    emptyMessage: 'No notification data',
                    flex: 2,
                  ),

                  // Vertical divider
                  _buildVerticalDivider(isDarkMode),

                  // Data Payload Column
                  _buildTableColumn(
                    'Data Payload',
                    Icons.data_array,
                    _buildMapDataRows(message.data),
                    emptyMessage: 'No data payload',
                    flex: 3,
                  ),

                  // Vertical divider
                  _buildVerticalDivider(isDarkMode),

                  // Metadata Column
                  _buildTableColumn(
                    'Metadata',
                    Icons.label,
                    _buildMapDataRows(
                      message.metadata,
                      excludeKeys: ['receivedAt'],
                    ),
                    emptyMessage: 'No additional metadata',
                    flex: 2,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // View Raw JSON section - kept as is
          ExpansionTile(
            title: Row(
              children: [
                const Icon(Icons.code, size: 20),
                const SizedBox(width: 8),
                const Text('View Raw JSON'),
              ],
            ),
            iconColor: Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context).colorScheme.primary,
            initiallyExpanded: false, // Expand Raw JSON by default
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]
                          : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4.0),
                ),
                width: double.infinity,
                child: SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(message.originalJson),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDarkMode) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildTableColumn(
    String title,
    IconData icon,
    List<Widget> rows, {
    String? emptyMessage,
    int flex = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column Header
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 8.0,
              ),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color:
                        isDarkMode ? Colors.lightBlueAccent : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Column Data
            if (rows.isEmpty && emptyMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(String key, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMapDataRows(
    Map<String, dynamic> data, {
    List<String>? excludeKeys,
  }) {
    final List<Widget> rows = [];

    for (final entry in data.entries) {
      // Skip excluded keys
      if (excludeKeys != null && excludeKeys.contains(entry.key)) {
        continue;
      }

      // Convert the value to a displayable format
      if (entry.value is Map) {
        rows.add(
          _buildNestedMapRow(entry.key, entry.value as Map<dynamic, dynamic>),
        );
      } else if (entry.value is List) {
        rows.add(_buildNestedListRow(entry.key, entry.value as List<dynamic>));
      } else {
        // Simple key-value row
        rows.add(_buildTableRow(entry.key, entry.value?.toString() ?? 'null'));
      }
    }

    return rows;
  }

  Widget _buildNestedMapRow(String key, Map<dynamic, dynamic> map) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable header
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                key,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
                ),
              ),
              subtitle: Text(
                '${map.length} items',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(left: 16.0),
              iconColor: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
              textColor: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
              initiallyExpanded: false, // Expand nested maps by default
              children: [
                // Nested items
                for (final item in map.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.key}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child:
                              item.value is Map || item.value is List
                                  ? Text(
                                    item.value is Map ? '{...}' : '[...]',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color:
                                          isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                    ),
                                  )
                                  : Text(
                                    item.value?.toString() ?? 'null',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[800],
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedListRow(String key, List<dynamic> list) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable header
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                key,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
                ),
              ),
              subtitle: Text(
                '${list.length} items',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(left: 16.0),
              iconColor: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
              textColor: isDarkMode ? Colors.lightBlue[300] : Colors.blue[700],
              initiallyExpanded: false, // Expand nested lists by default
              children: [
                // Nested items
                for (int i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[$i]: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child:
                              list[i] is Map || list[i] is List
                                  ? Text(
                                    list[i] is Map ? '{...}' : '[...]',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color:
                                          isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                    ),
                                  )
                                  : Text(
                                    list[i]?.toString() ?? 'null',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[800],
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firebase Messaging DevTool Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // Message Count
          Card(
            color: isDarkMode ? Colors.grey[800] : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox,
                    color: isDarkMode ? Colors.lightBlue : Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages Received',
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_messages.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Message Order Preference
          Card(
            color: isDarkMode ? Colors.grey[800] : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Display Options',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Show newest messages on top',
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                      Switch(
                        value: _showNewestOnTop,
                        onChanged: (value) {
                          setState(() {
                            _showNewestOnTop = value;
                            // Reverse the current message list to match the new order preference
                            if (_messages.isNotEmpty) {
                              final reversedMessages =
                                  _messages.reversed.toList();
                              _messages.clear();
                              _messages.addAll(reversedMessages);
                            }
                          });
                        },
                        activeColor:
                            isDarkMode ? Colors.lightBlue : Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Card(
            color: isDarkMode ? Colors.grey[800] : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear All Messages'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About
          Card(
            color: isDarkMode ? Colors.grey[800] : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firebase Messaging DevTool displays Firebase Cloud Messaging (FCM) events received by your app in real-time for easier debugging.',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version: 0.1.0',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}
