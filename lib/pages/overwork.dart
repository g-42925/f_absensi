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

class OverWorkPage extends ConsumerStatefulWidget {
  final Future<Map<String, double>> coord;
  final CameraDescription camera;

  const OverWorkPage({super.key, required this.coord, required this.camera});

  @override
  ConsumerState<OverWorkPage> createState() => _OverWorkPageState();
}

class _OverWorkPageState extends ConsumerState<OverWorkPage> {
  late Future<http.Response>? list;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<http.Response> getLeaveList() async {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    Uri url = Uri.parse("${Env.api}/api/mobile/ovwList/${other.pegawaiId}");

    try {
      return await http.get(url).timeout(const Duration(seconds: 30));
    } 
    on TimeoutException catch(err) {
      throw Error();
    }
    catch (err) {
      throw Error();
    }
  }

  Future<void> fetch() async {
    setState(() {
      list = null;
    });
    setState(() {
      list = getLeaveList();
    });
  }

  Map<String, dynamic> getStatusColor(String status) {
    switch (status) {
      case "0":
        return {"status": "pending", "color": Colors.orange};
      case "1":
        return {"status": "approved", "color": Colors.green};
      default:
        return {"status": "pending", "color": Colors.orange};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: list != null
          ? FutureBuilder(
              future: list,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
									WidgetsBinding.instance.addPostFrameCallback((_) {
										showModalBottomSheet(
											context: context,
											backgroundColor: Colors.transparent,
											builder: (_) => Container(
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
																"Request timeout or something went wrong",
																style: TextStyle(color: Colors.white),
															),
														),
													],
												),
											),
										);
									});

									return SizedBox();
                } 
                else {
                  final response = snapshot.data!;
                  final data = jsonDecode(response.body);
                  if (data['success'] as bool) {
                    return ListView.builder(
                      itemCount: (data['result'] as List).length,
                      itemBuilder: (context, index) {
                        final item = (data['result'] as List)[index];
                        return Card(
                          margin: EdgeInsets.only(left: 16, right: 16, top: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.event_note,
                                      color: getStatusColor(
                                        item['approved'],
                                      )['color'],
                                    ),
                                    title: Text(
                                      "Tgl: ${DateFormat('d MMM').format(DateTime.parse(item['date']))}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text("Reason: ${item['reason']}"),
                                  ),
                                ),
                                SizedBox(width: 6),
                                TextButton(
                                  onPressed: () {
                                    final until = DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).parse(item['until']);
                                    final startFrom = DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).parse(item['start_from']);
                                    if (DateTime.now().isBefore(until)) {
                                      if (DateTime.now().isAfter(startFrom)) {
                                        if (item['approved'] == '1') {
                                          Navigator.pushNamed(
                                            context,
                                            '/overwork_start',
                                            arguments: {
                                              'id':
                                                  item['employee_overwork_detail_id'],
                                              'id2':
                                                  item['employee_overwork_id'],
                                            },
                                          );
                                        } 
                                        else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "form lembur ini belum disetujui",
                                              ),
                                              duration: Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "belum bisa mengakses waktu lembur",
                                            ),
                                            duration: Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "form lembur ini sudah kadaluwarsa",
                                          ),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text("Mulai"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final until = DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).parse(item['until']);
                                    if (DateTime.now().isAfter(until)) {
                                      Navigator.pushNamed(
                                        context,
                                        '/overwork_end',
                                        arguments: {
                                          'id':
                                              item['employee_overwork_detail_id'],
                                          'id2': item['employee_overwork_id'],
                                        },
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "form lembur ini belum bisa di klaim",
                                          ),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text("Selesai"),
                                ),
                              ],
                            ),
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
          Navigator.pushNamed(context, '/makeoverwork');
        },
        tooltip: 'Tambah',
        child: const Icon(Icons.add),
      ),
    );
  }
}