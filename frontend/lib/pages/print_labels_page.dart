import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class PrintLabelsPage extends ConsumerStatefulWidget {
  final int? preselectedItemId;
  const PrintLabelsPage({super.key, this.preselectedItemId});

  @override
  ConsumerState<PrintLabelsPage> createState() => _PrintLabelsPageState();
}

class _PrintLabelsPageState extends ConsumerState<PrintLabelsPage> {
  final List<int> _selectedItemIds = [];
  final List<int> _selectedLocationIds = [];
  bool _includeLocations = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItemId != null) {
      _selectedItemIds.add(widget.preselectedItemId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = parseHexColor(activeMember?.color ?? '#3F51B5');

    final items = ref.watch(itemsProvider).value ?? [];
    final locations = ref.watch(locationsProvider).value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Brother QL-700 快速標籤列印', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  color: const Color(0xFF161B26),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '標籤列印設定',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.print, color: Colors.indigoAccent),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('目標印表機: BrotherLabelPtr', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('機種: Brother QL-700 (免開 PDF，直接送印)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('列印類型:', style: TextStyle(color: Colors.white70)),
                          DropdownButton<bool>(
                            value: _includeLocations,
                            dropdownColor: const Color(0xFF161B26),
                            style: const TextStyle(color: Colors.white),
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(value: false, child: Text('物品標籤 (Items)')),
                              DropdownMenuItem(value: true, child: Text('儲存空間標籤 (Locations)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _includeLocations = val);
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _includeLocations ? '選擇儲存格 (${_selectedLocationIds.length})' : '選擇物品 (${_selectedItemIds.length})',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_includeLocations) {
                                  if (_selectedLocationIds.length == locations.length) {
                                    _selectedLocationIds.clear();
                                  } else {
                                    _selectedLocationIds.clear();
                                    _selectedLocationIds.addAll(locations.map((l) => l.id));
                                  }
                                } else {
                                  if (_selectedItemIds.length == items.length) {
                                    _selectedItemIds.clear();
                                  } else {
                                    _selectedItemIds.clear();
                                    _selectedItemIds.addAll(items.map((i) => i.id));
                                  }
                                }
                              });
                            },
                            child: const Text('全選 / 取消', style: TextStyle(color: Colors.indigoAccent, fontSize: 12)),
                          )
                        ],
                      ),
                      Expanded(
                        child: _includeLocations
                            ? _buildLocationsChecklist(locations, themeColor)
                            : _buildItemsChecklist(items, themeColor),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.print_sharp),
                          label: Text(
                            '一鍵直印至 Brother QL-700 (${_includeLocations ? _selectedLocationIds.length : _selectedItemIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _handleDirectPrint(items, locations),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Brother QL-700 標籤排版預覽',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: const Text('規格符合: QR >= 2cm × 2cm | 字串 <= 80字元', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: _hasSelection()
                              ? _buildPreviewGrid(items, locations)
                              : const Center(
                                  child: Text('請自左側勾選欲列印之物品或儲存格。', style: TextStyle(color: Colors.white30)),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isPrinting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.indigoAccent),
                    SizedBox(height: 16),
                    Text('正在將標籤送入 Brother QL-700 印表機佇列...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasSelection() {
    return _includeLocations ? _selectedLocationIds.isNotEmpty : _selectedItemIds.isNotEmpty;
  }

  Widget _buildItemsChecklist(List<Item> items, Color themeColor) {
    if (items.isEmpty) return const Center(child: Text('尚無物品', style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSel = _selectedItemIds.contains(item.id);
        final payload = 'ID:${item.id}|${item.name}';

        return CheckboxListTile(
          value: isSel,
          activeColor: themeColor,
          title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text('字元數: ${payload.length}/80', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedItemIds.add(item.id);
              } else {
                _selectedItemIds.remove(item.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildLocationsChecklist(List<Location> locations, Color themeColor) {
    if (locations.isEmpty) return const Center(child: Text('尚無空間', style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final isSel = _selectedLocationIds.contains(loc.id);
        final payload = 'LOC:${loc.id}|${loc.name}';

        return CheckboxListTile(
          value: isSel,
          activeColor: themeColor,
          title: Text(loc.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text('字元數: ${payload.length}/80', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedLocationIds.add(loc.id);
              } else {
                _selectedLocationIds.remove(loc.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildPreviewGrid(List<Item> items, List<Location> locations) {
    final previewList = <Widget>[];

    if (_includeLocations) {
      for (var id in _selectedLocationIds) {
        try {
          final loc = locations.firstWhere((l) => l.id == id);
          previewList.add(_buildSingleLabelCard('LOC:${loc.id}', loc.name));
        } catch (_) {}
      }
    } else {
      for (var id in _selectedItemIds) {
        try {
          final it = items.firstWhere((i) => i.id == id);
          previewList.add(_buildSingleLabelCard('ID:${it.id}', it.name));
        } catch (_) {}
      }
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: previewList.length,
      itemBuilder: (context, index) => previewList[index],
    );
  }

  Widget _buildSingleLabelCard(String header, String title) {
    final payload = '$header|$title';
    final cleanPayload = payload.length > 80 ? payload.substring(0, 80) : payload;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          QrImageView(
            data: cleanPayload,
            version: QrVersions.auto,
            size: 70,
            gapless: true,
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(header, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.black87, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                const Text('Brother QL-700', style: TextStyle(color: Colors.black38, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDirectPrint(List<Item> items, List<Location> locations) async {
    if (!_hasSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先勾選欲列印之標籤。')));
      return;
    }

    setState(() => _isPrinting = true);
    int successCount = 0;

    try {
      if (_includeLocations) {
        for (var locId in _selectedLocationIds) {
          final loc = locations.firstWhere((l) => l.id == locId);
          final payload = 'LOC:${loc.id}|${loc.name}';
          await apiService.printDirect(qrPayload: payload, title: loc.name, locationId: loc.id);
          successCount++;
        }
      } else {
        for (var itemId in _selectedItemIds) {
          final it = items.firstWhere((i) => i.id == itemId);
          final payload = 'ID:${it.id}|${it.name}';
          await apiService.printDirect(qrPayload: payload, title: it.name, itemId: it.id);
          successCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已直接發送 $successCount 張標籤至 Brother QL-700 (BrotherLabelPtr)！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('列印失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}
