import 'package:flutter/material.dart';

/// Widget for displaying and configuring extension settings
class SettingsTab extends StatelessWidget {
  final bool showNewestOnTop;
  final bool autoClearOnReload;
  final int messageCount;
  final Future<void> Function(bool) onToggleShowNewestOnTop;
  final Future<void> Function(bool) onToggleAutoClearOnReload;
  final Future<void> Function() onClearMessages;

  const SettingsTab({
    required this.showNewestOnTop,
    required this.autoClearOnReload,
    required this.messageCount,
    required this.onToggleShowNewestOnTop,
    required this.onToggleAutoClearOnReload,
    required this.onClearMessages,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Message Display', isDarkMode),
          const SizedBox(height: 8),
          _buildSettingCard(
            context,
            title: 'Show Newest Messages On Top',
            subtitle: 'Toggle to change message display order',
            icon: Icons.sort,
            value: showNewestOnTop,
            onChanged: (value) async {
              await onToggleShowNewestOnTop(value);
            },
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('Storage Management', isDarkMode),
          const SizedBox(height: 8),
          _buildSettingCard(
            context,
            title: 'Auto-Clear On Reload',
            subtitle: 'Messages will be cleared when extension reloads',
            icon: Icons.cleaning_services,
            value: autoClearOnReload,
            onChanged: (value) async {
              await onToggleAutoClearOnReload(value);
            },
          ),
          const SizedBox(height: 12),
          _buildClearMessagesButton(context, isDarkMode),
          const SizedBox(height: 24),

          _buildSectionHeader('About', isDarkMode),
          const SizedBox(height: 8),
          _buildInfoCard(
            context,
            title: 'Firebase Messaging DevTools Extension',
            content:
                'This extension allows you to monitor Firebase Cloud Messaging messages received by your app during development.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            title: 'Storage Information',
            content:
                'Messages are stored in local storage for persistence between reloads.',
            subtitle: 'Current message count: $messageCount',
            icon: Icons.storage,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            title: 'Flutter Firebase Plugin',
            content:
                'To send test messages, use the Firebase console or FCM API.',
            icon: Icons.local_fire_department,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isDarkMode ? Colors.blue[300] : Colors.blue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (newValue) async {
                await onChanged(newValue);
              },
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearMessagesButton(BuildContext context, bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.delete_forever,
              size: 28,
              color: isDarkMode ? Colors.red[300] : Colors.red,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear All Messages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Remove all messages from storage',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Show confirmation dialog
                final shouldClear = await _showClearConfirmationDialog(context);
                if (shouldClear) {
                  await onClearMessages();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.red[700] : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('CLEAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
    String? subtitle,
    required IconData icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showClearConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Messages'),
            content: const Text(
              'Are you sure you want to clear all messages? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('CLEAR'),
              ),
            ],
          ),
    );
    return result ?? false;
  }
}
