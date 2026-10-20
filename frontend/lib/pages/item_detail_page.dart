import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import 'add_item_page.dart';

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

    final themeColor = parseHexColor(activeMember.color);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('物品詳情', style: TextStyle(color: Colors.white)),
        actions: [
          itemsAsync.when(
            data: (items) {
              final item = _findItem(items);
              if (item == null) return const SizedBox();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white70),
                    tooltip: '快速列印 Brother 標籤',
                    onPressed: () => _printDirectLabel(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    tooltip: '編輯物品',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddItemPage(editItem: item)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: '刪除物品',
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
            return const Center(child: Text('找不到此物品。', style: TextStyle(color: Colors.white54)));
          }
          return _buildContent(context, item, activeMember, themeColor);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
        error: (err, _) => Center(child: Text('載入失敗: $err', style: const TextStyle(color: Colors.redAccent))),
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

    final locations = ref.watch(locationsProvider).value ?? [];
    final locationName = getLocationPath(item.locationId, locations);

    final members = ref.watch(membersProvider).value ?? [];
    String checkedOutByName = '未知成員';
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
          _buildPhotoViewer(item.photoUrls),
          const SizedBox(height: 24),
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
                  isAvailable ? '在庫中' : '借出中',
                  style: GoogleFonts.inter(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
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
                        isAvailable ? '儲存位置' : '借出成員',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAvailable ? locationName : checkedOutByName,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (!isAvailable && item.checkedOutAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '借出時間: ${formatDateTime(item.checkedOutAt!)}',
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
          Text(
            '物品備註',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            item.description == null || item.description!.isEmpty ? '無額外備註。' : item.description!,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 32),
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
                  isAvailable ? '登記借出 (Check Out)' : '物品歸還 (Check In)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          const SizedBox(height: 32),
          Text(
            '活動歷史 (保留 30 天)',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _buildItemLogHistory(item.id),
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
          child: Icon(Icons.inventory_2, size: 64, color: Colors.white10),
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
            return Image.network(
              photos[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white24, size: 48),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemLogHistory(int itemId) {
    final logsAsync = ref.watch(activityLogsProvider);

    return logsAsync.when(
      data: (allLogs) {
        final itemLogs = allLogs.where((log) => log.itemId == itemId).toList();
        if (itemLogs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
            child: const Text('尚無借還活動紀錄。', style: TextStyle(color: Colors.white30, fontSize: 13)),
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
                          '${log.memberName} ${isCheckOut ? '取用' : '歸還'}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(log.locationName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(formatDateTime(log.createdAt), style: const TextStyle(color: Colors.white30, fontSize: 11)),
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
        await ref.read(itemsProvider.notifier).checkOut(item.id, activeMember.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已借出「${item.name}」')));
        }
      } else {
        _showCheckInLocationPicker(context, item, activeMember);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e'), backgroundColor: Colors.redAccent));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('選擇歸還之儲存格', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('請選擇要將此物品歸還存放至哪一個抽屜或儲物格：', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    final fullPath = getLocationPath(loc.id, locations);
                    final isSelected = selectedLocId == loc.id;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.location_on, color: isSelected ? Colors.greenAccent : Colors.white24),
                      title: Text(fullPath, style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white, fontSize: 14)),
                      onTap: () => setSheetState(() => selectedLocId = loc.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isActionLoading = true);
                    try {
                      await ref.read(itemsProvider.notifier).checkIn(item.id, activeMember.id, selectedLocId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已成功歸還「${item.name}」')));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('歸還失敗: $e'), backgroundColor: Colors.redAccent));
                      }
                    } finally {
                      if (mounted) setState(() => _isActionLoading = false);
                    }
                  },
                  child: const Text('確認歸位', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _printDirectLabel(Item item) async {
    final qrPayload = 'ID:${item.id}|${item.name}';
    try {
      final res = await apiService.printDirect(
        qrPayload: qrPayload,
        title: item.name,
        itemId: item.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已直接發送標籤至 Brother QL-700 (${res['printer']})！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('直印失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('確認刪除物品', style: TextStyle(color: Colors.white)),
        content: Text('確定要永久刪除「${item.name}」嗎？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref.read(itemsProvider.notifier).deleteItem(item.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
