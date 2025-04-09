extension MapUtils<K, V> on Map<K, V> {
  /// Returns a new map with all null values removed recursively.
  /// Also processes nested maps and lists to remove null values within them.
  Map<K, dynamic> removeNullValues() {
    final result = <K, dynamic>{};

    for (final entry in entries) {
      if (entry.value == null) continue;

      if (entry.value is Map) {
        // Recursively clean nested maps
        final cleanedMap = (entry.value as Map).removeNullValues();
        if (cleanedMap.isNotEmpty) {
          result[entry.key] = cleanedMap;
        }
      } else if (entry.value is List) {
        // Process lists and remove null values
        final cleanedList = _cleanList(entry.value as List);
        if (cleanedList.isNotEmpty) {
          result[entry.key] = cleanedList;
        }
      } else {
        // Regular non-null value
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Helper method to clean a list by removing null values and processing nested maps/lists
  List<dynamic> _cleanList(List list) {
    return list.where((item) => item != null).map((item) {
      if (item is Map) {
        return item.removeNullValues();
      } else if (item is List) {
        return _cleanList(item);
      } else {
        return item;
      }
    }).toList();
  }
}
