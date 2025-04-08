import 'dart:async';
import 'dart:developer' as developer;

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' show Event;

import '../models/firebase_message.dart';
import '../services/storage_service.dart';
import 'message_card.dart';
import 'settings_tab.dart';

/// The screen that displays the incoming Firebase messages
class MessageDisplayScreen extends StatefulWidget {
  const MessageDisplayScreen({super.key});

  @override
  State<MessageDisplayScreen> createState() => _MessageDisplayScreenState();
}

class _MessageDisplayScreenState extends State<MessageDisplayScreen>
    with SingleTickerProviderStateMixin {
  // Change from final to non-final so we can reassign it
  List<FirebaseMessage> _messages = [];
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

    // Apply auto-clear at startup if needed
    _applyAutoClearIfNeededAtStartup();

    // Load settings
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
      final autoClearOnReloadStr = StorageService.isAutoClearEnabled();
      developer.log(
        '[Startup Check] Auto-clear setting from storage: $autoClearOnReloadStr',
        name: 'FirebaseMessagingDevTool',
      );

      if (autoClearOnReloadStr) {
        developer.log(
          '[Startup Check] Auto-clear is TRUE. Forcing message clear NOW.',
          name: 'FirebaseMessagingDevTool',
        );
        StorageService.forceClearMessageStorage();

        // Explicitly create a new empty list instead of using clear()
        _messages = [];
        developer.log(
          '[Startup Check] Set _messages to empty list',
          name: 'FirebaseMessagingDevTool',
        );
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
      final settings = await StorageService.loadSettings();

      if (mounted) {
        setState(() {
          _showNewestOnTop = settings['showNewestOnTop'] ?? false;
          _autoClearOnReload = settings['autoClearOnReload'] ?? false;
        });
      }

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

  Future<void> _loadMessages() async {
    developer.log(
      '[Message Screen] Starting _loadMessages() with current count: ${_messages.length}',
      name: 'FirebaseMessagingDevTool',
    );

    try {
      final loadedMessages = await StorageService.loadMessages();
      developer.log(
        '[Message Screen] Loaded ${loadedMessages.length} messages from storage',
        name: 'FirebaseMessagingDevTool',
      );

      if (mounted) {
        setState(() {
          // Use empty list assignment first
          _messages = [];
          // Then add all loaded messages
          _messages.addAll(loadedMessages);

          developer.log(
            '[Message Screen] Updated _messages list, new count: ${_messages.length}',
            name: 'FirebaseMessagingDevTool',
          );
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in _loadMessages: $e',
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

      // Check for duplicate message IDs before adding
      bool isDuplicate = _messages.any((m) => m.messageId == message.messageId);
      if (isDuplicate) {
        developer.log(
          'Skipping duplicate message with ID: ${message.messageId}',
          name: 'FirebaseMessagingDevTool',
        );
        return;
      }

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

  Future<void> _saveMessages() async {
    developer.log(
      '[Message Screen] Saving ${_messages.length} messages to storage',
      name: 'FirebaseMessagingDevTool',
    );

    try {
      await StorageService.saveMessages(_messages, isClearing: _isClearing);
    } catch (e, stackTrace) {
      developer.log(
        '[Message Screen] Error saving messages: $e',
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
      // Clear in-memory messages by assigning a new empty list
      if (mounted) {
        setState(() {
          _messages = [];
          developer.log(
            '[Manual Clear] Set _messages to empty list',
            name: 'FirebaseMessagingDevTool',
          );
        });
      }

      // Force clear storage using the robust method
      await StorageService.forceClearMessageStorage();
      developer.log(
        '[Manual Clear] Storage clear attempted.',
        name: 'FirebaseMessagingDevTool',
      );

      // Force next session to auto-clear
      StorageService.forceAutoClearNextSession();
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
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.view_list), text: 'Messages'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          SettingsTab(
            showNewestOnTop: _showNewestOnTop,
            autoClearOnReload: _autoClearOnReload,
            onClearMessages: _clearMessages,
            onToggleShowNewestOnTop: _toggleShowNewestOnTop,
            onToggleAutoClearOnReload: _toggleAutoClearOnReload,
            messageCount: _messages.length,
          ),
        ],
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

  Future<void> _toggleShowNewestOnTop(bool value) async {
    setState(() {
      _showNewestOnTop = value;
    });
    await StorageService.saveSettings(
      showNewestOnTop: _showNewestOnTop,
      autoClearOnReload: _autoClearOnReload,
    );

    if (_messages.isNotEmpty) {
      setState(() {
        final reversedMessages = _messages.reversed.toList();
        // Use empty list assignment first, then add all messages
        _messages = [];
        _messages.addAll(reversedMessages);
      });
      await StorageService.saveMessages(_messages, isClearing: _isClearing);
    }
  }

  Future<void> _toggleAutoClearOnReload(bool value) async {
    setState(() {
      _autoClearOnReload = value;
    });
    await StorageService.saveSettings(
      showNewestOnTop: _showNewestOnTop,
      autoClearOnReload: _autoClearOnReload,
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
          (context, index) => MessageCard(
            message: _messages[index],
            index: index,
            totalMessages: _messages.length,
            showNewestOnTop: _showNewestOnTop,
            onDeleteMessage: _deleteMessage,
          ),
    );
  }

  // Add a method to delete individual messages
  Future<void> _deleteMessage(int index) async {
    developer.log(
      '[Delete Message] Deleting message at index: $index',
      name: 'FirebaseMessagingDevTool',
    );

    if (mounted) {
      setState(() {
        _messages.removeAt(index);
        developer.log(
          '[Delete Message] Removed message. Remaining count: ${_messages.length}',
          name: 'FirebaseMessagingDevTool',
        );
      });

      // Save updated messages to storage
      if (!_isClearing) {
        await StorageService.saveMessages(_messages, isClearing: false);
        developer.log(
          '[Delete Message] Updated storage after message deletion',
          name: 'FirebaseMessagingDevTool',
        );
      }
    }
  }
}
