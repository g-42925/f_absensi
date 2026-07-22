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

  String selectedValue = "";

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
    await Future.delayed(Duration(milliseconds: 1000));
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

      print("=====================");
      print(distance);
      print(loc['radius']);
      print(int.parse(loc['radius']));
      print("=====================");
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
    final globalState = ref.read(globalStateProvider);
    final config = globalState.config;


    final supabase = Supabase.instance.client;
    final currentTime = DateTime.now();

    final uri = Uri.parse(Env.locationIqUrl).replace(
      queryParameters: {
        'lat': "$latitude",
        'lon': "$longitude", 
        'key': Env.locationIqKey,
        'format': 'json',
      },
    );


    try {
      final state = ref.read(globalStateProvider);
      final other = state.other;
      final company = state.company;
      final img = await _controller!.takePicture();
      final requestResponse = await http.get(uri);
      final response = jsonDecode(requestResponse.body);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}';
      final url = Uri.parse("${Env.api}/api/mobile/signin");
      final uploadUrl = Uri.parse("${Env.api}/filebase/attendance/$fileName/${company.id}");

      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type": "application/json"};
      final now = DateTime.now(); // ambil tanggal sekarang
      final formatted = DateFormat('yyyy-MM-dd').format(now);
      final formattedSecond = DateFormat('HH:mm:ss').format(now);
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final inputImage = InputImage.fromFilePath(img.path);

      loc['address'] = response['display_name'];

      setState(() {
        path = img.path;
        preview = true;
      });

      final result = await captureScreen();

      final bytes = result.asUint8List();

      final faces = await faceDetector.processImage(inputImage);

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1920,
        quality: 50,
        format: CompressFormat.jpeg, // penting, karena png lebih besar
      );

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

      if ((ffocia || config.ffocia) || isOnOffice(latitude, longitude)) {
        if(faces.length > 0){
          final xRequest = await http.post(
            url,
            headers: headers,
            body: jsonEncode(params),
          )
          .timeout(
            const Duration(seconds: 30)
          );

          final xResponse = jsonDecode(xRequest.body);

          print(xResponse);

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
          } 

          else{
            final response = await supabase
              .from('companies')
              .select()
              .eq('company_id', company.id)
              .maybeSingle();

            if (xResponse['late'] as bool) {
              try {
                await supabase.from('messages').insert({
                  'receiver_id': response?['account_id'],
                  'date': formatted,
                  'created_at': timestamp,
                  'image': uploadResponse,
                  'employee_id': pegawaiId,
                  'employee_name': other.namaPegawai,
                  'late': xResponse['late'] as bool,
                  'late_diff': xResponse['late'] as bool
                    ? xResponse['late_diff']
                    : 0,
                  'action_type': 'melakukan absen masuk',
                  'action_time': formattedSecond,
                  'on_office': isOnOffice(latitude, longitude),
                });
              } 
              catch (e) {
                print(e);
              }
            }

            Navigator.of(context).pop();

            ref.read(globalStateProvider.notifier).signIn(formattedTime);
            ref
              .read(globalStateProvider.notifier)
              .setPosition(latitude, longitude);

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
                latitude = latitude;
                longitude = longitude;
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
          Navigator.of(context).pop();

          setState(() {
            preview = false;
            clicked = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child:Column(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    Icon(Icons.warning, color: Colors.red, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Wajah tidak terdeteksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pastikan wajah berada di dalam frame kamera',
                      textAlign: TextAlign.center,
                    )
                  ]
                )
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
          );
        }
      } 
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Silahkan ajuan pengecualian"),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/makeexception',
          (Route<dynamic> route) => false,
        );
      }
    } 
    on TimeoutException catch (err) {
      print(err);
      Navigator.pop(context);
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
      Navigator.pop(context);
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
                    Uri.parse(Env.locationIqStaticMap)
                        .replace(
                          queryParameters: {
                            'center': "$latitude,$longitude",
                            'size': '100x200',
                            'zoom': '18',
                            'key': Env.locationIqKey,
                            'markers': 'icon:large-red-cutout|$latitude,$longitude',
                            'format': 'jpg',
                            'maptype':'streets'
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
                              "${loc['address']}",
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
										Text(setLocation(latitude, longitude)),
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
							onPressed: () {
								setState(() {
										clicked = true;
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
