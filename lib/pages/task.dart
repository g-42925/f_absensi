import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/global_state.dart';
import '../env/env.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class TaskPage extends ConsumerStatefulWidget {
  final Future<Map<String, double>> coord;
  final CameraDescription camera;

  const TaskPage({super.key, required this.coord, required this.camera});

  @override
  ConsumerState<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends ConsumerState<TaskPage> {
  late Future<http.Response>? list;

  Future<http.Response> getTaskList() async {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    Uri url = Uri.parse("${Env.api}/api/mobile/taskList/${other.pegawaiId}");

    var response = http.get(url);

    try {
      await response;
    } catch (e) {
      print(e);
    }

    return response;
  }

  Future<void> fetch() async {
    setState(() {
      list = null;
    });
    setState(() {
      list = getTaskList();
    });
  }

  @override
  void initState() {
    super.initState();
    fetch();

    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await Future.delayed(Duration(seconds: 2));
    //   final globalState = ref.read(globalStateProvider);
    //   final locations = globalState.location.list;
    //   final coordinate = await widget.coord;

    //   for (var locs in locations) {
    //     final lat1 = coordinate['lat'];
    //     final lat2 = double.parse(locs['lat']);
    //     final lon1 = coordinate['lon'];
    //     final lon2 = double.parse(locs['lon']);

    //     if (haversineDistance(lat1, lat2, lon1, lon2) < 200) {
    //       setState(() {
    //         latitude = lat2;
    //         longitude = lon2;
    //         locationName = locs['locationName'];
    //       });
    //     } else {
    //       setState(() {
    //         latitude = lat1 as double;
    //         longitude = lon1 as double;
    //       });
    //     }
    //   }

    //   print(latitude);
    //   print(longitude);
    // });
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.read(globalStateProvider).task;
    return Scaffold(
      appBar: AppBar(title: Text("Penugasan")),
      body: list != null
          ? FutureBuilder(
              future: list,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("something went wrong"));
                } else {
                  final response = snapshot.data!;
                  final data = jsonDecode(response.body);
                  if (data['success'] as bool) {
                    return ListView.builder(
                      itemCount: (data['result'] as List).length,
                      itemBuilder: (context, index) {
                        final item = (data['result'] as List)[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              6,
                            ), // ubah angka 20 sesuai keinginan
                          ),
                          margin: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  leading: Icon(Icons.event_note),
                                  title: Text(
                                    "Tgl: ${item['date']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Description: ${item['description']}",
                                  ),
                                ),
                              ),
                              TextButton(
                                child: Text("Mulai"),
                                onPressed: () {
                                  final limit = DateTime.parse(
                                    "${item['date']} 00:00:00",
                                  ).add(Duration(days: 1));
                                  if (DateTime.now().isAfter(limit)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Form tugas ini sudah kadaluwarsa',
                                        ),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    if (task.started.contains(
                                      item['task_id'],
                                    )) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Sudah submit data kehadiran',
                                          ),
                                          backgroundColor: Colors.blue,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        '/task_start',
                                        arguments: {'task_id': item['task_id']},
                                      );
                                    }
                                  }
                                },
                              ),
                              TextButton(
                                child: Text("Selesai"),
                                onPressed: () {
                                  final limit = DateTime.parse(
                                    "${item['date']} 00:00:00",
                                  ).add(Duration(days: 1));
                                  if (DateTime.now().isAfter(limit)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Form tugas ini sudah kadaluwarsa',
                                        ),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    if (task.finished.contains(
                                      item['task_id'],
                                    )) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'tugas ini sudah selesai',
                                          ),
                                          backgroundColor: Colors.blue,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        '/task_end',
                                        arguments: {'task_id': item['task_id']},
                                      );
                                    }
                                  }
                                },
                              ),
                              TextButton(
                                child: Text("Edit"),
                                onPressed: () {
                                  final limit = DateTime.parse(
                                    "${item['date']} 00:00:00",
                                  ).add(Duration(days: 1));
                                  if (DateTime.now().isAfter(limit)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Form tugas ini sudah kadaluwarsa',
                                        ),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    Navigator.pushNamed(
                                      context,
                                      '/task_edit',
                                      arguments: {
                                        'date': item['date'],
                                        'desc': item['description'],
                                        'id': item['task_id'],
                                      },
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                }

                return SizedBox();
              },
            )
          : SizedBox(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/make_task');
        },
        tooltip: 'Tambah',
        child: const Icon(Icons.add),
      ),
    );
  }
}
