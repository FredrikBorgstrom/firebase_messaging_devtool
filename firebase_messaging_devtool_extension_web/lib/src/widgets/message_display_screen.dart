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
  // Device identifier
  String _deviceIdentifier = '';
  // Flag to control message acceptance after initial connection
  bool _acceptingMessages = false;
  // Timer to delay message acceptance
  Timer? _acceptMessagesTimer;

  @override
  void initState() {
    // Ensure messages list is cleared right at the beginning
    _messages = [];
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load settings (only showNewestOnTop)
    _loadSettings();
    _setDeviceIdentifier();
    _initServiceListener();
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
        });
      }
    } catch (e, stackTrace) {}
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

      // Start a timer to enable message acceptance after a delay
      _acceptMessagesTimer?.cancel(); // Cancel any existing timer
      _acceptMessagesTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Only set the flag if the widget is still mounted
          _acceptingMessages = true;
          // Optionally log when messages start being accepted (if logging needed later)
          // print('[Init Listener] Now accepting messages.');
        }
      });
    } catch (e, stackTrace) {}
  }

  void _handleMessageEvent(Event event) {
    // Ignore messages received before the acceptance timer fires
    if (!_acceptingMessages) {
      // Optionally log that a message was ignored due to timing
      // print('[HandleEvent] Ignoring early message.');
      return;
    }

    try {
      final data = event.extensionData?.data as Map<String, dynamic>?;
      if (data == null) {
        return;
      }
      final message = FirebaseMessage.fromJson(data);

      // Removed the duplicate ID check, relying on time-based filter
      // if (message.messageId.isNotEmpty &&
      //     _messages.any((m) => m.messageId == message.messageId)) {
      //   return;
      // }

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
            onToggleShowNewestOnTop: _toggleShowNewestOnTop,
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

  // Only saves the showNewestOnTop setting
  Future<void> _toggleShowNewestOnTop(bool value) async {
    setState(() {
      _showNewestOnTop = value;
    });
    await StorageService.saveSettings(showNewestOnTop: _showNewestOnTop);

    // Only reorder in-memory list
    if (_messages.isNotEmpty) {
      setState(() {
        final reversedMessages = _messages.reversed.toList();
        _messages = [];
        _messages.addAll(reversedMessages);
      });
    }
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
              'Messages will appear here (cleared on reload)',
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

  // Simplified delete: only removes from in-memory list
  void _deleteMessage(int index) {
    if (mounted) {
      setState(() {
        _messages.removeAt(index);
      });
    }
  }
}
