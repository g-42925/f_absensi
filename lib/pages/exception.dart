import 'dart:convert';

import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ExceptionPage extends ConsumerStatefulWidget {
  const ExceptionPage({super.key});

  @override
  ConsumerState<ExceptionPage> createState() => _ExceptionPageState();
}

class _ExceptionPageState extends ConsumerState<ExceptionPage> {
  late Future<http.Response>? list;

  Future<http.Response> getLeaveList() async {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    Uri url = Uri.parse("${Env.api}/api/mobile/excList/${other.pegawaiId}");

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

  final List<Map<String, dynamic>> exceptionData = [
    {
      "id": "EXC001",
      "date": "2025-09-05",
      "employee_id": "EMP001",
      "reason": "Terlambat karena macet",
      "status": "pending",
    },
    {
      "id": "EXC002",
      "date": "2025-09-04",
      "employee_id": "EMP002",
      "reason": "Lupa absen masuk",
      "status": "approved",
    },
  ];

  Map<String, dynamic> getStatusColor(String status) {
    switch (status) {
      case "0":
        return {"status": "pending", "color": Colors.orange};
      case "1":
        return {"status": "approved", "color": Colors.green};
      case "2":
        return {"status": "rejected", "color": Colors.red};
      default:
        return {"status": "pending", "color": Colors.orange};
    }
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pengecualian")),
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
                          margin: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 3,
                          child: ListTile(
                            leading: Icon(
                              Icons.event_note,
                              color: getStatusColor(item['status'])['color'],
                            ),
                            title: Text(
                              "Tanggal: ${item['date']}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Reason: ${item['reason']}"),
                            trailing: Text(
                              getStatusColor(
                                item['status'],
                              )['status'].toString().toUpperCase(),
                              style: TextStyle(
                                color: getStatusColor(item['status'])['color'],
                                fontWeight: FontWeight.bold,
                              ),
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
          Navigator.pushNamed(context, '/makeexception');
        },
        tooltip: 'Tambah',
        child: const Icon(Icons.add),
      ),
    );
  }
}
