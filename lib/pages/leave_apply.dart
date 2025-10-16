import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/global_state.dart';
import '../env/env.dart';

class LeaveApplyPage extends ConsumerStatefulWidget {
  const LeaveApplyPage({super.key});

  @override
  ConsumerState<LeaveApplyPage> createState() => _LeaveApplyPageState();
}

class _LeaveApplyPageState extends ConsumerState<LeaveApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  String formatTanggal(DateTime? date) {
    if (date == null) return "Pilih Tanggal";
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null &&
        picked != (isStartDate ? tanggalMulai : tanggalSelesai)) {
      setState(() {
        if (isStartDate) {
          tanggalMulai = picked;
        } else {
          tanggalSelesai = picked;
        }
      });
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

  void _submitForm(int quota) async {
    final other = ref.read(globalStateProvider).other;
    final company = ref.read(globalStateProvider).company;
    final Duration d = tanggalSelesai!.difference(tanggalMulai!);
    final xTanggalMulai = DateFormat("yyyy-MM-dd").format(tanggalMulai!);
    final xTanggalSelesai = DateFormat("yyyy-MM-dd").format(tanggalSelesai!);
    final url = Uri.parse("${Env.api}/api/mobile/leave");
    final headers = {"Content-type": "application/json"};

    if (d.inDays > quota) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // supaya bisa atur tinggi
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return FractionallySizedBox(
            widthFactor: 1.0,
            heightFactor: 0.5, // setengah layar
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    "Tidak bisa melebihi sisa jumlah cuti",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Periksa kembali',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      final params = {
        'company_id': company.id,
        'tanggal_request': xTanggalMulai,
        'tanggal_request_end': xTanggalSelesai,
        'catatan_awal': _reasonController.text,
        'pegawai_id': other.pegawaiId,
      };

      try {
        await http.post(url, headers: headers, body: jsonEncode(params));
        Navigator.pushReplacementNamed(context, '/permission_success');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("gagal mengajukan cuti!"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int quota = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      appBar: AppBar(title: const Text('Form Pengajuan Cuti')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              GestureDetector(
                onTap: () => _selectDate(context, true),
                child: AbsorbPointer(
                  child: Expanded(
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
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context, false),
                child: AbsorbPointer(
                  child: Expanded(
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
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Alasan Cuti',
                  hintText: 'Jelaskan alasan pengajuan cuti Anda...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alasan cuti tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _submitForm(quota);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Ajukan Cuti',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
