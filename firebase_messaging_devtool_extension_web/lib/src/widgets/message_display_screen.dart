import 'dart:async';

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
  // Messages are now purely in-memory
  List<FirebaseMessage> _messages = [];
  // Keep track of the subscription to cancel it later
  StreamSubscription<Event>? _eventSubscription;
  // Tab controller for the main tabs
  late TabController _tabController;
  // Setting for message order preference (still persistent)
  bool _showNewestOnTop = false;
  // Setting to clear messages on restart (effectively controls the initial filter)
  bool _clearOnReload = true; // Default to true
  // Setting to hide null values in message details
  bool _hideNullValues = false; // Default to false
  // Device identifier
  String _deviceIdentifier = '';
  // Flag to control message acceptance based on _clearOnReload setting
  bool _acceptingMessages = false;
  // Timer to delay message acceptance (only used if _clearOnReload is true)
  Timer? _acceptMessagesTimer;

  @override
  void initState() {
    // Ensure messages list is cleared right at the beginning
    _messages = [];
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load settings which determines initial _acceptingMessages state
    _loadSettingsAndInitListener();
    _setDeviceIdentifier();
  }

  // Combine loading settings and initializing listener
  Future<void> _loadSettingsAndInitListener() async {
    await _loadSettings(); // Load settings first

    // Set initial acceptance based on loaded setting
    _acceptingMessages = !_clearOnReload;

    _initServiceListener(); // Then initialize listener
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the widget is disposed
    _eventSubscription?.cancel();
    // Cancel the timer if it's still active
    _acceptMessagesTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await StorageService.loadSettings();
      if (mounted) {
        setState(() {
          _showNewestOnTop = settings['showNewestOnTop'] ?? false;
          _clearOnReload = settings['clearOnReload'] ?? true; // Load setting
          _hideNullValues = settings['hideNullValues'] ?? false; // Load setting
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          // Ensure defaults are set on error
          _showNewestOnTop = false;
          _clearOnReload = true;
          _hideNullValues = false; // Default
        });
      }
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
      final vmService = await serviceManager.onServiceAvailable;
      await vmService.registerService(
        'FirebaseMessage',
        'ext.firebase_messaging.message',
      );
      _eventSubscription = vmService.onExtensionEvent.listen(
        (event) {
          if (event.extensionKind == 'FirebaseMessage' ||
              event.extensionKind == 'ext.firebase_messaging.message') {
            _handleMessageEvent(event);
          }
        },
        onError: (error) {},
        onDone: () {},
      );

      // Only start the timer if clearOnReload is true
      if (_clearOnReload) {
        _acceptMessagesTimer?.cancel(); // Cancel any existing timer
        _acceptMessagesTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _acceptingMessages = true;
          }
        });
      } else {
        // If clearOnReload is false, accept messages immediately
        _acceptingMessages = true;
      }
    } catch (e, stackTrace) {}
  }

  void _handleMessageEvent(Event event) {
    // Ignore messages received before the acceptance flag is set
    if (!_acceptingMessages) {
      return;
    }

    try {
      final data = event.extensionData?.data as Map<String, dynamic>?;
      if (data == null) {
        return;
      }
      final message = FirebaseMessage.fromJson(data);

      if (data['deviceId'] != null || data['deviceName'] != null) {
        setState(() {
          _deviceIdentifier =
              '${data['deviceName'] ?? 'Unknown Device'} (${data['deviceId'] ?? 'unknown'})';
        });
      }

      // Add the message to the list
      setState(() {
        if (_showNewestOnTop) {
          _messages.insert(0, message);
        } else {
          _messages.add(message);
        }
      });
    } catch (e, stackTrace) {}
  }

  // Simplified clear: only clears the in-memory list
  Future<void> _clearMessages() async {
    try {
      if (mounted) {
        setState(() {
          _messages = [];
        });
      }
    } catch (e, stackTrace) {
      print('[MessageDisplayScreen] Error clearing in-memory messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
            clearOnReload: _clearOnReload, // Pass the setting
            hideNullValues: _hideNullValues, // Pass the setting
            onToggleShowNewestOnTop: _toggleShowNewestOnTop,
            onToggleClearOnReload:
                _toggleClearOnReload, // Pass the toggle handler
            onToggleHideNullValues: _toggleHideNullValues, // Pass handler
            messageCount: _messages.length,
          ),
        ],
      ),
      // Keep FAB to clear in-memory messages for the current session
      floatingActionButton: FloatingActionButton(
        onPressed: _clearMessages, // Directly call the simplified clear
        tooltip: 'Clear Session Messages',
        backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.delete_sweep),
      ),
    );
  }

  // Saves showNewestOnTop setting
  Future<void> _toggleShowNewestOnTop(bool value) async {
    setState(() {
      _showNewestOnTop = value;
    });
    // Save all settings
    await _saveAllSettings();

    // Only reorder in-memory list
    if (_messages.isNotEmpty) {
      setState(() {
        final reversedMessages = _messages.reversed.toList();
        _messages = [];
        _messages.addAll(reversedMessages);
      });
    }
  }

  // Add handler for the new setting
  Future<void> _toggleClearOnReload(bool value) async {
    setState(() {
      _clearOnReload = value;
    });
    // Save all settings
    await _saveAllSettings();

    // Update acceptance state immediately based on new setting
    // If turning ON clearOnReload, messages might still be accepted briefly if timer is running
    // If turning OFF clearOnReload, accept immediately
    if (!_clearOnReload) {
      _acceptMessagesTimer?.cancel(); // Cancel timer if turning off
      _acceptingMessages = true;
    } else {
      // If turning ON, reset acceptance and let the listener logic restart the timer if needed (on next load)
      // For current session, we might have already passed the timer, so new messages might still come in.
      // A full reload is needed for the timer logic to restart correctly based on this setting.
    }
  }

  // Add handler for the new hideNullValues setting
  Future<void> _toggleHideNullValues(bool value) async {
    setState(() {
      _hideNullValues = value;
    });
    // Save all settings
    await _saveAllSettings();
    // No immediate effect needed, MessageCard will use the value on next build
  }

  // Saves all settings
  Future<void> _saveAllSettings() async {
    await StorageService.saveSettings(
      showNewestOnTop: _showNewestOnTop,
      clearOnReload: _clearOnReload,
      hideNullValues: _hideNullValues,
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
              _clearOnReload
                  ? 'Messages will appear here (cleared on reload)'
                  : 'Messages will appear here (preserved on reload)',
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
            hideNullValues: _hideNullValues, // Pass the setting
            onDeleteMessage: _deleteMessage,
          ),
    );
  }

  // Simplified delete: only removes from in-memory list
  void _deleteMessage(int index) {
    if (mounted) {
      setState(() {
        _messages.removeAt(index);
      });
    }
  }
}
