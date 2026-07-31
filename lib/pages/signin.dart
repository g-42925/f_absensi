import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart'; // <-- MediaType
import '../env/env.dart';
import '../providers/global_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../providers/location_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SignInPage extends ConsumerStatefulWidget {
  final CameraDescription camera;

  const SignInPage({super.key, required this.camera});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  CameraController? _controller;
  Future<void>? _cameraFuture;
  final GlobalKey _globalKey = GlobalKey();
  SupabaseClient supabase = Supabase.instance.client;
  bool preview = false;

  bool face = false;

  final distance = 0;

  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  double latitude = 0;
  double longitude = 0;

  bool clicked = false;

  bool isSuspicious = false;

  final controller = TextEditingController();

  String locationName = 'Anda berada di luar area presensi';

  Map<dynamic, dynamic>? _selectedLocation;

  Map<String, String> loc = {'address': ''};

  String path = "";

  bool isCameraDenied = false;
  bool _cameraDisclosureAccepted = false;

  Future<bool> showDisclosureDialog({required String title, required String message, required IconData icon, required VoidCallback onConfirm,required VoidCallback onDenied}) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDenied();
            },
            child: const Text("TUTUP", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("SETUJU \u0026 LANJUT"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<dynamic> requestLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      bool userAgreed = false;
      await showDisclosureDialog(
        title: "Izin Lokasi",
        message: "Leryn Absensi mengumpulkan data lokasi untuk memverifikasi bahwa Anda berada di area kantor saat melakukan Check-in dan Check-out. Data ini hanya diambil saat Anda menekan tombol absen.",
        icon: Icons.location_on,
        onConfirm: () {
          userAgreed = true;
        },
        onDenied: () {},
      );

      if (userAgreed) {
        permission = await Geolocator.requestPermission();
      } 
      else {
        return Future.error("Izin lokasi ditolak oleh pengguna");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error("Izin lokasi ditolak secara permanen. Silakan aktifkan di pengaturan.");
    }

    return Geolocator.getCurrentPosition();
  }

	@override
  void dispose() {
    _controller?.dispose();
    faceDetector.close();
    super.dispose(); 
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkPermissions();
    });
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
    await Future.delayed(Duration(milliseconds: 3000));
    final boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer as ByteBuffer;
  }

  bool isOnOffice(double latitude, double longitude) {
    final globalState = ref.read(globalStateProvider);
    final locations = globalState.location.list;

    return locations.any((loc) {
      final lat2 = double.parse(loc['lat']);
      final lon2 = double.parse(loc['lon']);
      final distance = haversineDistance(latitude, lat2, longitude, lon2);
      return distance <= int.parse(loc['radius']);
    });
  }


  Future<void> checkPermissions() async {
    // Check Location
    LocationPermission locPermission = await Geolocator.checkPermission();
    if (locPermission == LocationPermission.denied) {
      await showDisclosureDialog(
        title: "Izin Lokasi",
        message: "Aplikasi ini membutuhkan akses lokasi untuk memverifikasi kehadiran Anda di area kantor.",
        icon: Icons.location_on,
        onConfirm: () async {
          await Geolocator.requestPermission();
          ref.refresh(locationProvider);
        },
        onDenied: () {
        },
      );
    }

    // Check Camera
    final prefs = await SharedPreferences.getInstance();
    bool cameraDisclosed = prefs.getBool('camera_disclosed') ?? false;
    if (!cameraDisclosed) {
      await showDisclosureDialog(
        title: "Izin Kamera",
        message: "Aplikasi ini membutuhkan akses kamera untuk fitur verifikasi wajah saat melakukan absensi.",
        icon: Icons.camera_alt,
        onConfirm: () async {
          await prefs.setBool('camera_disclosed', true);
          setState(() {
            _cameraDisclosureAccepted = true;
          });
        },
        onDenied: () {
          setState(() {
            isCameraDenied = true;
          });
        }
      );
    } else {
      setState(() {
        _cameraDisclosureAccepted = true;
      });
    }
  }

  String setLocation(double latitude, double longitude) {
    final globalState = ref.read(globalStateProvider);
    final locations = globalState.location.list;

    for (var locs in locations) {
      final lat1 = latitude;
      final lat2 = double.parse(locs['lat']);
      final lon1 = longitude;
      final lon2 = double.parse(locs['lon']);

      if(haversineDistance(lat1, lat2, lon1, lon2) < 200) {
        return locs['locationName'];
      }
    }

    return locationName;
  }

  void captureAndUpload(String? pegawaiId,bool ffocia) async {
    bool isDialogShowing = false;
    final globalState = ref.read(globalStateProvider);
    final config = globalState.config;


    final supabase = Supabase.instance.client;
    final currentTime = DateTime.now();

    try {
      final state = ref.read(globalStateProvider);
      final other = state.other;
      final company = state.company;
      final img = await _controller!.takePicture();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}';
      final url = Uri.parse("${Env.api}/api/mobile/signin");
      final uploadUrl = Uri.parse("${Env.api}/filebase/attendance/$fileName/${company.id}");
      final exceptionCheckUrl = Uri.parse("${Env.api}/api/mobile/exceptiontoday/${other.pegawaiId}");

      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type": "application/json"};
      final now = DateTime.now(); // ambil tanggal sekarang
      final formatted = DateFormat('yyyy-MM-dd').format(now);
      final formattedSecond = DateFormat('HH:mm:ss').format(now);
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final inputImage = InputImage.fromFilePath(img.path);

      final isOther = _selectedLocation != null && _selectedLocation!['id'] == 'other';
  
      loc['address'] = isOther ? '' : (_selectedLocation != null ? _selectedLocation!['address'] : 'Tidak diketahui');
      locationName = isOther ? '' : (_selectedLocation != null ? _selectedLocation!['locationName'] : 'Tidak diketahui');

      setState(() {
        path = img.path;
        preview = true;
      });

      final result = await captureScreen();

      final bytes = result.asUint8List();

      final faces = await faceDetector.processImage(inputImage);

      if(faces.length > 0){
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1080,
          minHeight: 1920,
          quality: 50,
          format: CompressFormat.jpeg, // penting, karena png lebih besar
        );

        isDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // ubah sesuai selera
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('submit is loading, please wait...'),
                ],
              ),
            ),
          ),
        );

        final request = http.MultipartRequest('POST', uploadUrl);

        request.files.add(
            http.MultipartFile.fromBytes(
            'file', // field name
            compressed, // file data
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ),
        );

        final streamedResponse = await request.send();

        if (streamedResponse.statusCode != 200) {}

        final responseBody = await streamedResponse.stream.bytesToString();

        final uploadResponse = responseBody;

        final params = {
          "is_status": "hhk",
          "jam_masuk": formattedTime,
          "foto_absen_masuk": uploadResponse,
          "point_latitude": latitude,
          "point_longitude": longitude,
          "latitude_masuk": latitude,
          "longitude_masuk": longitude,
          "pegawai_id": pegawaiId,
          "is_mock":isSuspicious
        };

        bool isOutOfRadius = true;

        if (_selectedLocation != null && !isOther) {
          final lat2 = double.parse(_selectedLocation!['lat'].toString());
          final lon2 = double.parse(_selectedLocation!['lon'].toString());
          final radius = int.parse(_selectedLocation!['radius'].toString());
          final distance = haversineDistance(latitude, lat2, longitude, lon2);
          isOutOfRadius = distance > radius;
        }


        if(!config.ffocia){
          if(!isOutOfRadius){
            if(_selectedLocation!['mainLocation']){           
              final xRequest = await http.post(
                url,
                headers: headers,
                body: jsonEncode(params),
              )
              .timeout(
                const Duration(seconds: 30)
              );

              final xResponse = jsonDecode(xRequest.body);

              if (!xResponse['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("coba beberapa saat lagi"),
                    duration: Duration(seconds: 4),
                  ),
                );
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> route) => false,
                );

                return;
              }

              Navigator.of(context).pop();

              ref.read(globalStateProvider.notifier).signIn(formattedTime);
              ref.read(globalStateProvider.notifier).setPosition(latitude, longitude);

              (() async {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'you have been checked in',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.check_circle, color: Colors.green, size: 28),
                        ],
                      ),
                    ),
                  ),
                );

                await Future.delayed(Duration(seconds: 1));

                setState(() {
                  path = img.path;
                  preview = false;
                });

                Navigator.of(context).pop();

                await Future.delayed(Duration(seconds: 1));

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> route) => false,
                );
              })();             
            }
            else{
              final response = await http.get(
                Uri.parse("${Env.api}/api/mobile/exceptiontoday/${other.pegawaiId}/in"),
                headers: headers,
              )
              .timeout(
                const Duration(seconds: 30)
              );

              if(jsonDecode(response.body)['exist'] == "yes"){
                final xRequest = await http.post(
                  url,
                  headers: headers,
                  body: jsonEncode(params),
                )
                .timeout(
                  const Duration(seconds: 30)
                );

                final xResponse = jsonDecode(xRequest.body);

                if (!xResponse['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("coba beberapa saat lagi"),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (Route<dynamic> route) => false,
                  );
                  return;
                }

                Navigator.of(context).pop();

                ref.read(globalStateProvider.notifier).signIn(formattedTime);
                ref.read(globalStateProvider.notifier).setPosition(latitude, longitude);

                (() async {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'you have been checked in',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.check_circle, color: Colors.green, size: 28),
                          ],
                        ),
                      ),
                    ),
                  );

                  await Future.delayed(Duration(seconds: 1));

                  setState(() {
                    path = img.path;
                    preview = false;
                  });

                  Navigator.of(context).pop();

                  await Future.delayed(Duration(seconds: 1));

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (Route<dynamic> route) => false,
                  );
                })();
              }

              else{
                if (isDialogShowing) {
                  Navigator.pop(context);
                  isDialogShowing = false;
                }
                setState(() {
                  preview = false;
                  clicked = false;
                });
                // show make an exception warning first
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Warning"),
                    content: Text("make an exception first"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("OK"),
                      ),
                    ],
                  ),
                );
              }
            }
          }
          else{
            final response = await http.get(
              Uri.parse("${Env.api}/api/mobile/exceptiontoday/${other.pegawaiId}/in"),
              headers: headers,
            )
            .timeout(
              const Duration(seconds: 30)
            );

            if(jsonDecode(response.body)['exist'] == "yes"){
              final xRequest = await http.post(
                url,
                headers: headers,
                body: jsonEncode(params),
              )
              .timeout(
                const Duration(seconds: 30)
              );

              final xResponse = jsonDecode(xRequest.body);

              if (!xResponse['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("coba beberapa saat lagi"),
                    duration: Duration(seconds: 4),
                  ),
                );
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> route) => false,
                );
                return;
              }

              Navigator.of(context).pop();

              ref.read(globalStateProvider.notifier).signIn(formattedTime);
              ref.read(globalStateProvider.notifier).setPosition(latitude, longitude);

              (() async {
                showDialog(
                  context: context,
                barrierDismissible: true,
                builder: (_) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'you have been checked in',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.check_circle, color: Colors.green, size: 28),
                        ],
                      ),
                    ),
                  ),
                );

                await Future.delayed(Duration(seconds: 1));

                setState(() {
                  path = img.path;
                  preview = false;
                });

                Navigator.of(context).pop();

                await Future.delayed(Duration(seconds: 1));

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> route) => false,
                );
              })();
            }

            else{
              if (isDialogShowing) {
                Navigator.pop(context);
                isDialogShowing = false;
              }
              setState(() {
                preview = false;
                clicked = false;
              });
              // show make an exception warning first
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Warning"),
                  content: Text("make an exception first"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("OK"),
                    ),
                  ],
                ),
              );
            }
          }
        }

        if(config.ffocia){
          final xRequest = await http.post(
            url,
            headers: headers,
            body: jsonEncode(params),
          )
          .timeout(
            const Duration(seconds: 30)
          );

          final xResponse = jsonDecode(xRequest.body);

          if (!xResponse['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("coba beberapa saat lagi"),
                duration: Duration(seconds: 4),
              ),
            );
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) => false,
            );
            return;
          }

          Navigator.of(context).pop();

          ref.read(globalStateProvider.notifier).signIn(formattedTime);
          ref.read(globalStateProvider.notifier).setPosition(latitude, longitude);

          (() async {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'you have been checked in',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                    ],
                  ),
                ),
              ),
            );

            await Future.delayed(Duration(seconds: 1));

            setState(() {
              path = img.path;
              preview = false;
            });

            Navigator.of(context).pop();

            await Future.delayed(Duration(seconds: 1));

            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) => false,
            );
          })();            
        }

      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Wajah tidak terdeteksi",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } 
    on TimeoutException catch (err) {
      print(err);
      if (isDialogShowing) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Request timeout, coba beberapa saat lagi",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
      );
      setState(() {
        preview = false;
        clicked = false;
      });
    }
    catch (err) {
      if (isDialogShowing) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    err.toString().replaceAll('Exception: ', ''),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
      );
      setState(() {
        preview = false;
        clicked = false;
      });
    }
  }

  Widget setPreview() {
    final isOther = _selectedLocation != null && _selectedLocation!['id'] == 'other';

    final _lat2 = (_selectedLocation != null && !isOther && _selectedLocation!['lat'] != null) 
        ? double.parse(_selectedLocation!['lat'].toString()) 
        : latitude;
        
    final _lon2 = (_selectedLocation != null && !isOther && _selectedLocation!['lon'] != null) 
        ? double.parse(_selectedLocation!['lon'].toString()) 
        : longitude;
    final _d =  haversineDistance(latitude, _lat2, longitude, _lon2);

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
                  SizedBox(
                    width: 100,
                    height: 200,
                    child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.leryn.f_absensi',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                              "${loc['address']} (${_d})",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "$latitude",
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              "$longitude",
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              "${getYear(DateTime.now())} ${DateFormat('HH:mm').format(DateTime.now())}",
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

  Widget setCamera(Map<String, dynamic> args) {
    final globalState = ref.read(globalStateProvider);
    final schedule = globalState.schedule;
    final other = globalState.other;
    final workSystemName = schedule.workSystemName;
    final locations = globalState.location.list;
    final List<dynamic> dropdownItems = List.from(locations);
    dropdownItems.add(const {'id': 'other', 'locationName': 'Lainnya'});

    final currentLoc = _selectedLocation ?? (dropdownItems.isNotEmpty ? dropdownItems.first : null);
    final isOther = currentLoc != null && currentLoc['id'] == 'other';

    bool isOutOfRadius = true;
    if (currentLoc != null && !isOther) {
      final lat2 = double.parse(currentLoc['lat'].toString());
      final lon2 = double.parse(currentLoc['lon'].toString());
      final radius = int.parse(currentLoc['radius'].toString());
      final distance = haversineDistance(latitude, lat2, longitude, lon2);
      isOutOfRadius = distance > radius;
    }

    bool disableButton = !isOther && isOutOfRadius;

		return Stack(
			children: [
				Center(
					child: ClipOval(
						child: SizedBox(
							width: 300,
							height: 300,
							child: CameraPreview(_controller!),
						),
					),
				),
				Positioned(
					bottom: 110,
					left: 0,
					right: 0,
					child: Container(
						padding: EdgeInsets.all(12),
						margin: EdgeInsets.symmetric(horizontal: 20),
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(8),
							border: Border.all(color: Colors.grey.shade300),
						),
						child: Column(
							children: [
								Row(
									children: [
										Icon(Icons.calendar_today, size: 18),
										SizedBox(width: 8),
										Text("$workSystemName - ${DateFormat('EEEE, dd MMM yyyy').format(DateTime.now())}"),
									],
								),
								SizedBox(height: 8),
								Row(
									children: [
										Icon(
											Icons.location_on,
											size: 18,
											color: Colors.red,
										),
										SizedBox(width: 8),
										Expanded(
                      child: InkWell(
                        onTap: () {
                          String searchQuery = '';
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (BuildContext context, StateSetter setModalState) {
                                  final filteredItems = dropdownItems.where((loc) {
                                    if (loc['id'] == 'other') return true;
                                    final locName = loc['locationName'].toString().toLowerCase();
                                    return locName.contains(searchQuery.toLowerCase());
                                  }).toList();

                                  return SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context).viewInsets.bottom,
                                        top: 16,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Pilih Lokasi",
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: TextField(
                                              decoration: InputDecoration(
                                                hintText: 'Cari lokasi...',
                                                prefixIcon: const Icon(Icons.search),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                              ),
                                              onChanged: (value) {
                                                setModalState(() {
                                                  searchQuery = value;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(),
                                          Flexible(
                                            child: ListView(
                                              shrinkWrap: true,
                                              children: filteredItems.map<Widget>((loc) {
                                            if (loc['id'] == 'other') {
                                              return ListTile(
                                                leading: const Icon(Icons.location_off, color: Colors.grey),
                                                title: const Text("Lainnya"),
                                                onTap: () {
                                                  setState(() {
                                                    _selectedLocation = loc;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                              );
                                            }
                                            final lat2 = double.parse(loc['lat'].toString());
                                            final lon2 = double.parse(loc['lon'].toString());
                                            final radius = int.parse(loc['radius'].toString());
                                            final distance = haversineDistance(latitude, lat2, longitude, lon2).toInt();
                                            final isOutOfRadius = distance > radius;
                                            
                                            return ListTile(
                                              leading: Icon(
                                                Icons.location_on, 
                                                color: isOutOfRadius ? Colors.red : Colors.green
                                              ),
                                              title: Text(loc['locationName']),
                                              subtitle: Text("Jarak: ${distance}m / Radius: ${radius}m"),
                                              trailing: isOutOfRadius 
                                                ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                                                : const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                              onTap: () {
                                                setState(() {
                                                  _selectedLocation = loc;
                                                });
                                                Navigator.pop(context);
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                                },
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    if (currentLoc == null) {
                                      return const Text("Pilih Lokasi", style: TextStyle(fontWeight: FontWeight.bold));
                                    }
                                    if (currentLoc['id'] == 'other') {
                                      return const Text("Lainnya", style: TextStyle(fontWeight: FontWeight.bold));
                                    }
                                    final lat2 = double.parse(currentLoc['lat'].toString());
                                    final lon2 = double.parse(currentLoc['lon'].toString());
                                    final radius = int.parse(currentLoc['radius'].toString());
                                    final distance = haversineDistance(latitude, lat2, longitude, lon2).toInt();
                                    final isOutOfRadius = distance > radius;
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentLoc['locationName'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "${distance}m / ${radius}m",
                                          style: TextStyle(
                                            color: isOutOfRadius ? Colors.red : Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
									],
								),
							],
						),
					),
				),
				Positioned(
					bottom: 20,
					left: 0,
					right: 0,
					child: Container(
						margin: EdgeInsets.all(16), // margin di semua sisi
						width: double.infinity, // membuat selebar layar
						child: ElevatedButton(
							style: ElevatedButton.styleFrom(
								backgroundColor: clicked ? Colors.red : Colors.green[600], // hijau gelap
								padding: EdgeInsets.symmetric(vertical: 16), // tinggi button
							),
							onPressed: disableButton ? null : () {
								setState(() {
										clicked = true;
                    _selectedLocation = currentLoc;
								});
								captureAndUpload(
									other.pegawaiId,
									args['ffocia'],
								);
							},           
							child: Text(
								"Masuk",
								style: TextStyle(
										color: Colors.white, // warna teks putih
										fontSize: 16,
								),
							),
						),
					),
				),
			],
		);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
		final locs = ref.watch(locationProvider);

		return locs.when(
			loading: () => const Scaffold(
        body: Center(child: Text('please wait')),
      ),
			error: (err, _) {
        final errorMsg = err.toString();
        final isGpsOff = errorMsg.contains('GPS is not enabled') || errorMsg.contains('failed to get current location');
        final isPermissionDenied = errorMsg.contains('denied');

        return Scaffold(
          appBar: !preview
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.black),
              )
            : null,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGpsOff ? Icons.location_off : Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGpsOff 
                      ? 'GPS Anda sedang tidak aktif.\nSilakan nyalakan GPS untuk menggunakan fitur ini.'
                      : (isPermissionDenied 
                          ? 'Izin Lokasi ditolak.\nIzinkan akses lokasi pada pengaturan aplikasi.' 
                          : 'Gagal mendapatkan lokasi: ${errorMsg.replaceAll('Exception: ', '')}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  if (isGpsOff) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Buka Pengaturan Lokasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isPermissionDenied) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      icon: const Icon(Icons.settings_applications),
                      label: const Text('Buka Pengaturan Aplikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(locationProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isGpsOff || isPermissionDenied) ? Colors.grey[200] : Colors.teal,
                      foregroundColor: (isGpsOff || isPermissionDenied) ? Colors.black87 : Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: (isGpsOff || isPermissionDenied) ? 0 : 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
			data: (position){
				WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted && (latitude != position['position'].latitude || longitude != position['position'].longitude)){
            setState(() {
              latitude = position['position'].latitude;
              longitude = position['position'].longitude;
              isSuspicious = position['isSuspicious'];
            });
					}
        });

        if (_controller == null && _cameraDisclosureAccepted) {
          _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);
          _cameraFuture = _controller!.initialize();
        }

        if(isCameraDenied){
          return Scaffold(
            body: Center(child: Text('Camera access is denied')),
          );
        }

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
            future: _cameraFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                  return preview ? setPreview() : setCamera(args);
              }  
              else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        );
	    }
		);
  }
}
