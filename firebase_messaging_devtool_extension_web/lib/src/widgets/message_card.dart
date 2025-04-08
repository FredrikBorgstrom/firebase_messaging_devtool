import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/firebase_message.dart';
import '../utils/date_formatter.dart';

/// Widget to display a single Firebase message in a card format
class MessageCard extends StatefulWidget {
  final FirebaseMessage message;
  final int index;
  final int totalMessages;
  final bool showNewestOnTop;
  final Function(int) onDeleteMessage;

  const MessageCard({
    required this.message,
    required this.index,
    required this.totalMessages,
    required this.showNewestOnTop,
    required this.onDeleteMessage,
    super.key,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  @override
  Widget build(BuildContext context) {
    return _buildMessageCard(
      widget.message,
      widget.index,
      widget.totalMessages,
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
        widget.showNewestOnTop
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
                        'Sent: ${formatDateTime(message.sentTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 20,
                  color: isDarkMode ? Colors.red[300] : Colors.red,
                ),
                tooltip: 'Delete this message',
                onPressed: () {
                  _showDeleteConfirmation(context, index);
                },
              ),
            ],
          ),
          initiallyExpanded:
              index ==
              totalMessages - 1, // Expand only the newest message by default
          iconColor: isDarkMode ? Colors.lightBlue : Colors.blue,
          collapsedIconColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          children: [_buildMessageDetails(message)],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, int index) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text(
              'Are you sure you want to delete this message?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (result == true) {
      widget.onDeleteMessage(widget.index);
    }
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
                      message.metadata['receivedAt'] != null
                          ? formatDateTime(
                            DateTime.parse(
                              message.metadata['receivedAt'] as String,
                            ),
                          )
                          : formatDateTime(DateTime.now()),
                    ),
                    if (message.sentTime != null)
                      _buildTableRow(
                        'Sent At',
                        formatDateTime(message.sentTime!),
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

          // View Raw JSON section
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
            initiallyExpanded: false,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
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
                    color: isDarkMode ? Colors.white : Colors.black87,
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
              initiallyExpanded: false,
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
              initiallyExpanded: false,
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
}
