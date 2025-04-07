import 'dart:async'; // Import for StreamSubscription
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' show Event; // Import for Event
import 'package:web/web.dart' as web; // Use package:web instead of dart:html

// Storage keys - using namespaced keys to avoid conflicts
const String _storageKeyPrefix = 'com.firebase_messaging_devtool.';
const String _messagesStorageKey = '${_storageKeyPrefix}messages';
const String _showNewestOnTopKey = '${_storageKeyPrefix}show_newest_on_top';
const String _autoClearOnReloadKey = '${_storageKeyPrefix}auto_clear_on_reload';

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
      developer.log(
        'Converting message from JSON: ${json.keys.join(', ')}',
        name: 'FirebaseMessagingDevTool',
      );

      // Extract notification
      if (json.containsKey('notification') && json['notification'] != null) {
        final notificationData = json['notification'];
        if (notificationData is Map) {
          notification.addAll(Map<String, dynamic>.from(notificationData));
          developer.log(
            'Extracted notification fields: ${notification.keys.join(', ')}',
            name: 'FirebaseMessagingDevTool',
          );
        } else {
          developer.log(
            'Notification is not a Map: $notificationData',
            name: 'FirebaseMessagingDevTool',
          );
        }
      }

      // Extract data payload
      if (json.containsKey('data') && json['data'] != null) {
        final dataPayload = json['data'];
        if (dataPayload is Map) {
          data.addAll(Map<String, dynamic>.from(dataPayload));
          developer.log(
            'Extracted data payload fields: ${data.keys.join(', ')}',
            name: 'FirebaseMessagingDevTool',
          );
        } else {
          developer.log(
            'Data payload is not a Map: $dataPayload',
            name: 'FirebaseMessagingDevTool',
          );
        }
      }

      // Extract metadata (everything that's not notification or data)
      for (final entry in json.entries) {
        if (entry.key != 'notification' && entry.key != 'data') {
          if (entry.key == 'sentTime') {
            // Handle sentTime specially below
          } else {
            metadata[entry.key] = entry.value;
          }
        }
      }

      developer.log(
        'Extracted metadata fields: ${metadata.keys.join(', ')}',
        name: 'FirebaseMessagingDevTool',
      );

      // Parse sentTime if available
      DateTime? sentTime;
      if (json.containsKey('sentTime') && json['sentTime'] != null) {
        try {
          final sentTimeValue = json['sentTime'];
          if (sentTimeValue is String) {
            sentTime = DateTime.parse(sentTimeValue);
          } else if (sentTimeValue is int) {
            sentTime = DateTime.fromMillisecondsSinceEpoch(sentTimeValue);
          }

          developer.log(
            'Parsed sentTime: $sentTime from value type: ${sentTimeValue.runtimeType}',
            name: 'FirebaseMessagingDevTool',
          );
        } catch (e) {
          developer.log(
            'Failed to parse sentTime: ${json['sentTime']}',
            name: 'FirebaseMessagingDevTool',
            error: e,
          );
          // Leave sentTime as null if parsing fails
        }
      }

      final String messageId = (json['messageId'] as String?) ?? 'unknown';
      developer.log(
        'Creating message with ID: $messageId',
        name: 'FirebaseMessagingDevTool',
      );

      return FirebaseMessage(
        messageId: messageId,
        sentTime: sentTime,
        notification: notification,
        data: data,
        metadata: metadata,
        originalJson: json,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error in FirebaseMessage.fromJson: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
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
  // Setting for auto-clear on reload
  bool _autoClearOnReload = false;
  // Device identifier
  String _deviceIdentifier = '';
  // Flag to prevent saves during clear operations
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // --- CRITICAL: Apply auto-clear BEFORE anything else ---
    _applyAutoClearIfNeededAtStartup();

    // Now load settings (which might include the auto-clear state itself)
    _loadSettings();
    _setDeviceIdentifier();
    _initServiceListener();
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the widget is disposed
    _eventSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Checks the auto-clear setting AT STARTUP and forces storage clear if needed.
  /// This runs before any other loading logic.
  void _applyAutoClearIfNeededAtStartup() {
    try {
      final autoClearOnReloadStr = web.window.localStorage.getItem(
        _autoClearOnReloadKey,
      ); // Use web.window
      developer.log(
        '[Startup Check] Auto-clear setting from storage: $autoClearOnReloadStr',
        name: 'FirebaseMessagingDevTool',
      );
      if (autoClearOnReloadStr == 'true') {
        developer.log(
          '[Startup Check] Auto-clear is TRUE. Forcing message clear NOW.',
          name: 'FirebaseMessagingDevTool',
        );
        _forceClearMessageStorage(); // Clear storage

        // --- Explicitly clear in-memory list as well ---
        _messages.clear();
        developer.log(
          '[Startup Check] Cleared in-memory _messages list.',
          name: 'FirebaseMessagingDevTool',
        );
        // --- End ---
      } else {
        developer.log(
          '[Startup Check] Auto-clear is FALSE or not set. Messages will be loaded if present.',
          name: 'FirebaseMessagingDevTool',
        );
      }
    } catch (e) {
      developer.log(
        'Error during startup auto-clear check: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      // Load settings state from localStorage using package:web
      final showNewestOnTopStr = web.window.localStorage.getItem(
        _showNewestOnTopKey,
      );
      final autoClearOnReloadStr = web.window.localStorage.getItem(
        _autoClearOnReloadKey,
      );

      // Update state variables (without triggering immediate clears)
      if (mounted) {
        // Ensure the widget is still mounted
        setState(() {
          _showNewestOnTop = showNewestOnTopStr == 'true';
          _autoClearOnReload = autoClearOnReloadStr == 'true';
        });
      }

      developer.log(
        'Settings loaded: showNewest=$_showNewestOnTop, autoClear=$_autoClearOnReload',
        name: 'FirebaseMessagingDevTool',
      );

      // Load messages ONLY if auto-clear is currently disabled
      if (!_autoClearOnReload) {
        _loadMessages();
      } else {
        developer.log(
          'Skipping _loadMessages because auto-clear is enabled.',
          name: 'FirebaseMessagingDevTool',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error loading settings: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Forcefully clears message data using multiple methods, prioritizing standard web APIs.
  /// Does NOT call setState directly for memory clear anymore, handled by caller.
  Future<void> _forceClearMessageStorage() async {
    // Make async
    final key = _messagesStorageKey;
    developer.log(
      '[Force Clear] Attempting web API clear for key: $key',
      name: 'FirebaseMessagingDevTool',
    );
    bool cleared = false;
    try {
      // --- Log value BEFORE attempting clear ---
      var valueBefore = web.window.localStorage.getItem(key); // Use web API
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
        // --- Method 1: Standard web API removeItem ---
        web.window.localStorage.removeItem(key); // Use web API
        developer.log(
          '[Force Clear] Executed web localStorage.removeItem("$key")',
          name: 'FirebaseMessagingDevTool',
        );
        var valueAfterRemove = web.window.localStorage.getItem(
          key,
        ); // Use web API
        developer.log(
          '[Force Clear] Value immediately AFTER removeItem: "$valueAfterRemove"',
          name: 'FirebaseMessagingDevTool',
        );

        // --- Verification 1 ---
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

          // --- Method 2: Standard web API setItem to empty array ---
          web.window.localStorage.setItem(key, '[]'); // Use web API
          developer.log(
            '[Force Clear] Executed web localStorage.setItem("$key", "[]")',
            name: 'FirebaseMessagingDevTool',
          );
          var valueAfterSetEmpty = web.window.localStorage.getItem(
            key,
          ); // Use web API
          developer.log(
            '[Force Clear] Value immediately AFTER setItem([]): "$valueAfterSetEmpty"',
            name: 'FirebaseMessagingDevTool',
          );

          // --- Verification 2 ---
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

  void _loadMessages() {
    developer.log(
      '[LoadMessages] Starting. AutoClear=$_autoClearOnReload',
      name: 'FirebaseMessagingDevTool',
    );
    try {
      // Double-check auto-clear just in case
      if (_autoClearOnReload) {
        developer.log(
          '[LoadMessages] Auto-clear is ON. Aborting load.',
          name: 'FirebaseMessagingDevTool',
        );
        // Ensure in-memory is clear too if we reach here unexpectedly
        if (_messages.isNotEmpty && mounted) {
          setState(() => _messages.clear());
        }
        return;
      }

      final messagesJson = web.window.localStorage.getItem(
        _messagesStorageKey,
      ); // Use web.window
      if (messagesJson != null && messagesJson.isNotEmpty) {
        developer.log(
          '[LoadMessages] Found JSON string in storage: ${messagesJson.substring(0, (messagesJson.length > 100 ? 100 : messagesJson.length))}...',
          name: 'FirebaseMessagingDevTool',
        );
        // --- Deserialize and Update State ---
        try {
          final List<dynamic> decodedList = json.decode(messagesJson);
          final List<FirebaseMessage> loadedMessages =
              decodedList
                  .map((jsonData) => FirebaseMessage.fromJson(jsonData))
                  .toList();

          developer.log(
            '[LoadMessages] Parsed ${loadedMessages.length} messages from storage.',
            name: 'FirebaseMessagingDevTool',
          );

          if (mounted) {
            setState(() {
              developer.log(
                '[LoadMessages] Inside setState. Current _messages count: ${_messages.length}. Clearing now...',
                name: 'FirebaseMessagingDevTool',
              );
              _messages.clear(); // Clear INSIDE setState
              _messages.addAll(loadedMessages); // Add INSIDE setState
              developer.log(
                '[LoadMessages] Inside setState. Finished addAll. Final _messages count: ${_messages.length}.',
                name: 'FirebaseMessagingDevTool',
              );
            });
          } else {
            developer.log(
              '[LoadMessages] Widget not mounted, cannot update state with loaded messages.',
              name: 'FirebaseMessagingDevTool',
            );
          }
        } catch (e, stackTrace) {
          developer.log(
            '[LoadMessages] Error during deserialization/setState: $e',
            name: 'FirebaseMessagingDevTool',
            error: e,
            stackTrace: stackTrace,
          );
          // Clear potentially corrupted storage on error
          _forceClearMessageStorage();
        }
        // --- End Deserialize ---
      } else {
        developer.log(
          '[LoadMessages] No message JSON found in storage or string is empty.',
          name: 'FirebaseMessagingDevTool',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '[LoadMessages] Outer error: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveMessages() async {
    // --- Prevent saving during or immediately after a clear ---
    if (_isClearing) {
      developer.log(
        '[SaveMessages] Skipping save because clear operation is in progress.',
        name: 'FirebaseMessagingDevTool',
      );
      return;
    }

    try {
      // Don't save messages if auto-clear is enabled
      if (_autoClearOnReload) {
        developer.log(
          'Skipping message save because auto-clear is enabled',
          name: 'FirebaseMessagingDevTool',
        );
        return;
      }

      final messagesJson = json.encode(
        _messages.map((msg) => msg.originalJson).toList(),
      );
      web.window.localStorage.setItem(
        _messagesStorageKey,
        messagesJson,
      ); // Use web.window

      developer.log(
        'Saved ${_messages.length} messages to localStorage',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error saving messages to localStorage: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _setDeviceIdentifier() {
    // This is just a fallback, the actual device info will come from the message
    setState(() {
      _deviceIdentifier = 'Waiting for messages...';
    });
  }

  // Async function to wait for the service and set up the listener
  Future<void> _initServiceListener() async {
    try {
      // Wait for the VM service connection to become available.
      developer.log(
        'Setting up event listener...',
        name: 'FirebaseMessagingDevTool',
      );

      final vmService = await serviceManager.onServiceAvailable;
      developer.log(
        'VM service is available',
        name: 'FirebaseMessagingDevTool',
      );

      // Register for FirebaseMessage events
      await vmService.registerService(
        'FirebaseMessage',
        'ext.firebase_messaging.message',
      );
      developer.log(
        'Registered for Firebase Messaging events',
        name: 'FirebaseMessagingDevTool',
      );

      // Listen for events posted by the debugged application
      _eventSubscription = vmService.onExtensionEvent.listen(
        (event) {
          developer.log(
            'Received event kind: ${event.extensionKind}',
            name: 'FirebaseMessagingDevTool',
          );

          // Accept both event kinds for backward compatibility
          if (event.extensionKind == 'FirebaseMessage' ||
              event.extensionKind == 'ext.firebase_messaging.message') {
            developer.log(
              'Received firebase message event!',
              name: 'FirebaseMessagingDevTool',
            );
            _handleMessageEvent(event);
          }
        },
        onError: (error) {
          // Handle stream errors
          developer.log(
            'Error listening to extension events: $error',
            name: 'FirebaseMessagingDevTool',
            error: error,
          );
        },
        onDone: () {
          // Handle stream closing (optional)
          developer.log(
            'Extension event stream closed.',
            name: 'FirebaseMessagingDevTool',
          );
        },
      );

      developer.log(
        'Event listener setup complete',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error setting up service listener: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleMessageEvent(Event event) {
    try {
      developer.log(
        'Processing event: ${event.extensionKind}',
        name: 'FirebaseMessagingDevTool',
      );

      final data = event.extensionData?.data as Map<String, dynamic>?;
      if (data == null) {
        developer.log(
          'Received null data from event',
          name: 'FirebaseMessagingDevTool',
        );
        return;
      }

      developer.log(
        'Message data received: ${data.keys.join(', ')}',
        name: 'FirebaseMessagingDevTool',
      );

      final message = FirebaseMessage.fromJson(data);
      developer.log(
        'Message parsed with ID: ${message.messageId}',
        name: 'FirebaseMessagingDevTool',
      );

      // Update device identifier if available in the message
      if (data['deviceId'] != null || data['deviceName'] != null) {
        setState(() {
          _deviceIdentifier =
              '${data['deviceName'] ?? 'Unknown Device'} (${data['deviceId'] ?? 'unknown'})';
        });
        developer.log(
          'Updated device identifier: $_deviceIdentifier',
          name: 'FirebaseMessagingDevTool',
        );
      }

      setState(() {
        if (_showNewestOnTop) {
          _messages.insert(0, message);
        } else {
          _messages.add(message);
        }
      });

      // Schedule the save for after the state update completes, ONLY if not clearing
      if (!_isClearing) {
        Future.microtask(() => _saveMessages());
      }

      developer.log(
        'Message added to list: ${message.messageId}, total count: ${_messages.length}',
        name: 'FirebaseMessagingDevTool',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error handling message event: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
        title: Row(
          children: [
            const Text('Firebase Messages'),
            const SizedBox(width: 8),
            Text(
              'for $_deviceIdentifier',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[100],
              ),
            ),
          ],
        ),
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
        onPressed: () async {
          await _clearMessages();
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
            ? index +
                1 // For newest on top, newest = 1, 2, 3...
            : totalMessages -
                index; // For newest at bottom, oldest = 1, 2, 3...

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
                        onChanged: (value) async {
                          setState(() {
                            _showNewestOnTop = value;
                          });
                          await _saveSettings();

                          if (_messages.isNotEmpty) {
                            setState(() {
                              final reversedMessages =
                                  _messages.reversed.toList();
                              _messages.clear();
                              _messages.addAll(reversedMessages);
                            });
                            await _saveMessages();
                          }
                        },
                        activeColor:
                            isDarkMode ? Colors.lightBlue : Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Automatically clear messages on reload',
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                      Switch(
                        value: _autoClearOnReload,
                        onChanged: (value) async {
                          setState(() {
                            _autoClearOnReload = value;
                          });
                          await _saveSettings();

                          // Show a snackbar to explain what will happen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Messages will be cleared when extension is reloaded'
                                    : 'Messages will be preserved between reloads',
                              ),
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'OK',
                                onPressed: () {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                },
                              ),
                            ),
                          );
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
                    onPressed: () async {
                      await _clearMessages();
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
                    'Version: 0.2.0',
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

  Future<void> _saveSettings() async {
    try {
      web.window.localStorage.setItem(
        _showNewestOnTopKey,
        _showNewestOnTop.toString(),
      ); // Use web.window
      web.window.localStorage.setItem(
        _autoClearOnReloadKey,
        _autoClearOnReload.toString(),
      ); // Use web.window

      developer.log(
        'Settings saved to localStorage: showNewestOnTop=$_showNewestOnTop, autoClearOnReload=$_autoClearOnReload',
        name: 'FirebaseMessagingDevTool',
      );

      // Don't clear messages immediately when auto-clear is enabled
      // Messages will be cleared on next reload
      developer.log(
        'Auto-clear setting updated to: $_autoClearOnReload - will apply on next reload',
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

  Future<void> _clearMessages() async {
    _isClearing = true; // Set flag at the start
    developer.log(
      '[Manual Clear] Start. _isClearing = true',
      name: 'FirebaseMessagingDevTool',
    );
    try {
      // Clear in-memory messages FIRST
      if (mounted) {
        setState(() {
          _messages.clear();
          developer.log(
            '[Manual Clear] Cleared in-memory messages.',
            name: 'FirebaseMessagingDevTool',
          );
        });
      }
      // Force clear storage using the robust method (now async)
      await _forceClearMessageStorage();
      developer.log(
        '[Manual Clear] Storage clear attempted.',
        name: 'FirebaseMessagingDevTool',
      );

      // --- NEW: Force next session to auto-clear ---
      try {
        web.window.localStorage.setItem(_autoClearOnReloadKey, 'true');
        developer.log(
          '[Manual Clear] Set auto-clear flag in storage to TRUE for next session.',
          name: 'FirebaseMessagingDevTool',
        );
      } catch (e) {
        developer.log(
          '[Manual Clear] Error setting auto-clear flag for next session: $e',
          name: 'FirebaseMessagingDevTool',
        );
      }
      // --- End NEW ---
    } catch (e, stackTrace) {
      developer.log(
        '[Manual Clear] Error: $e',
        name: 'FirebaseMessagingDevTool',
        error: e,
        stackTrace: stackTrace,
      );
    }
    // NOTE: We intentionally DO NOT reset _isClearing = false here.
    // This prevents saves for the rest of the current session after a manual clear.
    developer.log(
      '[Manual Clear] Finished. _isClearing remains true for this session.',
      name: 'FirebaseMessagingDevTool',
    );
    // The finally block that reset _isClearing is removed.
  }
}
