import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../utils/image_compressor.dart';

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

  final List<String> _photoKeys = [];
  final List<Uint8List> _localPhotoBytes = [];
  final List<String> _photoDisplayUrls = [];
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
      _photoKeys.addAll(widget.editItem!.photos);
      _photoDisplayUrls.addAll(widget.editItem!.photoUrls);
      for (int i = 0; i < widget.editItem!.photos.length; i++) {
        _photoSizesInBytes.add(4000);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_photoKeys.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('單一物件最多拍攝 4 張照片。')),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      final familyId = ref.read(familyIdProvider);
      final photoIndex = _photoKeys.length;

      final result = await ImageCompressor.processAndUploadItemPhoto(
        pickedFile: pickedFile,
        familyId: familyId,
        shouldCompress: _compressImages,
        itemId: widget.editItem?.id.toString() ?? 'new',
        photoIndex: photoIndex,
      );

      setState(() {
        _photoKeys.add(result.photoKey);
        _localPhotoBytes.add(result.bytes);
        _photoDisplayUrls.add(result.publicUrl);
        _photoSizesInBytes.add(result.sizeInBytes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('圖片上傳失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoKeys.removeAt(index);
      if (index < _localPhotoBytes.length) _localPhotoBytes.removeAt(index);
      if (index < _photoDisplayUrls.length) _photoDisplayUrls.removeAt(index);
      if (index < _photoSizesInBytes.length) _photoSizesInBytes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeMember = ref.watch(activeMemberProvider);
    final themeColor = parseHexColor(activeMember?.color ?? '#3F51B5');
    final locations = ref.watch(locationsProvider).value ?? [];
    final isEditMode = widget.editItem != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: Text(isEditMode ? '編輯物品' : '登記新物品', style: const TextStyle(color: Colors.white)),
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
                        labelText: '物品名稱 (例如: 螺絲起子、電鑽、杯子)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(12)),
                        errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入概略物品名稱';
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
                        labelText: '存放空間 / 抽屜',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor), borderRadius: BorderRadius.circular(12)),
                      ),
                      items: locations.map((loc) {
                        return DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(
                            getLocationPath(loc.id, locations),
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedLocationId = val),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '簡要用途或備註 (選填，不強制要求填寫)',
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
                          '多角度照片 (${_photoKeys.length}/4)',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white70),
                              tooltip: '拍照',
                              onPressed: () => _pickAndUploadImage(ImageSource.camera),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: Colors.white70),
                              tooltip: '從相簿選擇',
                              onPressed: () => _pickAndUploadImage(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _compressImages,
                          activeColor: themeColor,
                          onChanged: (val) => setState(() => _compressImages = val ?? true),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '啟用尺寸壓縮 (長邊450px，檔案約 3KB ~ 5KB)',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '上傳至 Cloudflare R2，大幅節省儲存與傳輸頻寬。取消勾選則上傳原始畫質。',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_photoKeys.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _photoKeys.length,
                        itemBuilder: (context, index) {
                          final sizeKb = (_photoSizesInBytes.length > index ? _photoSizesInBytes[index] : 4000) / 1024.0;

                          Widget imageWidget;
                          if (index < _localPhotoBytes.length) {
                            imageWidget = Image.memory(_localPhotoBytes[index], fit: BoxFit.cover);
                          } else if (index < _photoDisplayUrls.length) {
                            imageWidget = Image.network(
                              _photoDisplayUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
                            );
                          } else {
                            imageWidget = const Icon(Icons.image, color: Colors.white30);
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: imageWidget),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    '${sizeKb.toStringAsFixed(1)} KB',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePhoto(index),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
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
                          isEditMode ? '儲存變更' : '登記並直接列印 Brother 標籤',
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
              _photoKeys,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('物品已成功更新！')));
          Navigator.pop(context);
        }
      } else {
        final item = await ref.read(itemsProvider.notifier).addItem(
              _nameController.text.trim(),
              _descController.text.trim(),
              _selectedLocationId,
              _photoKeys,
            );
        if (mounted) {
          _showPostRegisterDialog(item, themeColor);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPostRegisterDialog(Item item, Color themeColor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('登記成功！', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('物品「${item.name}」已建置完畢。', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('標籤代碼: ID:${item.id}|${item.name}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('是否立即直接列印至 Brother QL-700 印表機？', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('稍後再印', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
            icon: const Icon(Icons.print),
            label: const Text('直印標籤'),
            onPressed: () async {
              Navigator.pop(dialogContext);
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
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
