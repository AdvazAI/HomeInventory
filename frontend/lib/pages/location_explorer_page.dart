import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../utils/image_compressor.dart';
import 'item_detail_page.dart';
import 'add_item_page.dart';

class LocationExplorerPage extends ConsumerStatefulWidget {
  const LocationExplorerPage({super.key});

  @override
  ConsumerState<LocationExplorerPage> createState() => _LocationExplorerPageState();
}

class _LocationExplorerPageState extends ConsumerState<LocationExplorerPage> {
  int? _currentLocationId;
  String _currentLocationName = '家庭所有空間';
  String? _currentLocationDescription;
  List<String> _currentLocationPhotoUrls = [];

  final List<int?> _navigationStack = [];
  final List<String> _nameStack = [];

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = parseHexColor(activeMember?.color ?? '#3F51B5');

    final locationsAsync = ref.watch(locationsProvider);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      body: locationsAsync.when(
        data: (allLocations) {
          final subLocations = allLocations.where((loc) => loc.parentId == _currentLocationId).toList();

          return itemsAsync.when(
            data: (allItems) {
              final itemsInLocation = allItems.where((item) => item.locationId == _currentLocationId).toList();
              return _buildExplorer(context, allLocations, subLocations, itemsInLocation, themeColor);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
            error: (err, _) => Center(child: Text('載入失敗: $err', style: const TextStyle(color: Colors.redAccent))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
        error: (err, _) => Center(child: Text('載入空間失敗: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildExplorer(
    BuildContext context,
    List<Location> allLocations,
    List<Location> subLocations,
    List<Item> items,
    Color themeColor,
  ) {
    final hasParent = _navigationStack.isNotEmpty;
    final isVirtualRoot = _currentLocationId == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasParent)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: _navigateUp,
                ),
              Expanded(
                child: Text(
                  _currentLocationName,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isVirtualRoot) ...[
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white70),
                  tooltip: '直印此空間標籤至 Brother',
                  onPressed: () => _printLocationLabel(_currentLocationId!, _currentLocationName),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                  tooltip: '修改空間與照片',
                  onPressed: () => _showEditLocationDialog(context, themeColor, allLocations),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '刪除空間格',
                  onPressed: () => _confirmDeleteLocation(context),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white70),
                tooltip: '新增子空間 / 抽屜',
                onPressed: () => _showAddLocationDialog(context),
              ),
            ],
          ),
          if (_currentLocationDescription != null && _currentLocationDescription!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _currentLocationDescription!,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
            ),
          ],
          if (_currentLocationPhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '空間物理實景 (1-3張照片)',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _currentLocationPhotoUrls.length,
                itemBuilder: (context, idx) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _currentLocationPhotoUrls[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '子空間與隔層抽屜 (${subLocations.length})',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (subLocations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white30),
                  SizedBox(width: 12),
                  Text('此處尚未建立更細部的子隔層。', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subLocations.length,
              itemBuilder: (context, index) {
                final loc = subLocations[index];
                return Card(
                  color: const Color(0xFF161B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.folder, color: themeColor),
                    title: Text(loc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: loc.description != null && loc.description!.isNotEmpty
                        ? Text(loc.description!, style: const TextStyle(color: Colors.white38))
                        : null,
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => _navigateDown(loc),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '存放於此的物品 (${items.length})',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              if (_currentLocationId != null)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddItemPage(prefilledLocationId: _currentLocationId)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.indigoAccent),
                  label: const Text('新增物品至此', style: TextStyle(color: Colors.indigoAccent, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('此位置目前沒有存放任何物品。', style: TextStyle(color: Colors.white30, fontSize: 13)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                final isAvailable = it.status == 'checked_in';

                return Card(
                  color: const Color(0xFF161B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: Colors.white.withOpacity(0.05),
                        child: it.photoUrls.isNotEmpty
                            ? Image.network(it.photoUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, color: Colors.white24))
                            : const Icon(Icons.inventory_2, color: Colors.white24),
                      ),
                    ),
                    title: Text(it.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(isAvailable ? '在庫中' : '已借出', style: TextStyle(color: isAvailable ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: it.id))),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _navigateDown(Location loc) {
    setState(() {
      _navigationStack.add(_currentLocationId);
      _nameStack.add(_currentLocationName);
      _currentLocationId = loc.id;
      _currentLocationName = loc.name;
      _currentLocationDescription = loc.description;
      _currentLocationPhotoUrls = loc.photoUrls;
    });
  }

  void _navigateUp() {
    if (_navigationStack.isNotEmpty) {
      final prevId = _navigationStack.removeLast();
      final prevName = _nameStack.removeLast();
      setState(() {
        _currentLocationId = prevId;
        _currentLocationName = prevName;
        final allLocations = ref.read(locationsProvider).value ?? [];
        if (prevId != null) {
          final parentLoc = allLocations.firstWhere((l) => l.id == prevId);
          _currentLocationDescription = parentLoc.description;
          _currentLocationPhotoUrls = parentLoc.photoUrls;
        } else {
          _currentLocationDescription = null;
          _currentLocationPhotoUrls = [];
        }
      });
    }
  }

  void _printLocationLabel(int locId, String locName) async {
    final payload = 'LOC:$locId|$locName';
    try {
      final res = await apiService.printDirect(qrPayload: payload, title: locName, locationId: locId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已直接發送空間標籤至 Brother QL-700 (${res['printer']})！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('列印失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showAddLocationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final List<String> uploadedPhotoKeys = [];
    final List<String> displayUrls = [];
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          title: Text(_currentLocationId == null ? '新增頂層空間 (例如: 客廳、車庫)' : '新增子空間 / 抽屜', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '空間名稱 (例如: 紅色工具箱第二層)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '實體方位描述 (選填)'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('空間物理照片 (${uploadedPhotoKeys.length}/3)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_a_photo, color: Colors.indigoAccent),
                      onPressed: () async {
                        if (uploadedPhotoKeys.length >= 3) return;
                        final picked = await picker.pickImage(source: ImageSource.camera);
                        if (picked != null) {
                          final familyId = ref.read(familyIdProvider);
                          final res = await ImageCompressor.processAndUploadLocationPhoto(
                            pickedFile: picked,
                            familyId: familyId,
                            shouldCompress: true,
                            photoIndex: uploadedPhotoKeys.length,
                          );
                          setDialogState(() {
                            uploadedPhotoKeys.add(res.photoKey);
                            displayUrls.add(res.publicUrl);
                          });
                        }
                      },
                    )
                  ],
                ),
                if (displayUrls.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: displayUrls.length,
                      itemBuilder: (dialogContext, i) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: Image.network(displayUrls[i]).image, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(locationsProvider.notifier).createLocation(
                  name,
                  descController.text.trim().isEmpty ? null : descController.text.trim(),
                  _currentLocationId,
                  uploadedPhotoKeys,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, Color themeColor, List<Location> allLocations) {
    final loc = allLocations.firstWhere((l) => l.id == _currentLocationId);
    final nameController = TextEditingController(text: loc.name);
    final descController = TextEditingController(text: loc.description ?? '');
    final List<String> photoKeys = List.from(loc.photos);
    final List<String> displayUrls = List.from(loc.photoUrls);
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          title: const Text('修改空間資訊與照片', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '空間名稱'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '描述'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('物理實景照片 (${photoKeys.length}/3)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_a_photo, color: Colors.indigoAccent),
                      onPressed: () async {
                        if (photoKeys.length >= 3) return;
                        final picked = await picker.pickImage(source: ImageSource.camera);
                        if (picked != null) {
                          final familyId = ref.read(familyIdProvider);
                          final res = await ImageCompressor.processAndUploadLocationPhoto(
                            pickedFile: picked,
                            familyId: familyId,
                            shouldCompress: true,
                            locationId: loc.id.toString(),
                            photoIndex: photoKeys.length,
                          );
                          setDialogState(() {
                            photoKeys.add(res.photoKey);
                            displayUrls.add(res.publicUrl);
                          });
                        }
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(locationsProvider.notifier).editLocation(
                  loc.id,
                  name,
                  descController.text.trim().isEmpty ? null : descController.text.trim(),
                  photoKeys,
                );
                if (mounted) {
                  setState(() {
                    _currentLocationName = name;
                    _currentLocationDescription = descController.text.trim();
                    _currentLocationPhotoUrls = displayUrls;
                  });
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('確認刪除空間', style: TextStyle(color: Colors.white)),
        content: Text('確定要刪除「$_currentLocationName」嗎？若空間內尚有物品或子隔層，系統將會阻擋以防資料遺失。', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await ref.read(locationsProvider.notifier).removeLocation(_currentLocationId!);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _navigateUp();
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗: $e'), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
  }
}
