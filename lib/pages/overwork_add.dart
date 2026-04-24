import 'dart:convert';
import 'dart:async';
import 'package:absensi/env/env.dart';
import 'package:absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class OverWorkAddPage extends ConsumerStatefulWidget {
  const OverWorkAddPage({super.key});

  @override
  ConsumerState<OverWorkAddPage> createState() => _OverWorkAddPageState();
}

class _OverWorkAddPageState extends ConsumerState<OverWorkAddPage> {
  final _formKey = GlobalKey<FormState>();

  final _controller1 = TextEditingController();
  final _controller2 = TextEditingController();
  final _controller3 = TextEditingController();

  DateTime? _selectedDateTime;
  DateTime? _selectedFinishDateTime;

  final timeUri = Uri.parse("https://time.now/developer/api/ip");

  void _submitForm() async {


    try{
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
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Time validation",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );

      final start = ref.read(globalStateProvider).schedule.finish.split(":");
      final time = await http.get(timeUri).timeout(Duration(seconds: 30));
      final url = Uri.parse("${Env.api}/api/mobile/makeoverwork");
      final pegawaiId = ref.read(globalStateProvider).other.pegawaiId;
      final headers = {"Content-type": "application/json"};
      final response = await http.get(timeUri).timeout(Duration(seconds: 30));
      final _time = DateTime.parse(jsonDecode(time.body)['datetime']);

      final custom = DateTime(_time.year, _time.month, _time.day,int.parse(start[0]), int.parse(start[1]), int.parse(start[2])).add(
        const Duration(minutes: 59)
      );

      Navigator.of(context).pop();

      if (_formKey.currentState!.validate() && _selectedDateTime != null) {
        if (_selectedDateTime!.isAfter(custom)) {
          final overWorkData = {
            "start_from": DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateTime!),
            "until": DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedFinishDateTime!),
            "reason": _controller2.text,
            "employee_id": pegawaiId,
          };

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
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Submiting overwork request",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );

          final exc = await http.post(
            url,
            headers: headers,
            body: jsonEncode(overWorkData),
          )
          .timeout(
            const Duration(seconds: 30)
          );

          Navigator.of(context).pop();

          if (jsonDecode(exc.body)['success']) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) => false,
            );
          } 
          else {
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
                        "something went wrong",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } 
        else {
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
                      "something went wrong",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } 
      else {
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
                    "something went wrong",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    on TimeoutException catch(e){
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
                  "Request timeout",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );    
    }
    catch(e){
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
                  "something went wrong",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }  
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _selectedDateTime = selected;
      _controller1.text =
          "${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')} "
          "${time.format(context)}";
    });
  }

  Future<void> setFinish(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedFinishDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _selectedFinishDateTime = selected;
      _controller3.text =
          "${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')} "
          "${time.format(context)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Form Lembur')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _controller1,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Mulai dari',
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () => _selectDateTime(context),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _controller3,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Sampai',
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () => setFinish(context),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller2,
                decoration: InputDecoration(
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.send),
                  label: Text("Kirim Pengajuan"),
                  onPressed: () => _submitForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
