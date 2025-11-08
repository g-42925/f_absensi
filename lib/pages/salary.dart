import 'dart:convert';

import 'package:f_absensi/env/env.dart';
import 'package:f_absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SalaryPage extends ConsumerStatefulWidget {
  const SalaryPage({super.key});

  @override
  ConsumerState<SalaryPage> createState() => _SalaryPageState();
}

class InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool isBold;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryPageState extends ConsumerState<SalaryPage> {
  DateTime? selectedDate1;
  DateTime? selectedDate2;
  final _formKey = GlobalKey<FormState>();

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  String formatTanggal(DateTime? date) {
    if (date == null) return "Pilih Tanggal";
    return "${date.day}/${date.month}/${date.year}";
  }

  final int year = DateTime.now().year;
  final int month = DateTime.now().month;
  final int day = DateTime.now().day;

  late Future<http.Response>? salary;

  DateTime get dt1 => DateTime(year, month, 1); // awal bulan
  DateTime get dt2 => makeSalaryDate(); // hari ini

  // bulan sebelumnya
  DateTime get from1 => DateTime(dt1.year, dt1.month - 1, 1);
  DateTime get to1 =>
      DateTime(dt1.year, dt1.month, 0); // 0 = hari terakhir bulan lalu

  // range lain
  DateTime get from2 => DateTime(dt2.year, dt2.month - 1, dt2.day);
  DateTime get to2 => dt2.subtract(const Duration(days: 1));

  DateTime get from => (day == 1) ? from1 : from2;
  DateTime get to => (day == 1) ? to1 : to2;

  String get start => from.toIso8601String().split('T').first;
  String get end => to.toIso8601String().split('T').first;

  DateTime makeSalaryDate() {
    final globalState = ref.read(globalStateProvider);
    final salaryDate = globalState.company.salaryDate;
    return DateTime(year, month, salaryDate);
  }

  Future<http.Response> getSalary() async {
    final now = DateTime.now();
    final globalState = ref.read(globalStateProvider);
    final empId = globalState.other.pegawaiId;
    final salaryDate = globalState.company.salaryDate;
    final date = DateTime(now.year, now.month, salaryDate);
    final sDate = DateFormat('yyyy-MM-dd').format(date);
    Uri url = Uri.parse("${Env.api}/api/mobile/salary/${empId}/$sDate");

    print(url);

    return http.get(url);
  }

  Future<void> checkCurrentSalary(
    DateTime tglMulai,
    DateTime tglSelesai,
  ) async {
    final now = DateTime.now();
    final globalState = ref.read(globalStateProvider);
    final empId = globalState.other.pegawaiId;
    final salaryDate = globalState.company.salaryDate;
    final date = DateTime(now.year, now.month, salaryDate);
    final sDate = DateFormat('yyyy-MM-dd').format(date);
    final tglX = DateFormat('yyyy-MM-dd').format(tglMulai);
    final tglY = DateFormat('yyyy-MM-dd').format(tglSelesai);

    Uri url = Uri.parse("${Env.api}/api/mobile/salary/${empId}/$tglX/$tglY");

    try {
      final test = await http.get(url);

      Navigator.pushNamed(
        context,
        '/salary_slip',
        arguments: {'result': jsonDecode(test.body)},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coba beberapa saat lagi'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, 1),
      firstDate: DateTime(now.year - 1),
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

  Future<void> _selectDate2(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: firstDayOfMonth,
      lastDate: DateTime(2101),
    );
    setState(() {
      tanggalSelesai = picked;
    });
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

  final formatRupiah = NumberFormat.currency(
    locale: 'id', // locale Indonesia
    symbol: 'Rp ',
    decimalDigits: 0, // jumlah angka di belakang koma
  );

  final formatAngka = NumberFormat.decimalPattern('id');

  List<Widget> makeBenefitAndPenaltyList(List<Map<String, dynamic>> list) {
    final bPList = list.map((el) {
      return InfoRow(label: el['name'], value: el['value'].toString());
    });

    return bPList.toList();
  }

  List<Widget> makeAllowanceList(List<Map<String, dynamic>> list) {
    final allowanceList = list.map((el) {
      return InfoRow(label: el['name'], value: el['value'].toString());
    });

    return allowanceList.toList();
  }

  Future<void> fetch() async {
    setState(() {
      salary = null;
    });
    setState(() {
      salary = getSalary();
    });
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Salary')),
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
                          labelText: "Mulai dari",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(formatTanggal(tanggalMulai)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _selectDate2(context, true),
                child: AbsorbPointer(
                  child: Expanded(
                    child: GestureDetector(
                      onTap: () => pilihTanggal(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Sampai",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(formatTanggal(tanggalSelesai)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Warna tombol
                  foregroundColor: Colors.white, // Warna teks
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  checkCurrentSalary(tanggalMulai!, tanggalSelesai!);
                },
                child: Text('Tombol Hijau'),
              ),
            ],
          ),
        ),
      ),
    );

    // @override
    // Widget build(BuildContext context) {
    //   final globalState = ref.read(globalStateProvider);
    //   final other = globalState.other;
    //   final company = globalState.company;

    //   Widget buildInfoRow(String label, dynamic value) {
    //     return Padding(
    //       padding: const EdgeInsets.symmetric(vertical: 2),
    //       child: Row(
    //         children: [
    //           SizedBox(width: 100, child: Text("$label :")),
    //           Expanded(child: Text(value)),
    //         ],
    //       ),
    //     );
    //   }

    // return Scaffold(
    //   appBar: AppBar(title: const Text("Slip Gaji"), centerTitle: true),
    //   body: salary != null
    //       ? FutureBuilder(
    //           future: salary,
    //           builder: (context, snapshot) {
    //             if (snapshot.connectionState == ConnectionState.waiting) {
    //               return Center(child: CircularProgressIndicator());
    //             }
    //             if (snapshot.hasError) {
    //               return Center(child: Text("something went wrong"));
    //             } else {
    //               final response = snapshot.data!;
    //               final data = jsonDecode(response.body);
    //               return Padding(
    //                 padding: EdgeInsets.all(16.0),
    //                 child: SingleChildScrollView(
    //                   child: Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: [
    //                       Center(
    //                         child: Column(
    //                           children: [
    //                             Text(
    //                               company.name,
    //                               style: TextStyle(
    //                                 fontSize: 18,
    //                                 fontWeight: FontWeight.bold,
    //                               ),
    //                             ),
    //                             SizedBox(height: 4),
    //                             Text(company.address),
    //                             Divider(thickness: 1),
    //                           ],
    //                         ),
    //                       ),
    //                       const SizedBox(height: 8),
    //                       Center(
    //                         child: Text(
    //                           "SLIP GAJI KARYAWAN",
    //                           style: TextStyle(
    //                             fontSize: 16,
    //                             fontWeight: FontWeight.bold,
    //                           ),
    //                         ),
    //                       ),
    //                       Center(child: Text("Periode: $start - $end")),
    //                       const SizedBox(height: 16),

    //                       // Info Karyawan
    //                       buildInfoRow("Nama", other.namaPegawai),
    //                       buildInfoRow("NIK", other.pegawaiId),
    //                       buildInfoRow("Jabatan", other.position),
    //                       buildInfoRow("Status", other.status),

    //                       const SizedBox(height: 16),

    //                       Row(
    //                         crossAxisAlignment: CrossAxisAlignment.start,
    //                         children: [
    //                           // Penghasilan
    //                           Expanded(
    //                             child: Column(
    //                               crossAxisAlignment: CrossAxisAlignment.start,
    //                               children: [
    //                                 Text(
    //                                   "PENGHASILAN",
    //                                   style: TextStyle(
    //                                     fontWeight: FontWeight.bold,
    //                                   ),
    //                                 ),
    //                                 SizedBox(height: 4),
    //                                 InfoRow(
    //                                   label: "Gaji Pokok",
    //                                   value: formatAngka.format(data['salary']),
    //                                 ),
    //                                 ...makeAllowanceList(
    //                                   List<Map<String, dynamic>>.from(
    //                                     data['allowance'].map((e) {
    //                                       return {
    //                                         'name': e['name'],
    //                                         'value': formatAngka.format(
    //                                           e['value'],
    //                                         ),
    //                                       };
    //                                     }),
    //                                   ),
    //                                 ),
    //                                 Divider(),
    //                                 InfoRow(
    //                                   label: "TOTAL (A)",
    //                                   value: formatAngka.format(
    //                                     data['totalIncome'],
    //                                   ),
    //                                   isBold: true,
    //                                 ),
    //                               ],
    //                             ),
    //                           ),
    //                           const SizedBox(width: 16),
    //                           // Potongan
    //                         ],
    //                       ),
    //                       const SizedBox(height: 16),
    //                       Row(
    //                         crossAxisAlignment: CrossAxisAlignment.start,
    //                         children: [
    //                           // Penghasilan
    //                           Expanded(
    //                             child: Column(
    //                               crossAxisAlignment: CrossAxisAlignment.start,
    //                               children: [
    //                                 Text(
    //                                   "POTONGAN",
    //                                   style: TextStyle(
    //                                     fontWeight: FontWeight.bold,
    //                                   ),
    //                                 ),
    //                                 SizedBox(height: 4),
    //                                 ...makeBenefitAndPenaltyList(
    //                                   List<Map<String, dynamic>>.from(
    //                                     data['benefit'].map((e) {
    //                                       return {
    //                                         'name': e['name'],
    //                                         'value': formatAngka.format(
    //                                           e['value'],
    //                                         ),
    //                                       };
    //                                     }),
    //                                   ),
    //                                 ),
    //                                 ...makeBenefitAndPenaltyList(
    //                                   List<Map<String, dynamic>>.from(
    //                                     data['penalty'].map((e) {
    //                                       return {
    //                                         'name': e['name'],
    //                                         'value': formatAngka.format(
    //                                           e['value'],
    //                                         ),
    //                                       };
    //                                     }),
    //                                   ),
    //                                 ),
    //                                 Divider(),
    //                                 InfoRow(
    //                                   label: "TOTAL (B)",
    //                                   value: formatAngka.format(
    //                                     data['totalBenefit'],
    //                                   ),
    //                                   isBold: true,
    //                                 ),
    //                               ],
    //                             ),
    //                           ),
    //                           const SizedBox(width: 16),
    //                           // Potongan
    //                         ],
    //                       ),

    //                       const SizedBox(height: 16),

    //                       // Penerimaan bersih
    //                       Text(
    //                         "PENERIMAAN BERSIH (A-B)   = Rp ${formatAngka.format(data['thp'])}",
    //                         style: TextStyle(fontWeight: FontWeight.bold),
    //                       ),
    //                     ],
    //                   ),
    //                 ),
    //               );
    //             }
    //           },
    //         )
    //       : SizedBox(),
    // );
  }
}
