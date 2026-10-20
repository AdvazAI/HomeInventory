import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../models/models.dart';

class ApiService {
  late final Dio _dio;
  static String? customHost;

  static String get baseUrl {
    if (customHost != null && customHost!.isNotEmpty) {
      return customHost!;
    }
    if (kReleaseMode) {
      return 'https://homeinv.advaz.au';
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      try {
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:8000';
        }
      } catch (_) {}
      return 'http://localhost:8000';
    }
  }

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }

  void updateBaseUrl(String newUrl) {
    customHost = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  Future<int> triggerSetup() async {
    try {
      final response = await _dio.post('/api/setup');
      return response.data['family_id'] ?? 1;
    } catch (e) {
      debugPrint('Setup trigger failed or database already seeded: $e');
      return 1;
    }
  }

  Future<List<Member>> getMembers(int familyId) async {
    final response = await _dio.get('/api/families/$familyId/members');
    final list = response.data as List;
    return list.map((item) => Member.fromJson(item)).toList();
  }

  Future<Member> createMember(int familyId, String name, String color, String? pincode, String? email) async {
    final response = await _dio.post(
      '/api/families/$familyId/members',
      data: {
        'name': name,
        'color': color,
        'pincode': pincode,
        'email': email,
      },
    );
    return Member.fromJson(response.data);
  }

  Future<Member> googleLogin(String email, String googleId) async {
    final response = await _dio.post(
      '/api/auth/google-login',
      data: {'email': email, 'google_id': googleId},
    );
    return Member.fromJson(response.data);
  }

  Future<bool> verifyPin(int memberId, String pin) async {
    try {
      final response = await _dio.post(
        '/api/members/$memberId/verify-pin',
        data: {'pin': pin},
      );
      return response.data['status'] == 'verified';
    } catch (e) {
      return false;
    }
  }

  Future<List<Location>> getLocations(int familyId) async {
    final response = await _dio.get('/api/families/$familyId/locations');
    final list = response.data as List;
    return list.map((item) => Location.fromJson(item)).toList();
  }

  Future<List<LocationTreeNode>> getLocationTree(int familyId) async {
    final response = await _dio.get('/api/families/$familyId/locations/tree');
    final list = response.data as List;
    return list.map((item) => LocationTreeNode.fromJson(item)).toList();
  }

  Future<Location> createLocation(int familyId, String name, String? description, int? parentId, List<String> photos) async {
    final response = await _dio.post(
      '/api/families/$familyId/locations',
      data: {
        'name': name,
        'description': description,
        'parent_id': parentId,
        'photos': photos,
      },
    );
    return Location.fromJson(response.data);
  }

  Future<Location> updateLocation(int locationId, String name, String? description, List<String> photos) async {
    final response = await _dio.put(
      '/api/locations/$locationId',
      data: {
        'name': name,
        'description': description,
        'photos': photos,
      },
    );
    return Location.fromJson(response.data);
  }

  Future<void> deleteLocation(int locationId) async {
    await _dio.delete('/api/locations/$locationId');
  }

  Future<List<Item>> getItems(int familyId) async {
    final response = await _dio.get('/api/families/$familyId/items');
    final list = response.data as List;
    return list.map((item) => Item.fromJson(item)).toList();
  }

  Future<Item> getItem(int itemId) async {
    final response = await _dio.get('/api/items/$itemId');
    return Item.fromJson(response.data);
  }

  Future<Item> createItem(int familyId, String name, String? description, int? locationId, List<String> photos) async {
    final response = await _dio.post(
      '/api/families/$familyId/items',
      data: {
        'name': name,
        'description': description,
        'location_id': locationId,
        'photos': photos,
      },
    );
    return Item.fromJson(response.data);
  }

  Future<Item> updateItem(int itemId, String name, String? description, int? locationId, List<String> photos) async {
    final response = await _dio.put(
      '/api/items/$itemId',
      data: {
        'name': name,
        'description': description,
        'location_id': locationId,
        'photos': photos,
      },
    );
    return Item.fromJson(response.data);
  }

  Future<void> deleteItem(int itemId) async {
    await _dio.delete('/api/items/$itemId');
  }

  Future<Map<String, dynamic>> uploadItemPhoto(Uint8List imageBytes, int familyId, {String itemId = 'new', int photoIndex = 0}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: 'photo.jpg'),
      'family_id': familyId,
      'item_id': itemId,
      'photo_index': photoIndex,
    });
    final response = await _dio.post('/api/upload/item-photo', data: formData);
    return response.data;
  }

  Future<Map<String, dynamic>> uploadLocationPhoto(Uint8List imageBytes, int familyId, {String locationId = 'new', int photoIndex = 0}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: 'loc_photo.jpg'),
      'family_id': familyId,
      'location_id': locationId,
      'photo_index': photoIndex,
    });
    final response = await _dio.post('/api/upload/location-photo', data: formData);
    return response.data;
  }

  Future<Item> checkOutItem(int itemId, int memberId) async {
    final response = await _dio.post(
      '/api/items/$itemId/check-out',
      data: {'member_id': memberId},
    );
    return Item.fromJson(response.data);
  }

  Future<Item> checkInItem(int itemId, int memberId, int? locationId) async {
    final response = await _dio.post(
      '/api/items/$itemId/check-in',
      data: {
        'member_id': memberId,
        'location_id': locationId,
      },
    );
    return Item.fromJson(response.data);
  }

  Future<ItemTraceInfo> traceItem(int itemId) async {
    final response = await _dio.get('/api/items/$itemId/trace');
    return ItemTraceInfo.fromJson(response.data);
  }

  Future<Map<String, dynamic>> printDirect({
    required String qrPayload,
    required String title,
    int? itemId,
    int? locationId,
    int copies = 1,
  }) async {
    final response = await _dio.post(
      '/api/print/direct',
      data: {
        'qr_payload': qrPayload,
        'title': title,
        'item_id': itemId,
        'location_id': locationId,
        'copies': copies,
      },
    );
    return response.data;
  }

  Future<List<ActivityLog>> getActivityLogs(int familyId) async {
    final response = await _dio.get('/api/families/$familyId/logs');
    final list = response.data as List;
    return list.map((item) => ActivityLog.fromJson(item)).toList();
  }

  Future<List<SearchResult>> searchItems(int familyId, String query) async {
    final response = await _dio.get(
      '/api/families/$familyId/search',
      queryParameters: {'q': query},
    );
    final list = response.data as List;
    return list.map((item) => SearchResult.fromJson(item)).toList();
  }
}

final apiService = ApiService();
