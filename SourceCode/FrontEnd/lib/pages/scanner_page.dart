import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
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
    final themeColor = _parseHexColor(activeMember?.color ?? '#3F51B5');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Scan QR Label', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white70),
            tooltip: 'Toggle Flash',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mobile Scanner view
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScannedCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Scanning Overlay Frame
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
          
          // Processing Loader overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.indigoAccent),
                    SizedBox(height: 16),
                    Text('Processing tag...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

          // Manual Entry bottom panel
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter ID or code manually...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final val = _manualController.text.trim();
                      if (val.isNotEmpty) {
                        _handleScannedCode(val);
                      }
                    },
                    child: const Text('Go'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _handleScannedCode(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Stop scanner preview temporarily
    _scannerController.stop();

    try {
      debugPrint('[Scanner] Read raw code: "$rawValue"');

      // Parsing patterns:
      // Item format examples: "INV:ITEM:123", "ID: 123 | Name: Screwdriver", "123: Screwdriver", "123"
      // Location format examples: "INV:LOC:456", "LOC: 456", "LOC:456"

      if (rawValue.toUpperCase().contains('LOC:') || rawValue.toUpperCase().contains('INV:LOC:')) {
        // SCANNED A LOCATION QR
        final locId = _parseId(rawValue);
        if (locId != null) {
          _handleScannedLocation(locId);
        } else {
          _showError('Invalid location QR format');
        }
      } else {
        // SCANNED AN ITEM QR (Default assumption)
        final itemId = _parseId(rawValue);
        if (itemId != null) {
          await _handleScannedItem(itemId);
        } else {
          _showError('Invalid Item tag format');
        }
      }
    } catch (e) {
      _showError('Scanning failed: $e');
    } finally {
      // Resume scanner if still mounted
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
      }
    }
  }

  int? _parseId(String val) {
    // 1. Check numeric-only
    if (RegExp(r'^\d+$').hasMatch(val)) {
      return int.tryParse(val);
    }
    // 2. Check INV:ITEM:123 or INV:LOC:456
    final matchColon = RegExp(r'(?:ITEM|LOC):(\d+)', caseSensitive: false).firstMatch(val);
    if (matchColon != null) {
      return int.tryParse(matchColon.group(1)!);
    }
    // 3. Check 123: Screwdriver
    final matchPrefix = RegExp(r'^(\d+)\s*:').firstMatch(val);
    if (matchPrefix != null) {
      return int.tryParse(matchPrefix.group(1)!);
    }
    // 4. Check ID: 123
    final matchId = RegExp(r'ID\s*:\s*(\d+)', caseSensitive: false).firstMatch(val);
    if (matchId != null) {
      return int.tryParse(matchId.group(1)!);
    }
    return null;
  }

  Future<void> _handleScannedItem(int itemId) async {
    final activeMember = ref.read(activeMemberProvider);
    if (activeMember == null) return;

    // Fetch latest status
    Item item;
    try {
      item = await apiService.getItem(itemId);
    } catch (e) {
      _showError('Item ID $itemId not found in inventory.');
      return;
    }

    if (item.status == 'checked_in') {
      // Toggle to Checked-out immediately for the active profile
      final updatedItem = await ref.read(itemsProvider.notifier).addItem(
        item.name, // wait, Riverpod notifier has custom actions
        item.description, 
        item.locationId, 
        item.photos
      );
      // Wait, we defined helper actions: checkOut(itemId, memberId) and checkIn(itemId, memberId, locationId)
      await ref.read(itemsProvider.notifier).checkOut(item.id, activeMember.id);
      
      _showSuccess('Checked out "${item.name}" for ${activeMember.name}');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
        );
      }
    } else {
      // Checked out already. We need to check it in!
      // Ask user to confirm where to return it (Quick location prompt)
      if (mounted) {
        _promptCheckInLocation(item);
      }
    }
  }

  void _promptCheckInLocation(Item item) {
    final locations = ref.read(locationsProvider).value ?? [];
    final activeMember = ref.read(activeMemberProvider);
    if (activeMember == null) return;

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
              Text(
                'Return "${item.name}"',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Select returning storage cabinet/bin:',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
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
                        style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white, fontSize: 14),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(context); // Close bottom sheet
                    setState(() => _isProcessing = true);
                    try {
                      await ref.read(itemsProvider.notifier).checkIn(item.id, activeMember.id, selectedLocId);
                      _showSuccess('Successfully returned "${item.name}"');
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
                        );
                      }
                    } catch (e) {
                      _showError('Check-in failed: $e');
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
                  child: const Text('Confirm Check In', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _handleScannedLocation(int locId) {
    final locations = ref.read(locationsProvider).value ?? [];
    final locExists = locations.any((l) => l.id == locId);
    if (!locExists) {
      _showError('Storage Location ID $locId not found.');
      return;
    }
    
    final fullPath = _getLocationPath(locId, locations);
    _showSuccess('Location identified: "$fullPath"');
    
    // We can direct them to the explorer page preselected with this location!
    // For simplicity, we pop back to tell them they identified the location, 
    // or pop back showing a toast. Let's show a dialog of items inside this location.
    _showLocationSummaryDialog(locId, fullPath);
  }

  void _showLocationSummaryDialog(int locId, String path) {
    final items = ref.read(itemsProvider).value ?? [];
    final itemsInLoc = items.where((i) => i.locationId == locId).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: Text(path, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items stored here: (${itemsInLoc.length})', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            if (itemsInLoc.isEmpty)
              const Text('Empty storage space.', style: TextStyle(color: Colors.white30, fontSize: 13))
            else
              SizedBox(
                width: double.maxFinite,
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemsInLoc.length,
                  itemBuilder: (context, index) {
                    final item = itemsInLoc[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(item.status == 'checked_in' ? 'Available' : 'Taken', style: TextStyle(color: item.status == 'checked_in' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
