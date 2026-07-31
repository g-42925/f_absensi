import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../env/env.dart';
import '../providers/global_state.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


class TaskStartPage extends ConsumerStatefulWidget {
  final CameraDescription camera;
  final Future<Map<String, double>> coord;

  const TaskStartPage({super.key, required this.camera, required this.coord});

  @override
  ConsumerState<TaskStartPage> createState() => _TaskStartPageState();
}

class _TaskStartPageState extends ConsumerState<TaskStartPage> {
  CameraController? _controller;
  Future<void>? _cameraFuture;
  final GlobalKey _globalKey = GlobalKey();
  SupabaseClient supabase = Supabase.instance.client;
  bool preview = false;
  Future<Position>? position;


  final controller = TextEditingController();

  double latitude = 0;
  double longitude = 0;
  String locationName = 'Anda berada di luar area presensi';

  Map<dynamic, dynamic>? _selectedLocation;

  bool clicked = false;

  Map<String, String> loc = {'address': '',};

  String path = "";

  bool isSuspicious = false;

  bool isCameraDenied = false;
  bool _cameraDisclosureAccepted = false;

  Future<void> showDisclosureDialog({required String title, required String message, required IconData icon, required VoidCallback onConfirm,required VoidCallback onDenied}) async {
    await showDialog(
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
  }

  Future<dynamic> requestLocation() async{
    LocationPermission permission = await Geolocator.requestPermission();
    
    if(permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return Geolocator.getCurrentPosition();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose(); 
  }

  void _initCamera() {
    _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);
    setState(() {
      _cameraFuture = _controller!.initialize();
    });
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

    return locations.any((locs) {
      final lat2 = double.parse(locs['lat']);
      final lon2 = double.parse(locs['lon']);
      final distance = haversineDistance(latitude, lat2, longitude, lon2);

      return distance <= 50; // true jika ada lokasi dalam 50 meter
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
          _initCamera();
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
      _initCamera();
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

      if (haversineDistance(lat1, lat2, lon1, lon2) < 200) {
        return locs['locationName'];
      }
    }

    return locationName;
  }

  void captureAndUpload(String? pegawaiId,dynamic id) async {
    final supabase = Supabase.instance.client;
    final currentTime = DateTime.now();

    try {
      final state = ref.read(globalStateProvider);
      final other = state.other;
      final company = state.company;
      final img = await _controller!.takePicture();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}';
      final url = Uri.parse("${Env.api}/api/mobile/taskstart");
      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type": "application/json"};
      final now = DateTime.now(); // ambil tanggal sekarang
      final formatted = DateFormat('yyyy-MM-dd').format(now);
      final formattedSecond = DateFormat('HH:mm:ss').format(now);
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final uploadUrl = Uri.parse("${Env.api}/filebase/task/$fileName/${company.id}");

      loc['address'] = _selectedLocation != null ? _selectedLocation!['address'] : 'Tidak diketahui';
      locationName = _selectedLocation != null ? _selectedLocation!['locationName'] : 'Tidak diketahui';

      setState(() {
        path = img.path;
        preview = true;
      });

      final result = await captureScreen();

      final bytes = result.asUint8List();


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
          contentType: MediaType('image', 'png'),
        ),
      );

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        print("something went wrong");
      }

      final responseBody = await streamedResponse.stream.bytesToString();

      final uploadResponse = responseBody;

      final params = {
        "start_photo": uploadResponse,
        "start_location": "$latitude/$longitude",
        "employee_id": pegawaiId,
        'task_id': id,
        'is_mock': isSuspicious
      };

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

        Navigator.pop(context);
      } 
      else {
        Navigator.of(context).pop();

        ref.read(globalStateProvider.notifier).startTask(id,latitude,longitude);

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
                      'task submit is success',
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
    on TimeoutException catch (err) {
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
  }

  Widget setPreview(dynamic id) {
   final _lat2 = double.parse(_selectedLocation!['lat'].toString());
    final _lon2 = double.parse(_selectedLocation!['lon'].toString());
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

  Widget setCamera(dynamic id) {
    final globalState = ref.read(globalStateProvider);
    final schedule = globalState.schedule;
    final other = globalState.other;
    final workSystemName = schedule.workSystemName;
    final locations = globalState.location.list;

    final currentLoc = _selectedLocation ?? (locations.isNotEmpty ? locations.first : null);

    bool isOutOfRadius = true;
    if (currentLoc != null) {
      final lat2 = double.parse(currentLoc['lat'].toString());
      final lon2 = double.parse(currentLoc['lon'].toString());
      final radius = int.parse(currentLoc['radius'].toString());
      final distance = haversineDistance(latitude, lat2, longitude, lon2);
      isOutOfRadius = distance > radius;
    }

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
                    Text(DateFormat('EEEE, dd MMM yyyy').format(DateTime.now())),
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
                                  final filteredItems = locations.where((loc) {
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
              backgroundColor: clicked ? Colors.red : Colors.green[600],
              padding: EdgeInsets.symmetric(vertical: 16), // tinggi button
            ),
            onPressed: isOutOfRadius ? null : () {
              setState(() {
                clicked = true;
                _selectedLocation = currentLoc;
              });
              captureAndUpload(
                other.pegawaiId,
                id,
              );
            },
            child: Text(
              "Mulai",
              style: TextStyle(color: Colors.white,fontSize: 16),
            ),
          ),
         ),
        ),
      ]
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
			error: (err, _) => Scaffold(
        body: Center(child: Text('Gagal mengambil lokasi\n$err')),
      ),
			data: (position){
				WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted && (latitude != position['position'].latitude || longitude != position['position'].longitude)){
					  print("isSuspicious");
            setState(() {
              latitude = position['position'].latitude;
              longitude = position['position'].longitude;
              isSuspicious = position['isSuspicious'];
            });
					}
        });

        if(isCameraDenied){
          return Scaffold(
            body: Center(child: Text('Camera access is denied')),
          );
        }

        return Scaffold(
          appBar: !preview
            ? 
            AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
              ),
            )
           : null,
           body: _cameraFuture == null
           ? const Center(child: CircularProgressIndicator())
           : FutureBuilder(
            future: _cameraFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Kamera gagal dimuat:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
               return preview ? setPreview(args['task_id']) : setCamera(args['task_id']);
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
