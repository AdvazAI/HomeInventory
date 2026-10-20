import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import 'profile_selection_page.dart';
import 'item_detail_page.dart';
import 'location_explorer_page.dart';
import 'scanner_page.dart';
import 'add_item_page.dart';
import 'print_labels_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    if (activeMember == null) {
      return const ProfileSelectionPage();
    }

    final themeColor = parseHexColor(activeMember.color);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        elevation: 0,
        title: Text(
          '家庭庫存管理',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '列印 Brother 標籤',
            icon: const Icon(Icons.print, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrintLabelsPage()),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(activeMemberProvider.notifier).logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ProfileSelectionPage()),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: themeColor,
                    child: Text(
                      activeMember.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeMember.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz, size: 14, color: Colors.white54),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildItemsTab(themeColor),
          const LocationExplorerPage(),
          _buildLogsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF161B26),
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: '庫存物品',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_outlined),
            activeIcon: Icon(Icons.folder),
            label: '儲存空間',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_toggle_off_outlined),
            activeIcon: Icon(Icons.history),
            label: '借還記錄',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_item_fab',
            backgroundColor: const Color(0xFF161B26),
            foregroundColor: themeColor,
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddItemPage()),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'scan_fab',
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            child: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScannerPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab(Color themeColor) {
    final query = ref.watch(searchQueryProvider);
    final itemsAsync = ref.watch(itemsProvider);
    final searchAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              ref.read(searchQueryProvider.notifier).state = val;
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '輸入關鍵字搜尋 (例如: 電鑽、起子、杯子)...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              fillColor: const Color(0xFF161B26),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: query.isNotEmpty
              ? searchAsync.when(
                  data: (results) => _buildSearchResults(results),
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
                  error: (err, _) => Center(child: Text('搜尋錯誤: $err', style: const TextStyle(color: Colors.redAccent))),
                )
              : itemsAsync.when(
                  data: (items) => _buildItemsGrid(items),
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
                  error: (err, _) => Center(child: Text('載入失敗: $err', style: const TextStyle(color: Colors.redAccent))),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(List<SearchResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('查無符合之物品。', style: GoogleFonts.inter(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final res = results[index];
        final item = res.item;
        final isAvailable = item.status == 'checked_in';
        final statusColor = isAvailable ? Colors.greenAccent : Colors.orangeAccent;

        return Card(
          color: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 50,
                height: 50,
                color: Colors.white.withOpacity(0.05),
                child: item.photoUrls.isNotEmpty
                    ? Image.network(item.photoUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white24))
                    : const Icon(Icons.inventory_2, color: Colors.white24),
              ),
            ),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(res.locationPath, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('相關度: ${(res.score * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(isAvailable ? '在庫' : '已借出', style: TextStyle(color: statusColor, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsGrid(List<Item> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('目前庫存中尚無任何物品。', style: GoogleFonts.inter(color: Colors.white38)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              ),
              child: const Text('新增第一件物品'),
            )
          ],
        ),
      );
    }

    final locations = ref.watch(locationsProvider).value ?? [];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isAvailable = item.status == 'checked_in';
        final statusColor = isAvailable ? Colors.greenAccent : Colors.orangeAccent;
        final locPath = getLocationPath(item.locationId, locations);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.white.withOpacity(0.02),
                      child: item.photoUrls.isNotEmpty
                          ? Image.network(
                              item.photoUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 40, color: Colors.white10),
                            )
                          : const Icon(Icons.inventory_2, size: 40, color: Colors.white10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locPath,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAvailable ? '在庫' : '已借出',
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    final logsAsync = ref.watch(activityLogsProvider);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('目前尚無借還活動紀錄。', style: TextStyle(color: Colors.white30)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isCheckOut = log.action == 'check_out';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isCheckOut ? Icons.logout : Icons.login,
                    color: isCheckOut ? Colors.orangeAccent : Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            children: [
                              TextSpan(text: log.memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: isCheckOut ? ' 取用了 ' : ' 歸還了 '),
                              TextSpan(text: log.itemName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(log.locationName, style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
      error: (err, _) => Center(child: Text('日誌載入失敗: $err', style: const TextStyle(color: Colors.redAccent))),
    );
  }
}
