import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'add_item_page.dart';
import 'print_labels_page.dart';

class ItemDetailPage extends ConsumerStatefulWidget {
  final int itemId;
  const ItemDetailPage({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    if (activeMember == null) return const SizedBox();

    final themeColor = _parseHexColor(activeMember.color);
    final itemsAsync = ref.watch(itemsProvider);
    
    // Find item in state
    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Item Details', style: TextStyle(color: Colors.white)),
        actions: [
          itemsAsync.when(
            data: (items) {
              final item = _findItem(items);
              if (item == null) return const SizedBox();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white70),
                    tooltip: 'Print Label',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrintLabelsPage(preselectedItemId: item.id),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    tooltip: 'Edit Item',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddItemPage(editItem: item),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Delete Item',
                    onPressed: () => _confirmDelete(context, item),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          )
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          final item = _findItem(items);
          if (item == null) {
            return const Center(child: Text('Item not found.', style: TextStyle(color: Colors.white54)));
          }
          return _buildContent(context, item, activeMember, themeColor);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
        error: (err, stack) => Center(child: Text('Error loading item details: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Item? _findItem(List<Item> items) {
    try {
      return items.firstWhere((item) => item.id == widget.itemId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildContent(BuildContext context, Item item, Member activeMember, Color themeColor) {
    final isAvailable = item.status == 'checked_in';
    final statusColor = isAvailable ? Colors.greenAccent : Colors.orangeAccent;
    
    // Get location path
    final locations = ref.watch(locationsProvider).value ?? [];
    final locationName = _getLocationPath(item.locationId, locations);

    // Get members list to map names
    final members = ref.watch(membersProvider).value ?? [];
    String checkedOutByName = 'Unknown Member';
    if (item.checkedOutByMemberId != null) {
      try {
        checkedOutByName = members.firstWhere((m) => m.id == item.checkedOutByMemberId).name;
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo Carousel or Placeholder
          _buildPhotoViewer(item.photos),
          const SizedBox(height: 24),

          // Name and Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  isAvailable ? 'Available' : 'Taken',
                  style: GoogleFonts.inter(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Stored location breadcrumbs / checked out status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isAvailable ? Icons.location_on : Icons.person,
                  color: isAvailable ? Colors.indigoAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAvailable ? 'Stored Location' : 'Checked Out By',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAvailable ? locationName : checkedOutByName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (!isAvailable && item.checkedOutAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'At: ${_formatDateTime(item.checkedOutAt!)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white30),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Description',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            item.description == null || item.description!.isEmpty
                ? 'No description provided.'
                : item.description!,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Action Button Check-in / Check-out
          if (_isActionLoading)
            const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          else
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? Colors.orangeAccent : Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _handleStatusToggle(context, item, activeMember),
                icon: Icon(isAvailable ? Icons.logout : Icons.login),
                label: Text(
                  isAvailable ? 'Check Out This Item' : 'Return / Check In Item',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            
          const SizedBox(height: 32),
          
          // Activity History Log title
          Text(
            'Activity History (This Month)',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _buildItemLogHistory(item.id, members),
        ],
      ),
    );
  }

  Widget _buildPhotoViewer(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white10),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: PageView.builder(
          itemCount: photos.length,
          itemBuilder: (context, index) {
            return Image.network(photos[index], fit: BoxFit.cover);
          },
        ),
      ),
    );
  }

  Widget _buildItemLogHistory(int itemId, List<Member> members) {
    final logsAsync = ref.watch(activityLogsProvider);
    
    return logsAsync.when(
      data: (allLogs) {
        final itemLogs = allLogs.where((log) => log.itemId == itemId).toList();
        if (itemLogs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
            child: const Text('No activity logs recorded for this item.', style: TextStyle(color: Colors.white30, fontSize: 13)),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemLogs.length,
          itemBuilder: (context, index) {
            final log = itemLogs[index];
            final isCheckOut = log.action == 'check_out';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isCheckOut ? Icons.logout : Icons.login,
                    color: isCheckOut ? Colors.orangeAccent : Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log.memberName} ${isCheckOut ? 'took it' : 'returned it'}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.locationName,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDateTime(log.createdAt),
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }

  void _handleStatusToggle(BuildContext context, Item item, Member activeMember) async {
    setState(() => _isActionLoading = true);
    try {
      if (item.status == 'checked_in') {
        // Simple check out action
        await ref.read(itemsProvider.notifier).checkOut(item.id, activeMember.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.name} checked out successfully.')),
          );
        }
      } else {
        // Return item - Show dialog to select storage unit to check in
        _showCheckInLocationPicker(context, item, activeMember);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showCheckInLocationPicker(BuildContext context, Item item, Member activeMember) {
    final locations = ref.read(locationsProvider).value ?? [];
    int? selectedLocId = item.locationId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Return Location',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the container/cabinet where this item is being returned.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    final fullPath = _getLocationPath(loc.id, locations);
                    final isSelected = selectedLocId == loc.id;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.location_on, color: isSelected ? Colors.greenAccent : Colors.white24),
                      title: Text(
                        fullPath,
                        style: TextStyle(
                          color: isSelected ? Colors.greenAccent : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        setSheetState(() {
                          selectedLocId = loc.id;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isActionLoading = true);
                    try {
                      await ref.read(itemsProvider.notifier).checkIn(item.id, activeMember.id, selectedLocId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.name} successfully returned.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Check in failed: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isActionLoading = false);
                    }
                  },
                  child: const Text('Confirm Return', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to permanently delete ${item.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref.read(itemsProvider.notifier).deleteItem(item.id);
              if (mounted) {
                Navigator.pop(context); // Go back from detail view
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} deleted.')),
                );
              }
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  String _getLocationPath(int? locId, List<Location> locations) {
    if (locId == null) return 'No Location';
    final pathNodes = [];
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
    return pathNodes.isNotEmpty ? pathNodes.join(' > ') : 'Unknown';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute';
  }

  Color _parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.indigoAccent;
    }
  }
}
