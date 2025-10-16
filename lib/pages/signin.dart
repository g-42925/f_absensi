import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env/env.dart';
import '../providers/global_state.dart';

class SignInPage extends ConsumerStatefulWidget {
  final CameraDescription camera;
  final Future<Map<String, double>> coord;

  const SignInPage({super.key, required this.camera, required this.coord});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final GlobalKey _globalKey = GlobalKey();
  SupabaseClient supabase = Supabase.instance.client;
  bool preview = false;

  final controller = TextEditingController();

  String selectedValue = "";

  Map<String, String> loc = {
    'subDistrict': '',
    'province': '',
    'country': '',
    'address': '',
  };

  String path = "";

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  double toRad(double degree) {
    return degree * pi / 180;
  }

  num haversineDistance(lat1, lat2, lon1, lon2) {
    num dLat = toRad(lat2 - lat1);
    num dLon = toRad(lon2 - lon1);
    num cosinus1 = cos(toRad(lat1));
    num cosinus2 = cos(toRad(lat2));
    num cosValue = cosinus1 * cosinus2;
    num sinus1 = pow(sin(dLat / 2), 2);
    num sinus2 = pow(sin(dLon / 2), 2);
    num v = sinus1 + (cosValue * sinus2);

    double result = 6371 * (1000 * (2 * asin(sqrt(v))));

    return double.parse(result.toStringAsFixed(2));
  }

  String getYear(DateTime information) {
    return DateFormat('dd/MM/yy').format(information);
  }

  Future<ByteBuffer> captureScreen() async {
    await Future.delayed(Duration(milliseconds: 1000));
    final boundary =
        _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer as ByteBuffer;
  }

  void captureAndUpload(String? pegawaiId) async {
    final xLocation = await widget.coord;

    await _initializeControllerFuture;
    final currentTime = DateTime.now();
    final coord = selectedValue.split('/');

    final uri = Uri.parse(Env.gMapUrl).replace(
      queryParameters: {
        'latlng': '${coord[0]},${coord[1]}',
        'key': Env.gMapKey,
      },
    );

    try {
      final lt = xLocation['lat'] as double;
      final ln = xLocation['lon'] as double;
      final sLoc = selectedValue.split('/');
      final img = await _controller.takePicture();
      final requestResponse = await http.get(uri);
      final response = jsonDecode(requestResponse.body);
      final target = response['results'][0];
      final addressComponents = target['address_components'];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final url = Uri.parse("${Env.api}/api/mobile/signin");
      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type": "application/json"};

      loc['address'] = target['formatted_address'];
      loc['subDistrict'] = addressComponents[3]['short_name'];
      loc['province'] = addressComponents[5]['short_name'];
      loc['country'] = addressComponents[6]['long_name'];

      setState(() {
        path = img.path;
        preview = true;
      });

      final result = await captureScreen();

      print("test before upload");

      await supabase.storage
          .from('storage')
          .uploadBinary(fileName, result.asUint8List());

      print("test after upload");

      final publicUrl = supabase.storage.from('storage').getPublicUrl(fileName);

      final params = {
        "is_status": "hhk",
        "jam_masuk": formattedTime,
        "foto_absen_masuk": publicUrl,
        "point_latitude": xLocation['lat'],
        "point_longitude": xLocation['lon'],
        "latitude_masuk": sLoc[0],
        "longitude_masuk": sLoc[1],
        "pegawai_id": pegawaiId,
      };

      final xRequest = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      print(xRequest.body);

      final xResponse = jsonDecode(xRequest.body);

      if (!xResponse['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(xResponse['message']),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ref.read(globalStateProvider.notifier).signIn();
        ref.read(globalStateProvider.notifier).setPosition(lt, ln);

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (Route<dynamic> route) => false,
        );
      }
    } catch (err) {
      print("error");
      print(err);
    }
  }

  Widget setPreview() {
    return RepaintBoundary(
      key: _globalKey,
      child: Stack(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Image.file(File(path)),
          ),
          Positioned(
            width: MediaQuery.of(context).size.width,
            bottom: 60,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Image.network(
                    Uri.parse(Env.gStaticMap)
                        .replace(
                          queryParameters: {
                            'center':
                                "${selectedValue.split('/')[0]},${selectedValue.split('/')[1]}",
                            'size': '100x200',
                            'zoom': '18',
                            'key': Env.gMapKey,
                          },
                        )
                        .toString(),
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.black,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${loc['subDistrict']}, ${loc['province']}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "${loc['address']}",
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              selectedValue.split('/')[0],
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              selectedValue.split('/')[1],
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              getYear(DateTime.now()),
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
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
    );
  }

  Widget setCamera(List<Map<String, dynamic>>? list, Other other) {
    final entries = (list ?? []).map((l) {
      return DropdownMenuEntry(
        value: '${l['lat']}/${l['lon']}',
        label: '${l['locationName']}',
      );
    }).toList();

    entries.add(DropdownMenuEntry(value: '0/0', label: 'pilih lokasi'));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          DropdownMenu<String>(
            width: MediaQuery.of(context).size.width - 32,
            hintText: "Pilih lokasi kehadiran",
            controller: controller,
            dropdownMenuEntries: entries.toList(),
            onSelected: (value) async {
              final c = await widget.coord;
              final lt = double.parse(value?.split('/')[0] as String);
              final lng = double.parse(value?.split('/')[1] as String);
              if (haversineDistance(c['lat'], lt, c['lon'], lng) > 200) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // supaya bisa atur tinggi
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) {
                    return FractionallySizedBox(
                      heightFactor: 0.5, // setengah layar
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Lokasi tidak tersedia untuk dipilih',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kamu berada terlalu jauh dari lokasi yang dipilih',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                controller.clear();
                selectedValue = "";
              } else {
                final lat = value?.split('/')[0] as String;
                final idx = list?.indexWhere((i) => i['lat'] == lat);
                final target = list?[idx as int];
                controller.text = target?['locationName'];
                selectedValue = "${target?['lat']}/${target?['lon']}";
              }
            },
          ),
          SizedBox(height: 16),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(_controller),
              ),
              Positioned(
                bottom: 20,
                width: MediaQuery.of(context).size.width - 32,
                child: Padding(
                  padding: EdgeInsetsGeometry.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      captureAndUpload(other.pegawaiId);
                    },
                    icon: const Icon(
                      Icons.login,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Presensi Masuk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // hijau tosca
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0, // tanpa shadow
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    final location = globalState.location;

    return Scaffold(
      appBar: !preview
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return preview ? setPreview() : setCamera(location.list, other);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
