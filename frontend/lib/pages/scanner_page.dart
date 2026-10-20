import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import 'item_detail_page.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = parseHexColor(activeMember?.color ?? '#3F51B5');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('掃描標籤 QR Code', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white70),
            tooltip: '開關閃光燈',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
            tooltip: '切換鏡頭',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScannedCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: themeColor, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.indigoAccent),
                    SizedBox(height: 16),
                    Text('辨識與定位中...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '手動輸入 ID 或標籤內容 (例如 101)...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
                    onPressed: () {
                      final val = _manualController.text.trim();
                      if (val.isNotEmpty) _handleScannedCode(val);
                    },
                    child: const Text('查詢'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScannedCode(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      debugPrint('[Scanner] Read code: "$rawValue"');

      if (rawValue.toUpperCase().contains('LOC:') || rawValue.toUpperCase().contains('INV:LOC:')) {
        final locId = _parseId(rawValue);
        if (locId != null) {
          _handleScannedLocation(locId);
        } else {
          _showError('空間標籤格式無效');
        }
      } else {
        final itemId = _parseId(rawValue);
        if (itemId != null) {
          await _handleScannedItem(itemId);
        } else {
          _showError('無法辨識此物品標籤');
        }
      }
    } catch (e) {
      _showError('掃描處理失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
      }
    }
  }

  int? _parseId(String val) {
    if (RegExp(r'^\d+$').hasMatch(val)) return int.tryParse(val);
    final matchColon = RegExp(r'(?:ITEM|LOC|ID):(\d+)', caseSensitive: false).firstMatch(val);
    if (matchColon != null) return int.tryParse(matchColon.group(1)!);
    final matchPrefix = RegExp(r'^(\d+)\s*[:|]').firstMatch(val);
    if (matchPrefix != null) return int.tryParse(matchPrefix.group(1)!);
    return null;
  }

  Future<void> _handleScannedItem(int itemId) async {
    final activeMember = ref.read(activeMemberProvider);
    if (activeMember == null) return;

    ItemTraceInfo trace;
    try {
      trace = await apiService.traceItem(itemId);
    } catch (e) {
      _showError('在庫存中找不到編號為 $itemId 的物品。');
      return;
    }

    final item = trace.item;

    if (item.status == 'checked_in') {
      await ref.read(itemsProvider.notifier).checkOut(item.id, activeMember.id);
      _showSuccess('已為 ${activeMember.name} 登記借出「${item.name}」');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
        );
      }
    } else {
      if (mounted) {
        _showLostItemTraceCard(trace, activeMember);
      }
    }
  }

  void _showLostItemTraceCard(ItemTraceInfo trace, Member activeMember) {
    final item = trace.item;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_searching, color: Colors.amberAccent, size: 28),
                const SizedBox(width: 12),
                Text('遺失物定位溯源', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.name,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('最後借出成員: ${trace.lastCheckedOutBy}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (trace.checkedOutAt != null) ...[
                    const SizedBox(height: 6),
                    Text('借出時間: ${formatDateTime(trace.checkedOutAt!)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    children: [
                      const Icon(Icons.archive_outlined, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '原存放儲存格: ${trace.targetLocationPath}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                icon: const Icon(Icons.check_circle),
                label: Text('一鍵歸回原處 (${trace.targetLocationPath})', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isProcessing = true);
                  try {
                    await ref.read(itemsProvider.notifier).checkIn(item.id, activeMember.id, trace.targetLocationId);
                    _showSuccess('已成功將「${item.name}」歸還至 ${trace.targetLocationPath}');
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
                      );
                    }
                  } catch (e) {
                    _showError('歸還失敗: $e');
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                  _showCustomLocationPicker(item, activeMember);
                },
                child: const Text('歸還至其他抽屜 / 櫃位'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomLocationPicker(Item item, Member activeMember) {
    final locations = ref.read(locationsProvider).value ?? [];
    int? selectedLocId = item.locationId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('選擇歸還抽屜', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    final fullPath = getLocationPath(loc.id, locations);
                    final isSel = selectedLocId == loc.id;
                    return ListTile(
                      leading: Icon(Icons.location_on, color: isSel ? Colors.greenAccent : Colors.white24),
                      title: Text(fullPath, style: TextStyle(color: isSel ? Colors.greenAccent : Colors.white)),
                      onTap: () => setSheetState(() => selectedLocId = loc.id),
                    );
                  },
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await ref.read(itemsProvider.notifier).checkIn(item.id, activeMember.id, selectedLocId);
                  _showSuccess('物品已歸位！');
                },
                child: const Text('確定歸位'),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _handleScannedLocation(int locId) {
    final locations = ref.read(locationsProvider).value ?? [];
    Location? targetLoc;
    try {
      targetLoc = locations.firstWhere((l) => l.id == locId);
    } catch (_) {}

    if (targetLoc == null) {
      _showError('找不到空間編號為 $locId 的儲存格。');
      return;
    }

    final fullPath = getLocationPath(locId, locations);
    final items = ref.read(itemsProvider).value ?? [];
    final itemsInLoc = items.where((i) => i.locationId == locId).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: Text(fullPath, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此儲存格內存放之物品 (${itemsInLoc.length} 件):', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            if (itemsInLoc.isEmpty)
              const Text('目前無任何物品存放於此。', style: TextStyle(color: Colors.white30, fontSize: 13))
            else
              SizedBox(
                width: double.maxFinite,
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemsInLoc.length,
                  itemBuilder: (context, index) {
                    final it = itemsInLoc[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(it.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(it.status == 'checked_in' ? '在庫' : '已借出', style: TextStyle(color: it.status == 'checked_in' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: it.id)));
                      },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('關閉')),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
    }
  }
}
