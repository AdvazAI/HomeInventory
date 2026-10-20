import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import '../providers/app_state.dart';
import '../models/models.dart';
import 'scanner_page.dart';

class PrintLabelsPage extends ConsumerStatefulWidget {
  final int? preselectedItemId;
  const PrintLabelsPage({super.key, this.preselectedItemId});

  @override
  ConsumerState<PrintLabelsPage> createState() => _PrintLabelsPageState();
}

class _PrintLabelsPageState extends ConsumerState<PrintLabelsPage> {
  final List<int> _selectedItemIds = [];
  double _labelSizeCm = 3.0; // Slider value between 2.0 and 8.0 cm (Min 2cm requirement)
  bool _includeLocations = false;
  final List<int> _selectedLocationIds = [];
  String _printFormat = 'pdf';
  bool _isLoading = false;

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
    final themeColor = _parseHexColor(activeMember?.color ?? '#3F51B5');
    
    final items = ref.watch(itemsProvider).value ?? [];
    final locations = ref.watch(locationsProvider).value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Print QR Code Labels', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Side: Settings Panel
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF161B26),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Label Configurations',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  // Label size slider
                  Text(
                    'Physical Size: ${_labelSizeCm.toStringAsFixed(1)} cm × ${_labelSizeCm.toStringAsFixed(1)} cm',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  Slider(
                    value: _labelSizeCm,
                    min: 2.0, // Strict minimum 2x2 cm requirement
                    max: 8.0,
                    divisions: 12,
                    activeColor: themeColor,
                    inactiveColor: Colors.white24,
                    label: '${_labelSizeCm.toStringAsFixed(1)} cm',
                    onChanged: (val) {
                      setState(() {
                        _labelSizeCm = val;
                      });
                    },
                  ),
                  const Text(
                    'Note: QR codes printed under 2cm may be difficult for camera lens focusing.',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Export Format',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _printFormat,
                    dropdownColor: const Color(0xFF161B26),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    underline: Container(height: 1, color: Colors.white24),
                    items: const [
                      DropdownMenuItem(value: 'pdf', child: Text('PDF Document (Standard Layout)')),
                      DropdownMenuItem(value: 'png', child: Text('PNG Image (Single Label)')),
                      DropdownMenuItem(value: 'gif', child: Text('GIF Image (Monochrome, Small File)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _printFormat = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Toggle Locations QR Code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Include Storage Location Tags',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Switch(
                        value: _includeLocations,
                        activeColor: themeColor,
                        onChanged: (val) {
                          setState(() {
                            _includeLocations = val;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const Divider(color: Colors.white12, height: 32),
                  
                  // Item Selection Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _includeLocations ? 'Select Storage Locations' : 'Select Items to Print',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
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
                        child: const Text('Toggle All', style: TextStyle(color: Colors.indigoAccent, fontSize: 13)),
                      ),
                    ],
                  ),

                  // List of checkable items
                  Expanded(
                    child: _includeLocations
                        ? _buildLocationsChecklist(locations, themeColor)
                        : _buildItemsChecklist(items, themeColor),
                  ),

                  const SizedBox(height: 16),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _printLabels(items, locations),
                      icon: const Icon(Icons.print),
                      label: Text(
                        'Print Selected (${_includeLocations ? _selectedLocationIds.length : _selectedItemIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right Side: Label Preview grid
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Label Sheet Preview',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                              child: Text(
                                'Select items or locations from the panel to preview.',
                                style: TextStyle(color: Colors.white24),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.indigoAccent),
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
    if (items.isEmpty) {
      return const Center(child: Text('No items to print.', style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItemIds.contains(item.id);
        
        // Strict QR code payload string formatting
        final qrPayload = 'ID:${item.id} | ${item.name}';
        final isTooLong = qrPayload.length > 80;

        return CheckboxListTile(
          value: isSelected,
          activeColor: themeColor,
          title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(
            'String size: ${qrPayload.length} chars ${isTooLong ? "(MAX 80 exceeded)" : ""}',
            style: TextStyle(color: isTooLong ? Colors.redAccent : Colors.white38, fontSize: 11),
          ),
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
    if (locations.isEmpty) {
      return const Center(child: Text('No storage locations to print.', style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final isSelected = _selectedLocationIds.contains(loc.id);
        final qrPayload = 'LOC:${loc.id} | ${loc.name}';
        final isTooLong = qrPayload.length > 80;

        return CheckboxListTile(
          value: isSelected,
          activeColor: themeColor,
          title: Text(loc.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(
            'String size: ${qrPayload.length} chars ${isTooLong ? "(MAX 80 exceeded)" : ""}',
            style: TextStyle(color: isTooLong ? Colors.redAccent : Colors.white38, fontSize: 11),
          ),
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
    final previewWidgets = <Widget>[];

    if (_includeLocations) {
      for (var id in _selectedLocationIds) {
        final loc = locations.firstWhere((l) => l.id == id);
        previewWidgets.add(_buildSingleLabelPreview('LOC:${loc.id}', loc.name));
      }
    } else {
      for (var id in _selectedItemIds) {
        final item = items.firstWhere((i) => i.id == id);
        previewWidgets.add(_buildSingleLabelPreview('ID:${item.id}', item.name));
      }
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: previewWidgets.length,
      itemBuilder: (context, index) => previewWidgets[index],
    );
  }

  Widget _buildSingleLabelPreview(String header, String title) {
    final payload = '$header | $title';
    // String length validation (Strict 80 char maximum)
    final displayPayload = payload.length > 80 ? payload.substring(0, 77) + '...' : payload;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: QrImageView(
              data: displayPayload,
              version: QrVersions.auto,
              size: 80,
              gapless: true,
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            header,
            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 8, overflow: TextOverflow.ellipsis),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _printLabels(List<Item> items, List<Location> locations) async {
    final printList = <Map<String, String>>[];

    if (_includeLocations) {
      if (_selectedLocationIds.isEmpty) return;
      for (var id in _selectedLocationIds) {
        final loc = locations.firstWhere((l) => l.id == id);
        printList.add({
          'header': 'LOC:${loc.id}',
          'title': loc.name,
        });
      }
    } else {
      if (_selectedItemIds.isEmpty) return;
      for (var id in _selectedItemIds) {
        final item = items.firstWhere((i) => i.id == id);
        printList.add({
          'header': 'ID:${item.id}',
          'title': item.name,
        });
      }
    }

    final activeMember = ref.read(activeMemberProvider);
    final themeColor = _parseHexColor(activeMember?.color ?? '#3F51B5');

    if (_printFormat == 'pdf') {
      final pdf = pw.Document();
      
      // Convert cm to points (1 inch = 2.54 cm = 72 points, so 1 cm = 28.35 points)
      final double labelDimPoints = _labelSizeCm * 28.346;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            final labels = printList.map((tag) {
              final payload = '${tag['header']} | ${tag['title']}';
              final displayPayload = payload.length > 80 ? payload.substring(0, 77) + '...' : payload;
              
              return pw.Container(
                width: labelDimPoints,
                height: labelDimPoints,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: displayPayload,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      tag['header']!,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      tag['title']!,
                      style: const pw.TextStyle(fontSize: 6),
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            }).toList();

            return [
              pw.Wrap(
                spacing: 12,
                runSpacing: 12,
                children: labels,
              )
            ];
          },
        ),
      );

      // Layout the PDF in system print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'home_inventory_labels.pdf',
      );

      if (mounted) {
        _showPrintSuccessDialog(themeColor);
      }
    } else {
      // PNG or GIF export
      setState(() => _isLoading = true);
      try {
        for (var tag in printList) {
          final payload = '${tag['header']} | ${tag['title']}';
          final displayPayload = payload.length > 80 ? payload.substring(0, 77) + '...' : payload;

          final bytes = await _generateLabelImageBytes(
            header: tag['header']!,
            title: tag['title']!,
            displayPayload: displayPayload,
            sizeCm: _labelSizeCm,
            format: _printFormat,
          );

          final fileExt = _printFormat;
          
          await Printing.sharePdf(
            bytes: bytes,
            filename: 'label_${tag['header']!.replaceAll(':', '_')}.$fileExt',
          );
        }
        if (mounted) {
          _showPrintSuccessDialog(themeColor);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to export label image: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<Uint8List> _generateLabelImageBytes({
    required String header,
    required String title,
    required String displayPayload,
    required double sizeCm,
    required String format,
  }) async {
    // 1 cm = 96 pixels (standard screen CSS DPI)
    const double pixelRatio = 96.0;
    final int width = (sizeCm * pixelRatio).round();
    final int height = (sizeCm * pixelRatio).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 1. Draw solid white background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    // 2. Draw thin black border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), borderPaint);

    // 3. Draw QR Code using QrPainter
    final double qrSize = height * 0.70;
    final double qrLeft = (width - qrSize) / 2;
    final double qrTop = height * 0.05;

    final qrPainter = QrPainter(
      data: displayPayload,
      version: QrVersions.auto,
      gapless: true,
    );

    canvas.save();
    canvas.translate(qrLeft, qrTop);
    qrPainter.paint(canvas, Size(qrSize, qrSize));
    canvas.restore();

    // 4. Draw Header text (e.g. ID:12)
    final headerFontSize = height * 0.07;
    final headerPainter = TextPainter(
      text: TextSpan(
        text: header,
        style: TextStyle(
          color: Colors.black,
          fontSize: headerFontSize,
          fontWeight: ui.FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    headerPainter.layout(maxWidth: width.toDouble());
    final headerX = (width - headerPainter.width) / 2;
    final headerY = qrTop + qrSize + (height * 0.02);
    headerPainter.paint(canvas, Offset(headerX, headerY));

    // 5. Draw Title text (e.g. Screwdriver)
    final titleFontSize = height * 0.055;
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Colors.black87,
          fontSize: titleFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    );
    titlePainter.layout(maxWidth: width * 0.9);
    final titleX = (width - titlePainter.width) / 2;
    final titleY = headerY + headerPainter.height + (height * 0.01);
    titlePainter.paint(canvas, Offset(titleX, titleY));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    if (format.toLowerCase() == 'png') {
      return pngBytes;
    }

    // Convert PNG to other formats using package:image
    final decodedImage = img.decodePng(pngBytes);
    if (decodedImage == null) return pngBytes;

    if (format.toLowerCase() == 'gif') {
      return Uint8List.fromList(img.encodeGif(decodedImage));
    } else if (format.toLowerCase() == 'jpg' || format.toLowerCase() == 'jpeg') {
      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: 90));
    }

    return pngBytes;
  }

  void _showPrintSuccessDialog(Color themeColor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            const Text('Printed/Exported!', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printed successfully! Scan destination QR code to check in item.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScannerPage(),
                ),
              );
            },
            child: const Text('Scan QR to Check In'),
          ),
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
