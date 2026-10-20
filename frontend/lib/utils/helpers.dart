import 'package:flutter/material.dart';
import '../models/models.dart';

Color parseHexColor(String hex) {
  try {
    String cleanHex = hex.replaceAll("#", "");
    if (cleanHex.length == 6) {
      cleanHex = "FF$cleanHex";
    }
    return Color(int.parse(cleanHex, radix: 16));
  } catch (_) {
    return const Color(0xFF3F51B5);
  }
}

String formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return "剛剛";
  if (diff.inMinutes < 60) return "${diff.inMinutes} 分鐘前";
  if (diff.inHours < 24) return "${diff.inHours} 小時前";
  if (diff.inDays < 7) return "${diff.inDays} 天前";

  return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}

String getLocationPath(int? locId, List<Location> locations) {
  if (locId == null) return "未指定儲存位置";
  final pathNodes = <String>[];
  int? currId = locId;
  final visited = <int>{};

  while (currId != null && !visited.contains(currId)) {
    visited.add(currId);
    try {
      final loc = locations.firstWhere((l) => l.id == currId);
      pathNodes.insert(0, loc.name);
      currId = loc.parentId;
    } catch (_) {
      break;
    }
  }

  return pathNodes.isNotEmpty ? pathNodes.join(" > ") : "未知空間";
}
