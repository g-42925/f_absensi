import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart' as aw;

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
  Future<Position>? position;

  final client = Client()
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('690ec18e001dfc4c748b');

  final controller = TextEditingController();

  double latitude = 0;
  double longitude = 0;
  String locationName = 'Anda berada di luar area presensi';

  String selectedValue = "";

  Map<String, String> loc = {
    'subDistrict': '',
    'province': '',
    'country': '',
    'address': '',
  };

  String path = "";

  Future<void> requestPositionPermission() async {
    setState(() {
      position = null;
    });

    await Geolocator.requestPermission();

    setState(() {
      position = Geolocator.getCurrentPosition();
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize().then((_) {
      print("camera ready");
    });
    position = Geolocator.getCurrentPosition();
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

  bool isOnOffice(double latitude, double longitude) {
    final globalState = ref.read(globalStateProvider);
    final locations = globalState.location.list;
    num distance = 0;

    for (var locs in locations) {
      final lat1 = latitude;
      final lat2 = double.parse(locs['lat']);
      final lon1 = longitude;
      final lon2 = double.parse(locs['lon']);
      distance = haversineDistance(lat1, lat2, lon1, lon2);
    }

    return distance > 50 ? false : true;
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
      } else {
        // setState(() {
        //   latitude = lat1;
        //   longitude = lon1;
        // });
      }
    }

    return locationName;
  }

  void captureAndUpload(
    double latitude,
    double longitude,
    String? pegawaiId,
  ) async {
    final storage = Storage(client);
    final supabase = Supabase.instance.client;
    final currentTime = DateTime.now();

    final uri = Uri.parse(Env.gMapUrl).replace(
      queryParameters: {'latlng': "$latitude,$longitude", 'key': Env.gMapKey},
    );

    try {
      final state = ref.read(globalStateProvider);
      final other = state.other;
      final company = state.company;
      final img = await _controller.takePicture();
      final requestResponse = await http.get(uri);
      final response = jsonDecode(requestResponse.body);
      final target = response['results'][0];
      final addressComponents = target['address_components'];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final url = Uri.parse("${Env.api}/api/mobile/signin");
      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type": "application/json"};
      final now = DateTime.now(); // ambil tanggal sekarang
      final formatted = DateFormat('yyyy-MM-dd').format(now);
      final formattedSecond = DateFormat('HH:mm:ss').format(now);
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final exception = Uri.parse("${Env.api}/api/mobile/makeexception");

      final targetUrl = state.config.ffocia
          ? url
          : isOnOffice(latitude, longitude)
          ? url
          : exception;

      loc['address'] = target['formatted_address'];
      loc['subDistrict'] = addressComponents[3]['short_name'];
      loc['province'] = addressComponents[5]['short_name'];
      loc['country'] = addressComponents[6]['long_name'];

      setState(() {
        latitude = latitude;
        longitude = longitude;
        path = img.path;
        preview = true;
      });

      final result = await captureScreen();

      await supabase.storage
          .from('storage')
          .uploadBinary(fileName, result.asUint8List());

      // kirim sebagai binary
      // final file = await storage.createFile(
      //   permissions: [aw.Permission.read(Role.any())],
      //   bucketId: '690ec331002a1b163da5',
      //   fileId: ID.unique(), // biar ID file otomatis
      //   file: InputFile.fromBytes(
      //     bytes: result.asUint8List(),
      //     filename: fileName, // wajib kasih nama file
      //   ), // binary file dari input
      // );

      // final publicUrl = storage.getFileView(
      //   bucketId: '690ec331002a1b163da5',
      //   fileId: file.$id,
      // );

      final publicUrl = await supabase.storage
          .from('storage')
          .getPublicUrl(fileName);

      final ffoci = locationName == "Anda berada di luar area presensi";

      final params = {
        "is_status": "hhk",
        "jam_masuk": formattedTime,
        "foto_absen_masuk": publicUrl,
        "point_latitude": latitude,
        "point_longitude": longitude,
        "latitude_masuk": latitude,
        "longitude_masuk": longitude,
        "pegawai_id": pegawaiId,
        "ffoci": ffoci,
      };

      if (state.config.ffocia || isOnOffice(latitude, longitude)) {
        final xRequest = await http.post(
          targetUrl,
          headers: headers,
          body: jsonEncode(params),
        );

        print(xRequest.body);

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
        } else {
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
                'image': publicUrl,
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
            } catch (e) {
              print(e);
            }
          }

          ref.read(globalStateProvider.notifier).signIn();
          ref
              .read(globalStateProvider.notifier)
              .setPosition(latitude, longitude);

          setState(() {
            latitude = latitude;
            longitude = longitude;
            path = img.path;
            preview = false;
          });
        }
      } else {
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
                            'center': "$latitude,$longitude",
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

  Widget setCamera(List<Map<String, dynamic>>? list, Other other) {
    final entries = (list ?? []).map((l) {
      return DropdownMenuEntry(
        value: '${l['lat']}/${l['lon']}',
        label: '${l['locationName']}',
      );
    }).toList();

    entries.add(DropdownMenuEntry(value: '0/0', label: 'pilih lokasi'));

    final globalState = ref.read(globalStateProvider);
    final schedule = globalState.schedule;
    final workSystemName = schedule.workSystemName;

    return position != null
        ? FutureBuilder(
            future: position,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  requestPositionPermission();
                });
                return Center(child: CircularProgressIndicator());
              } else {
                final response = snapshot.data;
                final latitude = response?.latitude;
                final longitude = response?.longitude;

                return Stack(
                  children: [
                    Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: CameraPreview(_controller),
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
                                Text(
                                  "$workSystemName - ${DateFormat('EEEE, dd MMM yyyy').format(DateTime.now())}",
                                ),
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
                                Text(setLocation(latitude!, longitude!)),
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
                            backgroundColor: Colors.green[600], // hijau gelap
                            padding: EdgeInsets.symmetric(
                              vertical: 16,
                            ), // tinggi button
                          ),
                          onPressed: () {
                            captureAndUpload(
                              latitude,
                              longitude,
                              other.pegawaiId,
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
            },
          )
        : SizedBox();

    // return position != null
    //     ? FutureBuilder(
    //         future: position,
    //         builder: (context, snapshot) {
    //           if (snapshot.connectionState == ConnectionState.waiting) {
    //             return Center(child: CircularProgressIndicator());
    //           }
    //           if (snapshot.hasError) {
    //             requestPositionPermission();
    //             return Center(child: CircularProgressIndicator());
    //           } else {
    //             final response = snapshot.data;
    //             final latitude = response?.latitude;
    //             final longitude = response?.longitude;
    //             return Container(
    //               margin: EdgeInsets.symmetric(horizontal: 16),
    //               child: Column(
    //                 children: [
    //                   DropdownMenu<String>(
    //                     width: MediaQuery.of(context).size.width - 32,
    //                     hintText: "Pilih lokasi kehadiran",
    //                     controller: controller,
    //                     dropdownMenuEntries: entries.toList(),
    //                     onSelected: (value) async {
    //                       final lt = double.parse(value?.split('/')[0] ?? '0');
    //                       final lng = double.parse(value?.split('/')[1] ?? '0');

    //                       print(
    //                         haversineDistance(latitude, lt, longitude, lng),
    //                       );
    //                       if (haversineDistance(latitude, lt, longitude, lng) >
    //                           200) {
    //                         showModalBottomSheet(
    //                           context: context,
    //                           isScrollControlled:
    //                               true, // supaya bisa atur tinggi
    //                           shape: const RoundedRectangleBorder(
    //                             borderRadius: BorderRadius.vertical(
    //                               top: Radius.circular(20),
    //                             ),
    //                           ),
    //                           builder: (context) {
    //                             return FractionallySizedBox(
    //                               heightFactor: 0.5, // setengah layar
    //                               child: Padding(
    //                                 padding: const EdgeInsets.all(20),
    //                                 child: Column(
    //                                   mainAxisAlignment:
    //                                       MainAxisAlignment.center,
    //                                   children: [
    //                                     const Icon(
    //                                       Icons.error_outline,
    //                                       color: Colors.red,
    //                                       size: 60,
    //                                     ),
    //                                     const SizedBox(height: 20),
    //                                     const Text(
    //                                       'Lokasi tidak tersedia untuk dipilih',
    //                                       textAlign: TextAlign.center,
    //                                       style: TextStyle(
    //                                         fontSize: 20,
    //                                         fontWeight: FontWeight.bold,
    //                                       ),
    //                                     ),
    //                                     const SizedBox(height: 8),
    //                                     const Text(
    //                                       'Kamu berada terlalu jauh dari lokasi yang dipilih',
    //                                       textAlign: TextAlign.center,
    //                                       style: TextStyle(
    //                                         fontSize: 16,
    //                                         color: Colors.black54,
    //                                       ),
    //                                     ),
    //                                   ],
    //                                 ),
    //                               ),
    //                             );
    //                           },
    //                         );
    //                         controller.clear();
    //                         selectedValue = "";
    //                       } else {
    //                         final lat = value?.split('/')[0] as String;
    //                         final idx = list?.indexWhere(
    //                           (i) => i['lat'] == lat,
    //                         );
    //                         final target = list?[idx as int];
    //                         controller.text = target?['locationName'];
    //                         selectedValue =
    //                             "${target?['lat']}/${target?['lon']}";
    //                       }
    //                     },
    //                   ),
    //                   SizedBox(height: 16),
    //                   Stack(
    //                     children: [
    //                       ClipRRect(
    //                         borderRadius: BorderRadius.circular(8),
    //                         child: CameraPreview(_controller),
    //                       ),
    //                       Positioned(
    //                         bottom: 20,
    //                         width: MediaQuery.of(context).size.width - 32,
    //                         child: Padding(
    //                           padding: EdgeInsets.all(16),
    //                           child: ElevatedButton.icon(
    //                             onPressed: () {
    //                               captureAndUpload(other.pegawaiId);
    //                             },
    //                             icon: const Icon(
    //                               Icons.login,
    //                               size: 18,
    //                               color: Colors.white,
    //                             ),
    //                             label: const Text(
    //                               'Presensi Masuk',
    //                               style: TextStyle(
    //                                 color: Colors.white,
    //                                 fontSize: 14,
    //                                 fontWeight: FontWeight.w500,
    //                               ),
    //                             ),
    //                             style: ElevatedButton.styleFrom(
    //                               backgroundColor: Colors.red, // hijau tosca
    //                               padding: const EdgeInsets.symmetric(
    //                                 horizontal: 20,
    //                                 vertical: 12,
    //                               ),
    //                               shape: RoundedRectangleBorder(
    //                                 borderRadius: BorderRadius.circular(8),
    //                               ),
    //                               elevation: 0, // tanpa shadow
    //                             ),
    //                           ),
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 ],
    //               ),
    //             );
    //           }

    //           return Center(child: CircularProgressIndicator());
    //         },
    //       )
    //     : SizedBox();

    // return Container(
    //   margin: EdgeInsets.symmetric(horizontal: 16),
    //   child: Column(
    //     children: [
    //       DropdownMenu<String>(
    //         width: MediaQuery.of(context).size.width - 32,
    //         hintText: "Pilih lokasi kehadiran",
    //         controller: controller,
    //         dropdownMenuEntries: entries.toList(),
    //         onSelected: (value) async {
    //           final c = await widget.coord;
    //           final lt = double.parse(value?.split('/')[0] as String);
    //           final lng = double.parse(value?.split('/')[1] as String);
    //           if (haversineDistance(c['lat'], lt, c['lon'], lng) > 200) {
    //             showModalBottomSheet(
    //               context: context,
    //               isScrollControlled: true, // supaya bisa atur tinggi
    //               shape: const RoundedRectangleBorder(
    //                 borderRadius: BorderRadius.vertical(
    //                   top: Radius.circular(20),
    //                 ),
    //               ),
    //               builder: (context) {
    //                 return FractionallySizedBox(
    //                   heightFactor: 0.5, // setengah layar
    //                   child: Padding(
    //                     padding: const EdgeInsets.all(20),
    //                     child: Column(
    //                       mainAxisAlignment: MainAxisAlignment.center,
    //                       children: [
    //                         const Icon(
    //                           Icons.error_outline,
    //                           color: Colors.red,
    //                           size: 60,
    //                         ),
    //                         const SizedBox(height: 20),
    //                         const Text(
    //                           'Lokasi tidak tersedia untuk dipilih',
    //                           textAlign: TextAlign.center,
    //                           style: TextStyle(
    //                             fontSize: 20,
    //                             fontWeight: FontWeight.bold,
    //                           ),
    //                         ),
    //                         const SizedBox(height: 8),
    //                         const Text(
    //                           'Kamu berada terlalu jauh dari lokasi yang dipilih',
    //                           textAlign: TextAlign.center,
    //                           style: TextStyle(
    //                             fontSize: 16,
    //                             color: Colors.black54,
    //                           ),
    //                         ),
    //                       ],
    //                     ),
    //                   ),
    //                 );
    //               },
    //             );
    //             controller.clear();
    //             selectedValue = "";
    //           } else {
    //             final lat = value?.split('/')[0] as String;
    //             final idx = list?.indexWhere((i) => i['lat'] == lat);
    //             final target = list?[idx as int];
    //             controller.text = target?['locationName'];
    //             selectedValue = "${target?['lat']}/${target?['lon']}";
    //           }
    //         },
    //       ),
    //       SizedBox(height: 16),
    //       Stack(
    //         children: [
    //           ClipRRect(
    //             borderRadius: BorderRadius.circular(8),
    //             child: CameraPreview(_controller),
    //           ),
    //           Positioned(
    //             bottom: 20,
    //             width: MediaQuery.of(context).size.width - 32,
    //             child: Padding(
    //               padding: EdgeInsetsGeometry.all(16),
    //               child: ElevatedButton.icon(
    //                 onPressed: () {
    //                   captureAndUpload(other.pegawaiId);
    //                 },
    //                 icon: const Icon(
    //                   Icons.login,
    //                   size: 18,
    //                   color: Colors.white,
    //                 ),
    //                 label: const Text(
    //                   'Presensi Masuk',
    //                   style: TextStyle(
    //                     color: Colors.white,
    //                     fontSize: 14,
    //                     fontWeight: FontWeight.w500,
    //                   ),
    //                 ),
    //                 style: ElevatedButton.styleFrom(
    //                   backgroundColor: Colors.red, // hijau tosca
    //                   padding: const EdgeInsets.symmetric(
    //                     horizontal: 20,
    //                     vertical: 12,
    //                   ),
    //                   shape: RoundedRectangleBorder(
    //                     borderRadius: BorderRadius.circular(8),
    //                   ),
    //                   elevation: 0, // tanpa shadow
    //                 ),
    //               ),
    //             ),
    //           ),
    //         ],
    //       ),
    //     ],
    //   ),
    // );
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
