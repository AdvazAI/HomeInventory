import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../providers/app_state.dart';
import '../models/models.dart';
import 'print_labels_page.dart';

class AddItemPage extends ConsumerStatefulWidget {
  final Item? editItem;
  final int? prefilledLocationId;

  const AddItemPage({super.key, this.editItem, this.prefilledLocationId});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  int? _selectedLocationId;
  
  final List<String> _base64Photos = [];
  final List<int> _photoSizesInBytes = [];
  
  bool _compressImages = true;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editItem?.name ?? '');
    _descController = TextEditingController(text: widget.editItem?.description ?? '');
    _selectedLocationId = widget.editItem?.locationId ?? widget.prefilledLocationId;

    if (widget.editItem != null) {
      _base64Photos.addAll(widget.editItem!.photos);
      for (var photo in widget.editItem!.photos) {
        _photoSizesInBytes.add(_estimateBase64SizeInBytes(photo));
      }
    }
  }

  int _estimateBase64SizeInBytes(String base64str) {
    try {
      final clean = base64str.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
      return base64.decode(clean).length;
    } catch (_) {
      return 4000;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_base64Photos.length >= 3) { // Enforce 1-3 photos limit
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed per item.')),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      String processedBase64;
      int processedSize;

      if (_compressImages) {
        final img.Image? decoded = img.decodeImage(rawBytes);
        if (decoded != null) {
          int newWidth, newHeight;
          if (decoded.width >= decoded.height) {
            newWidth = 450;
            newHeight = (decoded.height * (450 / decoded.width)).round();
          } else {
            newHeight = 450;
            newWidth = (decoded.width * (450 / decoded.height)).round();
          }
          
          final img.Image resized = img.copyResize(decoded, width: newWidth, height: newHeight);
          final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 18));
          
          processedBase64 = 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';
          processedSize = jpgBytes.length;
        } else {
          processedBase64 = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
          processedSize = rawBytes.length;
        }
      } else {
        final extension = pickedFile.name.split('.').last.toLowerCase();
        processedBase64 = 'data:image/$extension;base64,${base64Encode(rawBytes)}';
        processedSize = rawBytes.length;
      }

      setState(() {
        _base64Photos.add(processedBase64);
        _photoSizesInBytes.add(processedSize);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking/compressing image: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _base64Photos.removeAt(index);
      _photoSizesInBytes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = _parseHexColor(activeMember?.color ?? '#3F51B5');
    final locations = ref.watch(locationsProvider).value ?? [];

    final isEditMode = widget.editItem != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: Text(isEditMode ? 'Edit Item' : 'Register New Item', style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(12)),
                        errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      value: _selectedLocationId,
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF161B26),
                      decoration: InputDecoration(
                        labelText: 'Location / Storage Bin',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(12)),
                      ),
                      items: locations.map((loc) {
                        return DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(
                            _getLocationPath(loc.id, locations),
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedLocationId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Photos (${_base64Photos.length}/3)', // Limit to 3 photos
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white70),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: Colors.white70),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Checkbox(
                          value: _compressImages,
                          activeColor: themeColor,
                          onChanged: (val) {
                            setState(() {
                              _compressImages = val ?? true;
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compress & resize images (Target 3KB - 5KB)',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Saves cloud storage using high-efficiency JPEG compression.',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_base64Photos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _base64Photos.length,
                        itemBuilder: (context, index) {
                          final photoBase64 = _base64Photos[index];
                          final sizeKb = _photoSizesInBytes[index] / 1024.0;
                          final cleanBase64 = photoBase64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
                          final bytes = base64Decode(cleanBase64);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                  image: DecorationImage(
                                    image: MemoryImage(bytes),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${sizeKb.toStringAsFixed(1)} KB',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _removePhoto(index),
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

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _saveItem(themeColor),
                        child: Text(
                          isEditMode ? 'Save Changes' : 'Register & Print Label',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _saveItem(Color themeColor) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.editItem != null) {
        await ref.read(itemsProvider.notifier).updateItem(
              widget.editItem!.id,
              _nameController.text.trim(),
              _descController.text.trim(),
              _selectedLocationId,
              _base64Photos,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        final item = await ref.read(itemsProvider.notifier).addItem(
              _nameController.text.trim(),
              _descController.text.trim(),
              _selectedLocationId,
              _base64Photos,
            );
        if (mounted) {
          _showRegistrationWizard(item, themeColor);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegistrationWizard(Item item, Color themeColor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            const Text('Item Registered!', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${item.name}" has been registered in the database.', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text('Next Steps:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('1. Generate and print the QL-700 QR label.\n2. Scan the destination Storage Cell QR to place the item.', style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Go back to items list
            },
            child: const Text('Close / Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PrintLabelsPage(preselectedItemId: item.id),
                ),
              );
            },
            child: const Text('Print Label Now'),
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
