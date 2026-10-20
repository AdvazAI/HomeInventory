import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:dio/dio.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'item_detail_page.dart';
import 'add_item_page.dart';

class LocationExplorerPage extends ConsumerStatefulWidget {
  const LocationExplorerPage({super.key});

  @override
  ConsumerState<LocationExplorerPage> createState() => _LocationExplorerPageState();
}

class _LocationExplorerPageState extends ConsumerState<LocationExplorerPage> {
  int? _currentLocationId;
  String _currentLocationName = 'Home';
  String? _currentLocationDescription;
  List<String> _currentLocationPhotos = [];

  // Stack of parent IDs to navigate back up
  final List<int?> _navigationStack = [];
  final List<String> _nameStack = [];
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = _parseHexColor(activeMember?.color ?? '#3F51B5');
    
    final locationsAsync = ref.watch(locationsProvider);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : locationsAsync.when(
            data: (allLocations) {
              final subLocations = allLocations.where((loc) => loc.parentId == _currentLocationId).toList();
              
              return itemsAsync.when(
                data: (allItems) {
                  final itemsInLocation = allItems.where((item) => item.locationId == _currentLocationId).toList();
                  return _buildExplorer(context, subLocations, itemsInLocation, themeColor);
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
                error: (err, stack) => Center(child: Text('Error loading items: $err', style: const TextStyle(color: Colors.redAccent))),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
            error: (err, stack) => Center(child: Text('Error loading locations: $err', style: const TextStyle(color: Colors.redAccent))),
          ),
    );
  }

  Widget _buildExplorer(
    BuildContext context, 
    List<Location> subLocations, 
    List<Item> items, 
    Color themeColor
  ) {
    final hasParent = _navigationStack.isNotEmpty;
    final isVirtualRoot = _currentLocationId == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs, Edit, Delete, & Add Buttons
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
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                  tooltip: 'Edit Location Details',
                  onPressed: () => _showEditLocationDialog(context, themeColor),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Location Cell',
                  onPressed: () => _confirmDeleteLocation(context),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white70),
                tooltip: 'Add Sub-location',
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
          
          // Space Photos (1-3 photos showing location layout)
          if (_currentLocationPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _currentLocationPhotos.length,
                itemBuilder: (context, idx) {
                  final cleanBase64 = _currentLocationPhotos[idx].replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
                  final bytes = base64Decode(cleanBase64);

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      image: DecorationImage(
                        image: MemoryImage(bytes),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Sub-locations Section
          Text(
            'Sub-locations & Storage Units',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          if (subLocations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white30),
                  const SizedBox(width: 12),
                  Text(
                    'No sub-locations configured here.',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  ),
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
                    title: Text(
                      loc.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
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

          // Items in Location Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Stored Here',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              if (_currentLocationId != null)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddItemPage(prefilledLocationId: _currentLocationId),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.indigoAccent),
                  label: const Text('Add Item', style: TextStyle(color: Colors.indigoAccent, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No items directly in this location.',
                  style: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isAvailable = item.status == 'checked_in';

                return Card(
                  color: const Color(0xFF161B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: Colors.white.withOpacity(0.05),
                        child: item.photos.isNotEmpty
                            ? Image.network(item.photos.first, fit: BoxFit.cover)
                            : const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 20),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isAvailable ? 'Available' : 'Checked Out',
                      style: TextStyle(
                        color: isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ItemDetailPage(itemId: item.id)),
                    ),
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
      _currentLocationPhotos = loc.photos;
    });
  }

  void _navigateUp() {
    if (_navigationStack.isNotEmpty) {
      final prevId = _navigationStack.removeLast();
      final prevName = _nameStack.removeLast();
      
      Location? parentLoc;
      if (prevId != null) {
        final locs = ref.read(locationsProvider).value ?? [];
        parentLoc = locs.firstWhere((l) => l.id == prevId);
      }

      setState(() {
        _currentLocationId = prevId;
        _currentLocationName = prevName;
        _currentLocationDescription = parentLoc?.description;
        _currentLocationPhotos = parentLoc?.photos ?? [];
      });
    }
  }

  void _showAddLocationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Storage Location', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Location Name (e.g. Drawer B)',
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.indigoAccent), borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description / Notes',
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.indigoAccent), borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref.read(locationsProvider.notifier).createLocation(
                  name,
                  descController.text.trim(),
                  _currentLocationId,
                  [], // Photos empty initially
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, Color themeColor) {
    final nameController = TextEditingController(text: _currentLocationName);
    final descController = TextEditingController(text: _currentLocationDescription ?? '');
    final List<String> localPhotos = List.from(_currentLocationPhotos);
    bool isDialogLoading = false;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isDialogLoading) {
            return const AlertDialog(
              backgroundColor: Color(0xFF161B26),
              content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            );
          }

          Future<void> pickLocPhoto(ImageSource source) async {
            if (localPhotos.length >= 3) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 photos allowed.')));
              return;
            }
            final XFile? file = await picker.pickImage(source: source);
            if (file == null) return;

            setDialogState(() => isDialogLoading = true);
            try {
              final bytes = await file.readAsBytes();
              final img.Image? decoded = img.decodeImage(bytes);
              String base64str;
              if (decoded != null) {
                // Resize: long edge to 450px
                int newWidth, newHeight;
                if (decoded.width >= decoded.height) {
                  newWidth = 450;
                  newHeight = (decoded.height * (450 / decoded.width)).round();
                } else {
                  newHeight = 450;
                  newWidth = (decoded.width * (450 / decoded.height)).round();
                }
                final img.Image resized = img.copyResize(decoded, width: newWidth, height: newHeight);
                final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 18));
                base64str = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
              } else {
                base64str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              }
              setDialogState(() => localPhotos.add(base64str));
            } catch (e) {
              debugPrint('Photo compress error: $e');
            } finally {
              setDialogState(() => isDialogLoading = false);
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF161B26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Storage Cell Details', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Description / Location Guide',
                      labelStyle: const TextStyle(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Photo picker headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Photos (${localPhotos.length}/3)', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white70), onPressed: () => pickLocPhoto(ImageSource.camera)),
                          IconButton(icon: const Icon(Icons.photo_library, size: 18, color: Colors.white70), onPressed: () => pickLocPhoto(ImageSource.gallery)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Picked Photos grid
                  if (localPhotos.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: localPhotos.length,
                        itemBuilder: (context, idx) {
                          final clean = localPhotos[idx].replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
                          final photoBytes = base64Decode(clean);
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                  image: DecorationImage(image: MemoryImage(photoBytes), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => localPhotos.removeAt(idx)),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(context); // Close dialog
                    setState(() => _isLoading = true);
                    try {
                      await ref.read(locationsProvider.notifier).editLocation(
                        _currentLocationId!,
                        newName,
                        descController.text.trim(),
                        localPhotos,
                      );
                      setState(() {
                        _currentLocationName = newName;
                        _currentLocationDescription = descController.text.trim();
                        _currentLocationPhotos = localPhotos;
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update location cell: $e'), backgroundColor: Colors.redAccent));
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child: const Text('Save'),
              )
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Delete Storage Cell', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to permanently delete "$_currentLocationName"? This action cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              setState(() => _isLoading = true);
              try {
                await ref.read(locationsProvider.notifier).removeLocation(_currentLocationId!);
                
                // Pop navigation stack to parent location
                _navigateUp();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location deleted successfully.')));
                }
              } catch (e) {
                String errorMsg = e.toString();
                if (e is DioException) {
                  if (e.response != null && e.response!.data != null) {
                    final data = e.response!.data;
                    if (data is Map && data.containsKey('detail')) {
                      errorMsg = data['detail'];
                    }
                  }
                }
                
                // Show Warning constraints alert dialog
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF161B26),
                      title: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orangeAccent),
                          const SizedBox(width: 8),
                          Text('Deletion Blocked', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                      content: Text(
                        errorMsg.contains('detail:') ? errorMsg.split('detail:').last : errorMsg,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK', style: TextStyle(color: Colors.indigoAccent)),
                        )
                      ],
                    ),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
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
