import 'dart:convert';

import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class LongPermissionPage extends ConsumerStatefulWidget {
  const LongPermissionPage({super.key});

  @override
  ConsumerState<LongPermissionPage> createState() => _LongPermissionPageState();
}

class _LongPermissionPageState extends ConsumerState<LongPermissionPage> {
  final TextEditingController reason = TextEditingController();
  final dateFormat = DateFormat("yyyy-MM-dd");
  final url = Uri.parse("${Env.api}/api/mobile/afp");

  String selectedEntries = '';

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  String formatTanggal(DateTime? date) {
    if (date == null) return "Pilih Tanggal";
    return "${date.day}/${date.month}/${date.year}";
  }

  final entries = [
    DropdownMenuEntry(value: 'i', label: 'Izin'),
    DropdownMenuEntry(value: 's', label: 'Sakit'),
  ];

  void sendRequest(String companyId, String pegawaiId) async {
    final headers = {"Content-type": "application/json"};

    final params = {
      'company_id': companyId,
      'tanggal_request': dateFormat.format(tanggalMulai!),
      'tanggal_request_end': dateFormat.format(tanggalSelesai!),
      'tipe_request': selectedEntries,
      'catatan_awal': reason.text,
      'pegawai_id': pegawaiId,
    };

    try {
      await http.post(url, headers: headers, body: jsonEncode(params));
      Navigator.pushReplacementNamed(context, '/permission_success');
    } catch (e) {
      print(e);
    }
  }

  Future<void> pilihTanggal(BuildContext context, bool isMulai) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isMulai) {
          tanggalMulai = picked;
        } else {
          tanggalSelesai = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalState = ref.read(globalStateProvider);
    final company = globalState.company;
    final other = globalState.other;
    return Scaffold(
      appBar: AppBar(title: const Text("Izin Hari")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => pilihTanggal(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Pada tanggal",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(formatTanggal(tanggalMulai)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => pilihTanggal(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Sampai tanggal",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(formatTanggal(tanggalSelesai)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            DropdownMenu<String>(
              width: MediaQuery.of(context).size.width - 32,
              hintText: "Kategori",
              dropdownMenuEntries: entries,
              onSelected: (value) async {
                setState(() {
                  selectedEntries = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: "Keperluan",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  sendRequest(company.id, other.pegawaiId);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Kirim Permintaan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
