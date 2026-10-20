class Member {
  final int id;
  final int familyId;
  final String name;
  final String color;
  final String? email;
  final bool hasPincode;
  final DateTime createdAt;

  Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.color,
    this.email,
    required this.hasPincode,
    required this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      familyId: json['family_id'],
      name: json['name'],
      color: json['color'] ?? '#3F51B5',
      email: json['email'],
      hasPincode: json['has_pin'] ?? (json['pincode'] != null && json['pincode'].toString().isNotEmpty),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Location {
  final int id;
  final int familyId;
  final int? parentId;
  final String name;
  final String? description;
  final List<String> photos;
  final List<String> photoUrls;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.familyId,
    this.parentId,
    required this.name,
    this.description,
    required this.photos,
    required this.photoUrls,
    required this.createdAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      familyId: json['family_id'],
      parentId: json['parent_id'],
      name: json['name'],
      description: json['description'],
      photos: List<String>.from(json['photos'] ?? []),
      photoUrls: List<String>.from(json['photo_urls'] ?? (json['photos'] ?? [])),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class LocationTreeNode {
  final int id;
  final String name;
  final String? description;
  final List<String> photos;
  final List<String> photoUrls;
  final List<LocationTreeNode> subLocations;

  LocationTreeNode({
    required this.id,
    required this.name,
    this.description,
    required this.photos,
    required this.photoUrls,
    required this.subLocations,
  });

  factory LocationTreeNode.fromJson(Map<String, dynamic> json) {
    var subJson = json['sub_locations'] as List? ?? [];
    return LocationTreeNode(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      photos: List<String>.from(json['photos'] ?? []),
      photoUrls: List<String>.from(json['photo_urls'] ?? (json['photos'] ?? [])),
      subLocations: subJson.map((s) => LocationTreeNode.fromJson(s)).toList(),
    );
  }
}

class Item {
  final int id;
  final int familyId;
  final int? locationId;
  final String name;
  final String? description;
  final String status;
  final int? checkedOutByMemberId;
  final DateTime? checkedOutAt;
  final List<String> photos;
  final List<String> photoUrls;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.familyId,
    this.locationId,
    required this.name,
    this.description,
    required this.status,
    this.checkedOutByMemberId,
    this.checkedOutAt,
    required this.photos,
    required this.photoUrls,
    required this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      familyId: json['family_id'],
      locationId: json['location_id'],
      name: json['name'],
      description: json['description'],
      status: json['status'] ?? 'checked_in',
      checkedOutByMemberId: json['checked_out_by_member_id'],
      checkedOutAt: json['checked_out_at'] != null 
          ? DateTime.parse(json['checked_out_at']) 
          : null,
      photos: List<String>.from(json['photos'] ?? []),
      photoUrls: List<String>.from(json['photo_urls'] ?? (json['photos'] ?? [])),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ActivityLog {
  final int id;
  final int familyId;
  final int itemId;
  final String itemName;
  final int memberId;
  final String memberName;
  final int? locationId;
  final String locationName;
  final String action;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.familyId,
    required this.itemId,
    required this.itemName,
    required this.memberId,
    required this.memberName,
    this.locationId,
    required this.locationName,
    required this.action,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      familyId: json['family_id'],
      itemId: json['item_id'],
      itemName: json['item_name'] ?? '物品',
      memberId: json['member_id'],
      memberName: json['member_name'] ?? '成員',
      locationId: json['location_id'],
      locationName: json['location_name'] ?? '未指定位置',
      action: json['action'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class SearchResult {
  final Item item;
  final double score;
  final String locationPath;

  SearchResult({
    required this.item,
    required this.score,
    required this.locationPath,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      item: Item.fromJson(json['item']),
      score: (json['score'] as num).toDouble(),
      locationPath: json['location_path'] ?? '未指定位置',
    );
  }
}

class ItemTraceInfo {
  final Item item;
  final String lastCheckedOutBy;
  final DateTime? checkedOutAt;
  final int? targetLocationId;
  final String targetLocationPath;

  ItemTraceInfo({
    required this.item,
    required this.lastCheckedOutBy,
    this.checkedOutAt,
    this.targetLocationId,
    required this.targetLocationPath,
  });

  factory ItemTraceInfo.fromJson(Map<String, dynamic> json) {
    return ItemTraceInfo(
      item: Item.fromJson(json['item']),
      lastCheckedOutBy: json['last_checked_out_by'] ?? '未知成員',
      checkedOutAt: json['checked_out_at'] != null 
          ? DateTime.parse(json['checked_out_at']) 
          : null,
      targetLocationId: json['target_location_id'],
      targetLocationPath: json['target_location_path'] ?? '未指定空間',
    );
  }
}
