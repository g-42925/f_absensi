import 'dart:io';
import 'dart:convert';
import '../env/env.dart';
import 'package:http/http.dart' as http;
import 'package:absensi/providers/global_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http_parser/http_parser.dart';

class OfflineListPage extends ConsumerStatefulWidget {
  const OfflineListPage({super.key});

  @override
  ConsumerState<OfflineListPage> createState() => _OfflineListPageState();
}

class _OfflineListPageState extends ConsumerState<OfflineListPage> {
  bool isProcessing = false;
  static const _channel = MethodChannel('uptime');
  final ImagePicker picker = ImagePicker();
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
    ),
  );


  Future<void> takePhoto(Map<String, dynamic> entry) async {
    final serverTimeInfo = ref.watch(globalStateProvider).serverTimeInfo;
    final serverTime = serverTimeInfo.serverTime != null ? DateTime.parse(serverTimeInfo.serverTime!) : DateTime.now();
    final fixedMonotonic = (serverTimeInfo.upTime ?? 0) / 1000;
    final currentMonotonic = await _channel.invokeMethod('getUptime') / 1000;
    final monotonic = (currentMonotonic - fixedMonotonic).toInt();
    final syncedTime = serverTime.add(Duration(seconds: monotonic));


    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        isProcessing = true;
      });
      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await faceDetector.processImage(inputImage);
      if(faces.length > 0){
        try {
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) await Gal.requestAccess();
          final bytes = await photo.readAsBytes();
          final watermarkedBytes = await compute(_processImage, {
            'bytes': bytes,
            'type': entry['type'],
            'date': entry['date'],
            'time': DateFormat('HH:mm:ss').format(syncedTime),
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
        } 
        catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        } 
        finally {
          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }
        }
      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wajah tidak terdeteksi.')),
        );  
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> sync(Map<String, dynamic> entry) async{
    final state = ref.read(globalStateProvider);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}';
    final uploadUrl = Uri.parse("${Env.api}/filebase/attendance/$fileName/${state.company.id}");
    final syncOutUrl = Uri.parse("${Env.api}/api/mobile/syncout");

    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    final request = http.MultipartRequest('POST', uploadUrl);


    if(image != null){
      final inputImage = InputImage.fromFilePath(image.path);
      
      try{ 
        final bytes = await image.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1080,
          minHeight: 1920,
          quality: 50,
          format: CompressFormat.jpeg, // penting, karena png lebih besar
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', // field name
            compressed, // file data
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ),
        );

        final streamedResponse = await request.send();

        if (streamedResponse.statusCode != 200) {
          // do something
        }

        final responseBody = await streamedResponse.stream.bytesToString();
        final uploadResponse = responseBody;

        if(entry['type'] == "Sign In"){
          final response = await http.post(
            Uri.parse("${Env.api}/api/mobile/syncin"),
            headers: {'Content-Type': 'application/json'},              
            body: jsonEncode({
              'empId':state.other.pegawaiId,
              'captureTime': entry['captureTime'],
              'photo': uploadResponse,
            })
          );
          print(response.body);
        }
        else{
          final response = await http.post(
            Uri.parse("${Env.api}/api/mobile/syncout"),
            headers: {'Content-Type': 'application/json'},              
            body: jsonEncode({
              'empId':state.other.pegawaiId,
              'captureTime': entry['captureTime'],
              'photo': uploadResponse,
            })
          );

          if(jsonDecode(response.body)['success'] == true){
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data berhasil disinkronkan.')),
            );
          }
          else{
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal sinkron data.')),
            );  
          }
        }
      }
      catch(err){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal sinkron data.')),
        );  
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var globalState = ref.watch(globalStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Entry Offline")),
      body: isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: globalState.offlineEntries.isEmpty
                        ? const Center(child: Text("Belum ada entry."))
                        : ListView.builder(
                            itemCount: globalState.offlineEntries.length,
                            itemBuilder: (context, index) {
                              final entry = globalState.offlineEntries[index];
                              final hasPhoto =
                                  entry.containsKey('captureTime') &&
                                  entry['captureTime'] != null;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    '${entry['type']} - ${entry['date']}',
                                  ),
                                  subtitle: hasPhoto
                                      ? Text(
                                          'Disimpan pada: ${entry['captureTime']}',
                                        )
                                      : const Text(
                                          'Belum ada foto',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                  trailing: hasPhoto
                                      ? 
                                      IconButton(
                                        icon: HugeIcon(
                                          icon: HugeIcons.strokeRoundedCalendarSync,
                                          size: 24.0,
                                          color: Color(0xFF2196F3),
                                          strokeWidth: 1.5,
                                        ),
                                        onPressed: () {
                                          sync(entry);
                                        },
                                      )
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/offline_entry');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    faceDetector.close();
    super.dispose(); 
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
  const int scale = 4; // 2x font scale
  const int charH = 48; // arial48 height in px
  const int approxCharW = 28; // approximate width per char
  const int innerPad = 6; // padding inside temp image
  const int lineGap = scale * 8; // gap between scaled lines
  const int marginRight = 24; // distance from right edge
  const int marginTop = 24; // distance from top edge

  final lines = [typeText, dateText, timeText];
  final int tempH = charH + innerPad * 2;
  final int scaledH = tempH * scale;

  // Pre-compute scaled widths for all lines
  final List<int> scaledWs = lines
      .map((l) => (l.length * approxCharW + innerPad * 2) * scale)
      .toList();

  // dateText is index 1 — used as the horizontal reference
  final int dateScaledW = scaledWs[1];
  final int dstXDate = image.width - dateScaledW - marginRight;

  // X positions per line:
  //   typeText (0) → right-aligned
  //   dateText (1) → right-aligned (reference)
  //   timeText (2) → centered under dateText
  final List<int> dstXs = [
    image.width - scaledWs[0] - marginRight, // typeText
    dstXDate, // dateText
    dstXDate + (dateScaledW - scaledWs[2]) ~/ 2, // timeText centered
  ];

  int currentY = marginTop;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final scaledW = scaledWs[i];
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
