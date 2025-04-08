/// Message model to better organize Firebase Cloud Messaging data
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
        } else {}
      }

      // Extract data payload
      if (json.containsKey('data') && json['data'] != null) {
        final dataPayload = json['data'];
        if (dataPayload is Map) {
          data.addAll(Map<String, dynamic>.from(dataPayload));
        } else {}
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
        } catch (e) {
          // Leave sentTime as null if parsing fails
        }
      }

      final String messageId = (json['messageId'] as String?) ?? 'unknown';

      return FirebaseMessage(
        messageId: messageId,
        sentTime: sentTime,
        notification: notification,
        data: data,
        metadata: metadata,
        originalJson: json,
      );
    } catch (e, stackTrace) {
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

/// Helper to convert potentially complex map data to something JSON encodable
Map<String, dynamic> convertToJsonEncodable(Map<dynamic, dynamic> originalMap) {
  final Map<String, dynamic> newMap = {};
  originalMap.forEach((key, value) {
    final String stringKey = key.toString();
    if (value == null || value is String || value is num || value is bool) {
      newMap[stringKey] = value;
    } else if (value is Map) {
      newMap[stringKey] = convertToJsonEncodable(
        value,
      ); // Recurse for nested maps
    } else if (value is List) {
      newMap[stringKey] = convertListToJsonEncodable(value); // Handle lists
    } else {
      newMap[stringKey] = value.toString(); // Convert other types to string
    }
  });
  return newMap;
}

/// Helper to convert list data to something JSON encodable
List<dynamic> convertListToJsonEncodable(List<dynamic> originalList) {
  final List<dynamic> newList = [];
  for (var item in originalList) {
    if (item == null || item is String || item is num || item is bool) {
      newList.add(item);
    } else if (item is Map) {
      newList.add(convertToJsonEncodable(item)); // Recurse for maps in lists
    } else if (item is List) {
      newList.add(
        convertListToJsonEncodable(item),
      ); // Recurse for lists in lists
    } else {
      newList.add(item.toString()); // Convert other types to string
    }
  }
  return newList;
}
