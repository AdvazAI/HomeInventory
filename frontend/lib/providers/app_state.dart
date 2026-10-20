import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

final familyIdProvider = StateProvider<int>((ref) => 1);

final activeMemberProvider = StateNotifierProvider<ActiveMemberNotifier, Member?>((ref) {
  return ActiveMemberNotifier();
});

class ActiveMemberNotifier extends StateNotifier<Member?> {
  ActiveMemberNotifier() : super(null);

  void selectProfile(Member member) {
    state = member;
  }

  Future<void> loginWithGoogle(String email, String googleId) async {
    final member = await apiService.googleLogin(email, googleId);
    state = member;
  }

  void logout() {
    state = null;
  }
}

final membersProvider = StateNotifierProvider<MembersNotifier, AsyncValue<List<Member>>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return MembersNotifier(familyId);
});

class MembersNotifier extends StateNotifier<AsyncValue<List<Member>>> {
  final int familyId;
  MembersNotifier(this.familyId) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final members = await apiService.getMembers(familyId);
      state = AsyncValue.data(members);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> addMember(String name, String color, String? pincode, String? email) async {
    final newMember = await apiService.createMember(familyId, name, color, pincode, email);
    state.whenData((currentList) {
      state = AsyncValue.data([...currentList, newMember]);
    });
  }
}

final locationsProvider = StateNotifierProvider<LocationsNotifier, AsyncValue<List<Location>>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return LocationsNotifier(familyId, ref);
});

class LocationsNotifier extends StateNotifier<AsyncValue<List<Location>>> {
  final int familyId;
  final Ref ref;

  LocationsNotifier(this.familyId, this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final locations = await apiService.getLocations(familyId);
      state = AsyncValue.data(locations);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<Location> createLocation(String name, String? description, int? parentId, List<String> photos) async {
    final loc = await apiService.createLocation(familyId, name, description, parentId, photos);
    refresh();
    ref.read(locationTreeProvider.notifier).refresh();
    return loc;
  }

  Future<void> editLocation(int locationId, String name, String? description, List<String> photos) async {
    await apiService.updateLocation(locationId, name, description, photos);
    refresh();
    ref.read(locationTreeProvider.notifier).refresh();
  }

  Future<void> removeLocation(int locationId) async {
    await apiService.deleteLocation(locationId);
    refresh();
    ref.read(locationTreeProvider.notifier).refresh();
  }
}

final locationTreeProvider = StateNotifierProvider<LocationTreeNotifier, AsyncValue<List<LocationTreeNode>>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return LocationTreeNotifier(familyId);
});

class LocationTreeNotifier extends StateNotifier<AsyncValue<List<LocationTreeNode>>> {
  final int familyId;
  LocationTreeNotifier(this.familyId) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final tree = await apiService.getLocationTree(familyId);
      state = AsyncValue.data(tree);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }
}

final itemsProvider = StateNotifierProvider<ItemsNotifier, AsyncValue<List<Item>>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return ItemsNotifier(familyId, ref);
});

class ItemsNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  final int familyId;
  final Ref ref;

  ItemsNotifier(this.familyId, this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final items = await apiService.getItems(familyId);
      state = AsyncValue.data(items);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<Item> addItem(String name, String? description, int? locationId, List<String> photos) async {
    final newItem = await apiService.createItem(familyId, name, description, locationId, photos);
    refresh();
    ref.read(activityLogsProvider.notifier).refresh();
    return newItem;
  }

  Future<Item> updateItem(int itemId, String name, String? description, int? locationId, List<String> photos) async {
    final updated = await apiService.updateItem(itemId, name, description, locationId, photos);
    refresh();
    ref.read(activityLogsProvider.notifier).refresh();
    return updated;
  }

  Future<void> deleteItem(int itemId) async {
    await apiService.deleteItem(itemId);
    refresh();
    ref.read(activityLogsProvider.notifier).refresh();
  }

  Future<void> checkOut(int itemId, int memberId) async {
    await apiService.checkOutItem(itemId, memberId);
    refresh();
    ref.read(activityLogsProvider.notifier).refresh();
  }

  Future<void> checkIn(int itemId, int memberId, int? locationId) async {
    await apiService.checkInItem(itemId, memberId, locationId);
    refresh();
    ref.read(activityLogsProvider.notifier).refresh();
  }
}

final activityLogsProvider = StateNotifierProvider<ActivityLogsNotifier, AsyncValue<List<ActivityLog>>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return ActivityLogsNotifier(familyId);
});

class ActivityLogsNotifier extends StateNotifier<AsyncValue<List<ActivityLog>>> {
  final int familyId;
  ActivityLogsNotifier(this.familyId) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final logs = await apiService.getActivityLogs(familyId);
      state = AsyncValue.data(logs);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final familyId = ref.watch(familyIdProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return [];
  }
  return await apiService.searchItems(familyId, query);
});
