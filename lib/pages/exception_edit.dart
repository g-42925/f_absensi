import 'dart:convert';
import 'dart:io';

import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExceptionEditPage extends ConsumerStatefulWidget {
  const ExceptionEditPage({super.key});

  @override
  ConsumerState<ExceptionEditPage> createState() => _ExceptionEditPageState();
}

class _ExceptionEditPageState extends ConsumerState<ExceptionEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _selectedDate;
  String? selectedValue;
  final ImagePicker _picker = ImagePicker();

  XFile? _image;

  final List<Map<String, String>> typeList = [
    {'id': '68cf640082e8c', 'value': 'Terlambat'},
    {'id': '68cf640082e8x', 'value': 'Di luar kantor'},
    {'id': '8474832hd8322', 'value': 'Belum kembali ke kantor'},
  ];

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm(String pegawaiId) async {
    final url = Uri.parse("${Env.api}/api/mobile/makeexception");

    final headers = {"Content-type": "application/json"};

    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final file = File(_image!.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_image!.name}';
      final supabase = Supabase.instance.client;

      await supabase.storage.from('storage').upload(fileName, file);

      final uploaded = supabase.storage.from('storage').getPublicUrl(fileName);

      final exceptionData = {
        "date": _selectedDate!.toIso8601String().split("T")[0],
        "reason": _reasonController.text,
        "employee_id": pegawaiId,
        "type": selectedValue,
        "image": uploaded,
      };

      try {
        final exc = await http.post(
          url,
          headers: headers,
          body: jsonEncode(exceptionData),
        );

        if (jsonDecode(exc.body)['success']) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("coba beberapa saat lagi"),
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.pop(context);
        }
      } catch (e) {
        print(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("gagal mengajukan pengecualian!"),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Harap lengkapi data terlebih dahulu")),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;

    return Scaffold(
      appBar: AppBar(title: Text("Ajukan Pengecualian")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pilih tanggal
              Text("Tanggal"),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _pickDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? args['date']
                        : "${_selectedDate!.toLocal()}".split(" ")[0],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Alasan eksepsi
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Alasan",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Alasan tidak boleh kosong";
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.all(0),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButton<String>(
                  value: selectedValue,
                  hint: const Text('Pilih jenis pengecualiann'),
                  isExpanded: true, // biar lebar mengikuti parent
                  underline: const SizedBox(), // hilangkan garis bawaan
                  items: typeList.map((Map<String, String> r) {
                    return DropdownMenuItem<String>(
                      value: r['value'],
                      child: Text(r['value']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedValue = value;
                    });
                  },
                ),
              ),
              SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('From Galery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('New Image'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.send),
                  label: Text("Kirim Pengajuan"),
                  onPressed: () => {_submitForm(other.pegawaiId)},
                ),
              ),
              SizedBox(height: 24),
              if (_image != null && !isKeyboardVisible)
                Center(
                  child: Image.file(
                    File(_image!.path),
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                )
              else if (!isKeyboardVisible)
                const Text('Silahkan tambahkan bukti pengajuan'),
            ],
          ),
        ),
      ),
    );
  }
}
