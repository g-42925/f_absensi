import 'dart:io';

import 'package:absensi/providers/global_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  String selectedType = 'Sign In';
  final types = ['Sign In', 'Sign Out'];
  bool isProcessing = false;

  void addEntry() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.read(globalStateProvider.notifier).addOfflineEntry(selectedType, date);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry berhasil ditambahkan.')),
    );
  }

  Future<void> takePhoto(Map<String, dynamic> entry) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        isProcessing = true;
      });

      try {
        // Request Permission for Gallery
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }

        final bytes = await photo.readAsBytes();
        
        // Process image in isolate to avoid freezing UI
        final watermarkedBytes = await compute(_processImage, {
          'bytes': bytes,
          'type': entry['type'],
          'date': entry['date'],
          'time': DateFormat('HH:mm:ss').format(DateTime.now()),
        });

        if (watermarkedBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/watermarked_${entry['id']}.jpg');
          await tempFile.writeAsBytes(watermarkedBytes);

          await Gal.putImage(tempFile.path);

          ref.read(globalStateProvider.notifier).updateOfflineEntryPhoto(
                entry['id'],
                DateFormat('HH:mm:ss').format(DateTime.now()),
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto berhasil disimpan ke Galeri.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var globalState = ref.watch(globalStateProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mode Offline"),
      ),
      body: isProcessing 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Buat Entry Offline Baru',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipe Entry', border: OutlineInputBorder()),
                      items: types.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: today,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer
                      ),
                      onPressed: addEntry,
                      child: const Text('Simpan Entry'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Daftar Entry Anda',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: globalState.offlineEntries.isEmpty
                  ? const Center(child: Text("Belum ada entry."))
                  : ListView.builder(
                      itemCount: globalState.offlineEntries.length,
                      itemBuilder: (context, index) {
                        final entry = globalState.offlineEntries[index];
                        final hasPhoto = entry.containsKey('captureTime') && entry['captureTime'] != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${entry['type']} - ${entry['date']}'),
                            subtitle: hasPhoto 
                                ? Text('Disimpan pada: ${entry['captureTime']}') 
                                : const Text('Belum ada foto', style: TextStyle(color: Colors.red)),
                            trailing: hasPhoto
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : ElevatedButton.icon(
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Foto'),
                                    onPressed: () => takePhoto(entry),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top level function for isolate
Future<Uint8List?> _processImage(Map<String, dynamic> data) async {
  final Uint8List bytes = data['bytes'];
  final String typeText = '[${data['type']}]';
  final String dateText = '${data['date']}';
  final String timeText = '${data['time']}';

  final img.Image? image = img.decodeImage(bytes);
  if (image == null) return null;

  // ---- constants ----
  final font = img.arial48;
  const int scale = 4;             // 2x font scale
  const int charH = 48;            // arial48 height in px
  const int approxCharW = 28;      // approximate width per char
  const int innerPad = 6;          // padding inside temp image
  const int lineGap = scale * 8;   // gap between scaled lines
  const int marginRight = 24;      // distance from right edge
  const int marginTop = 24;        // distance from top edge

  final lines = [typeText, dateText, timeText];
  final int tempH   = charH + innerPad * 2;
  final int scaledH = tempH * scale;

  // Pre-compute scaled widths for all lines
  final List<int> scaledWs = lines
      .map((l) => (l.length * approxCharW + innerPad * 2) * scale)
      .toList();

  // dateText is index 1 — used as the horizontal reference
  final int dateScaledW = scaledWs[1];
  final int dstXDate    = image.width - dateScaledW - marginRight;

  // X positions per line:
  //   typeText (0) → right-aligned
  //   dateText (1) → right-aligned (reference)
  //   timeText (2) → centered under dateText
  final List<int> dstXs = [
    image.width - scaledWs[0] - marginRight,        // typeText
    dstXDate,                                        // dateText
    dstXDate + (dateScaledW - scaledWs[2]) ~/ 2,    // timeText centered
  ];

  int currentY = marginTop;

  for (int i = 0; i < lines.length; i++) {
    final line     = lines[i];
    final scaledW  = scaledWs[i];
    final int tempW = scaledW ~/ scale;

    // 1. Render text on a black temp image
    final tempImg = img.Image(width: tempW, height: tempH);
    img.fill(tempImg, color: img.ColorRgb8(0, 0, 0));
    img.drawString(
      tempImg,
      line,
      font: font,
      x: innerPad,
      y: innerPad,
      color: img.ColorRgb8(255, 255, 0),
    );

    // 2. Scale up using nearest-neighbor (sharp)
    final scaled = img.copyResize(
      tempImg,
      width: scaledW,
      height: scaledH,
      interpolation: img.Interpolation.nearest,
    );

    // 3. Stamp non-black pixels
    final int dstX = dstXs[i];
    final int dstY = currentY;

    for (int sy = 0; sy < scaledH; sy++) {
      for (int sx = 0; sx < scaledW; sx++) {
        final pixel = scaled.getPixel(sx, sy);
        if (pixel.r > 20 || pixel.g > 20 || pixel.b > 20) {
          final ix = dstX + sx;
          final iy = dstY + sy;
          if (ix >= 0 && ix < image.width && iy >= 0 && iy < image.height) {
            image.setPixel(ix, iy, pixel);
          }
        }
      }
    }

    currentY += scaledH + lineGap;
  }

  return img.encodeJpg(image, quality: 92);
}
