import 'dart:convert';

import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class LeavePage extends ConsumerStatefulWidget {
  const LeavePage({super.key});

  @override
  ConsumerState<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends ConsumerState<LeavePage> {
  late Future<http.Response>? list;
  int quota = 0;

  Future<http.Response> getLeaveList() async {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    Uri url = Uri.parse("${Env.api}/api/mobile/leavelist/${other.pegawaiId}");

    return http.get(url);
  }

  Future<void> fetch() async {
    setState(() {
      list = null;
    });
    setState(() {
      list = getLeaveList();
    });
  }

  void hapusCuti(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Apakah Anda yakin ingin membatalkan cuti ini?'),
        actions: [
          TextButton(
            child: Text('Batal'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Hapus'),
            onPressed: () {
              setState(() {});
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  String count(String start, String end) {
    DateTime startDate = DateTime.parse(start);
    DateTime endDate = DateTime.parse(end);
    int difference = endDate.difference(startDate).inDays + 1;
    return "${difference.toString()} Hari";
  }

  Map<String, dynamic> makeStatus(int status) {
    if (status == 0) {
      return {
        'text': 'pending',
        'statusStyle': TextStyle(fontSize: 12, color: Colors.orange),
        'counterStyle': TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.orange.shade700,
        ),
        'decoration': BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
      };
    }
    if (status == 1) {
      return {
        'text': 'approved',
        'statusStyle': TextStyle(fontSize: 12, color: Colors.blue),
        'counterStyle': TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
        'decoration': BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
      };
    }
    if (status == 2) {
      return {
        'text': 'rejected',
        'statusStyle': TextStyle(fontSize: 12, color: Colors.red),
        'counterStyle': TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.red.shade700,
        ),
        'decoration': BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade100, Colors.red.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
      };
    }

    return {'text': '', 'statusStyle': null, 'color': null};
  }

  Widget _buildDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildItem(
    String title,
    String value,
    String subtitle,
    Color valueColor,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cuti")),
      body: list != null
          ? FutureBuilder(
              future: list as Future<http.Response>,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else {
                  if (snapshot.hasError) {
                    return Center(child: Text("something went wrong"));
                  } else {
                    final response = snapshot.data!;
                    final data = jsonDecode(response.body);
                    if (data['success'] as bool) {
                      if (quota == 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            quota = data['result']['quota'];
                          });
                        });
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              _buildItem(
                                "Sisa",
                                "${data['result']['quota']}",
                                "Hari",
                                Colors.red,
                              ),
                              _buildDivider(),
                              _buildItem(
                                "Terpakai",
                                "${data['result']['used']}",
                                "Hari",
                                Colors.black,
                              ),
                              _buildDivider(),
                            ],
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount:
                                  (data['result']['list'] as List).length,
                              itemBuilder: (context, index) {
                                final cuti =
                                    (data['result']['list'] as List)[index];
                                return Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // Kiri
                                          Container(
                                            width: 80,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            decoration: makeStatus(
                                              int.parse(cuti['is_status']),
                                            )['decoration'],

                                            child: Column(
                                              children: [
                                                Text(
                                                  count(
                                                    cuti['tanggal_request'],
                                                    cuti['tanggal_request_end'],
                                                  ),
                                                  style: makeStatus(
                                                    int.parse(
                                                      cuti['is_status'],
                                                    ),
                                                  )['counterStyle'],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  makeStatus(
                                                    int.parse(
                                                      cuti['is_status'],
                                                    ),
                                                  )['text'],
                                                  style: makeStatus(
                                                    int.parse(
                                                      cuti['is_status'],
                                                    ),
                                                  )['statusStyle'],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Garis pemisah vertikal
                                          Container(
                                            width: 1,
                                            height: 60,
                                            color: Colors.grey.shade300,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                          ),

                                          // Kanan
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cuti['catatan_awal'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors.teal,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      "${cuti['tanggal_request']}  |  ${cuti['tanggal_request_end']}",
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      width: double.infinity,
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Center(child: Text("something went wrong"));
                    }
                  }
                }
              },
            )
          : SizedBox(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/leaveapply', arguments: quota);
        },
        tooltip: 'Tambah',
        child: const Icon(Icons.add),
      ),
    );
  }
}
