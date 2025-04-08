import 'package:flutter/material.dart';

/// Widget for displaying and configuring extension settings
class SettingsTab extends StatelessWidget {
  final bool showNewestOnTop;
  final int messageCount;
  final Future<void> Function(bool) onToggleShowNewestOnTop;

  const SettingsTab({
    required this.showNewestOnTop,
    required this.messageCount,
    required this.onToggleShowNewestOnTop,
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
            title: 'Message Information',
            content: 'Messages are stored in memory and cleared on reload.',
            subtitle: 'Current session message count: $messageCount',
            icon: Icons.memory,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            title: 'Flutter Firebase Plugin',
            content:
                'To send test messages, use the Firebase console or FCM API.',
            icon: Icons.local_fire_department,
          ),
          const SizedBox(height: 12),
          Text(
            'Version: 0.2.1',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
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
}
