import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/firebase_message.dart';
import '../utils/date_formatter.dart';

/// Widget to display a single Firebase message in a card format
class MessageCard extends StatefulWidget {
  final FirebaseMessage message;
  final int index;
  final int totalMessages;
  final bool showNewestOnTop;

  const MessageCard({
    required this.message,
    required this.index,
    required this.totalMessages,
    required this.showNewestOnTop,
    super.key,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine the display index based on sorting preference
    final displayIndex =
        widget.showNewestOnTop
            ? widget.totalMessages - widget.index
            : widget.index + 1;

    // Extract notification title and body if they exist
    final notificationTitle = widget.message.notification?['title'] as String?;
    final notificationBody = widget.message.notification?['body'] as String?;

    // Check if we have notification info to display
    final hasNotification =
        notificationTitle != null || notificationBody != null;

    // Check if message has data payload
    final hasData =
        widget.message.data != null && widget.message.data!.isNotEmpty;

    // Determine card color based on message type
    Color cardColor;
    String messageTypeLabel;

    if (hasNotification && hasData) {
      cardColor = isDarkMode ? Colors.amber[900]! : Colors.amber[100]!;
      messageTypeLabel = 'Notification with Data';
    } else if (hasNotification) {
      cardColor = isDarkMode ? Colors.green[900]! : Colors.green[100]!;
      messageTypeLabel = 'Notification';
    } else if (hasData) {
      cardColor = isDarkMode ? Colors.blue[900]! : Colors.blue[100]!;
      messageTypeLabel = 'Data Message';
    } else {
      cardColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
      messageTypeLabel = 'Empty Message';
    }

    final sentTime = widget.message.sentTime;
    final formattedTime =
        sentTime != null ? formatDateTime(sentTime) : 'Time unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with message type and time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Message index and type
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[700] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$displayIndex',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        messageTypeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  // Time and copy button
                  Row(
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy message to clipboard',
                        onPressed: () => _copyMessageToClipboard(context),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Notification content if available
              if (hasNotification) ...[
                if (notificationTitle != null) ...[
                  Text(
                    'Title: $notificationTitle',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (notificationBody != null) ...[
                  Text(
                    'Body: $notificationBody',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                ],
              ],

              // Data content preview (always visible)
              if (hasData) ...[
                Text(
                  'Data:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                // Show data preview or full data based on expansion state
                if (_isExpanded)
                  _buildFullDataView(isDarkMode)
                else
                  _buildDataPreview(isDarkMode),
              ],

              // Metadata section (only when expanded)
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildMetadataSection(isDarkMode),
              ],

              // Expansion hint
              Center(
                child: IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataPreview(bool isDarkMode) {
    // Show a condensed preview of data
    final data = widget.message.data ?? {};
    if (data.isEmpty) {
      return const Text('(empty)');
    }

    final previewText = data.entries
        .take(3)
        .map((e) => '${e.key}: ${_getShortValue(e.value)}')
        .join('\n');
    final hasMore = data.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black54 : Colors.white70,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            previewText,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '...and ${data.length - 3} more fields',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullDataView(bool isDarkMode) {
    final data = widget.message.data ?? {};
    if (data.isEmpty) {
      return const Text('(empty data payload)');
    }

    // Format JSON with indentation for better readability
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black54 : Colors.white70,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            prettyJson,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(bool isDarkMode) {
    final metadata = widget.message.metadata ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message Details:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _buildTableRow(
              'Message ID:',
              widget.message.messageId ?? 'Unknown',
              isDarkMode,
            ),
            if (metadata.containsKey('ttl'))
              _buildTableRow('TTL:', metadata['ttl'].toString(), isDarkMode),
            if (metadata.containsKey('messageType'))
              _buildTableRow(
                'Type:',
                metadata['messageType'].toString(),
                isDarkMode,
              ),
            if (metadata.containsKey('collapseKey'))
              _buildTableRow(
                'Collapse Key:',
                metadata['collapseKey'].toString(),
                isDarkMode,
              ),
            if (metadata.containsKey('from'))
              _buildTableRow('From:', metadata['from'].toString(), isDarkMode),
            if (metadata.containsKey('priority'))
              _buildTableRow(
                'Priority:',
                metadata['priority'].toString(),
                isDarkMode,
              ),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, bool isDarkMode) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: SelectableText(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  String _getShortValue(dynamic value) {
    if (value == null) return 'null';

    final stringValue = value.toString();
    if (stringValue.length <= 20) return stringValue;

    return '${stringValue.substring(0, 17)}...';
  }

  void _copyMessageToClipboard(BuildContext context) {
    try {
      // Get the complete message as JSON
      final encodedMessage = const JsonEncoder.withIndent(
        '  ',
      ).convert(widget.message.originalJson);
      Clipboard.setData(ClipboardData(text: encodedMessage));

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying message: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
