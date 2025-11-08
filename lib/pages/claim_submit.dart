import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ClaimSubmitPage extends ConsumerStatefulWidget {
  const ClaimSubmitPage({super.key});

  @override
  ConsumerState<ClaimSubmitPage> createState() => _ClaimSubmitPageState();
}

class _ClaimSubmitPageState extends ConsumerState<ClaimSubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController valueController = TextEditingController();
  DateTime? _selectedDate;
  String? selectedValue; // nilai yang dipilih
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  final List<Map<String, String>> list = [
    {'id': '68cf640082e8c', 'value': 'Tiket perjalanan'},
    {'id': '68cf640082e8x', 'value': 'Alat tulis kantor'},
  ];

  final List<String> items = ['Indonesia', 'Jepang', 'Korea', 'Amerika'];

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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  void _submitForm(String pegawaiId) async {
    final url = Uri.parse("${Env.api}/api/mobile/makeclaim");
    final supabase = Supabase.instance.client;
    final file = File(_image!.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_image!.name}';
    await supabase.storage.from('storage').upload(fileName, file);

    final uploaded = supabase.storage.from('storage').getPublicUrl(fileName);

    final headers = {"Content-type": "application/json"};

    if (_formKey.currentState!.validate()) {
      final exceptionData = {
        "value": valueController.text,
        "employee_id": pegawaiId,
        'reimburse_id': selectedValue,
        'photo': uploaded,
      };

      try {
        final exc = await http.post(
          url,
          headers: headers,
          body: jsonEncode(exceptionData),
        );

        if (jsonDecode(exc.body)['success']) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("coba beberapa saat lagi"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("gagal mengajukan pengecualian!"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Harap lengkapi data terlebih dahulu")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final List<Map<String, dynamic>> resultList =
        List<Map<String, dynamic>>.from(args['result']);

    // Sekarang bisa map dengan aman
    final List<Map<String, String>> list = resultList
        .map(
          (n) => {
            'value': n['reimburse_id'].toString(),
            'name': n['reimburse_name'].toString(),
          },
        )
        .toList();

    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text("Ajukan Reimburse")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pilih tanggal
              Container(
                margin: const EdgeInsets.all(8),
                child: Text("Jenis Reimburse"),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButton<String>(
                  value: selectedValue,
                  hint: const Text('Pilih jenis reimburse'),
                  isExpanded: true, // biar lebar mengikuti parent
                  underline: const SizedBox(), // hilangkan garis bawaan
                  items: list.map((Map<String, String> r) {
                    return DropdownMenuItem<String>(
                      value: r['value'],
                      child: Text(r['name']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedValue = value;
                    });
                  },
                ),
              ),
              SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.all(8),
                child: TextFormField(
                  controller: valueController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "Jumlah",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Jumlah tidak boleh kosong";
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 8),
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
              SizedBox(height: 8),
              // Tombol Submit
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
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
