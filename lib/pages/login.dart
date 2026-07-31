import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/global_state.dart';
import '../env/env.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final url = Uri.parse("${Env.api}/api/mobile/loginv2");
  
  static const _channel = MethodChannel('uptime');



  bool visibility = false;
  bool loading = false;

  setVisible() {
    setState(() {
      visibility = !visibility;
    });
  }

  login() async {
    setState(() {
      loading = true;
    });

    Map<String, String> credential = {
      'email': emailController.text,
      'pwd': passwordController.text,
    };

    Map<String, String> headers = {'Content-Type': 'application/json'};

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(credential),
      );   

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['success'] == false) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid Email or Password'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final String workSystem = responseBody['result']['workSystem'];

        final start = workSystem == "shift"
          ? responseBody['result']['clock_in']
          : responseBody['result']['jam_masuk'];

        final nextStart = workSystem == "shift"
          ? responseBody['result']['clock_in']
          : responseBody['result']['next']['jam_masuk'];

        final finish = workSystem == "shift"
          ? responseBody['result']['clock_out']
          : responseBody['result']['jam_pulang'];
      
        final workDay = workSystem == "shift"
          ? responseBody['result']['workDay']
          : responseBody['result']['workDay'];
        final workSystemName = workSystem == "shift"
          ? responseBody['result']['workSystemName']
          : responseBody['result']['workSystemName'];

        final breakStart = workSystem == "shift"
          ? responseBody['result']['break']
          : responseBody['result']['jam_istirahat'];

        final breakEnd = workSystem == "shift"
          ? responseBody['result']['after_break']
          : responseBody['result']['selesai_istirahat'];

        final Company company = (
          id: responseBody['result']['company_id'] ?? '',
          name: responseBody['result']['company_name'] ?? '',
          logo: responseBody['result']['logo'] ?? '',
          address: responseBody['result']['address'] ?? '',
          salaryDate: int.tryParse(responseBody['result']['salary_date']?.toString() ?? '0') ?? 0,
        );

        final Schedule schedule = (
          start: start ?? '',
          nextStart: nextStart ?? '',
          finish: finish ?? '',
          breakStart: breakStart,
          breakFinish: breakEnd,
          workSystem: workSystem,
          workSystemName: workSystemName,
        );

        final locationsRaw = responseBody['result']['locations'] ?? [];

        final Iterable<Map<String, dynamic>> location =
          (locationsRaw as List).map((l) {
          return {
            'lat': l['garis_lintang']?.toString() ?? '',
            'lon': l['garis_bujur']?.toString() ?? '',
            'address': l['alamat_lokasi'] ?? '',
            'locationName': l['nama_lokasi'] ?? '',
            'radius': l['jangkauan_radius'] ?? 0,
            'mainLocation': l['main_location'] == "1" ? true : false,
          };
        });


        final warningList = responseBody['result']['warningList'] ?? [];


        final Iterable<Map<String, dynamic>> violations = (warningList as List).map((v){
          return {
            'id': v['id'] ?? '',
            'employeeId': v['employee_id'] ?? '',
            'sp_number': v['sp_number'] ?? '',
            'level': v['level'] ?? '',
            'title': v['title'] ?? '',
            'violation': v['violation'] ?? '',
            'date': v['date'] ?? '',
            'createdAt': v['createdAt'] ?? '',
            'penalty': v['penalty'] ?? '',
            'issuedBy': v['issuedBy'] ?? '',
          };
        });
        

        final Other other = (
          pegawaiId: responseBody['result']['pegawai_id'] ?? '',
          namaPegawai: responseBody['result']['nama_pegawai'] ?? '',
          nomorPegawai: responseBody['result']['nomor_pegawai'] ?? '',
          emailPegawai: responseBody['result']['email_pegawai'] ?? '',
          fotoPegawai: responseBody['result']['foto_pegawai'] ?? '',
          position: responseBody['result']['position'] ?? '',
          status: responseBody['result']['status_pegawai'] ?? '',
          nik: responseBody['result']['nik'] ?? '',
        );

        final Holiday holiday = (
          holiday: responseBody['result']['holiday'] ?? false,
          workDay: workDay,
        );


        final Status status = (signedIn: false, signedOut: false);

        final Auth auth = (
          loggedIn: true,
          date: DateTime.now().toIso8601String(),
        );

        final OverWork overWork = (onOverWork: false);

        final ffocia = responseBody['result']['ffocia'] == "1" ? true : false;
        final ffocoa = responseBody['result']['ffocoa'] == "1" ? true : false;

        final coLimit = int.tryParse(responseBody['result']['co_limit']?.toString() ?? '0') ?? 0;

        final ciLimit = int.tryParse(responseBody['result']['ci_limit']?.toString() ?? '0') ?? 0;

        final tolerance = int.tryParse(responseBody['result']['tolerance']?.toString() ?? '0') ?? 0;


        final Config config = (
          ffocia: ffocia,
          ffocoa: ffocoa,
          coLimit: coLimit,
          ciLimit: ciLimit,
          tolerance: tolerance,
        );


        final XPresence presence = workSystem == "shift" ? (
          ci:responseBody['result']['clock_in'],
          co:responseBody['result']['clock_out'],
        ) : (
          ci:responseBody['result']['jam_masuk'],
          co:responseBody['result']['jam_pulang'],
        );



        ref.read(globalStateProvider.notifier).login((
          auth: auth,
          status: status,
          company: company,
          schedule: schedule,
          permission: (id: 0),
          location: (list: location.toList()),
          position: (lat: 0.0, lon: 0.0),
          other: other,
          history: <String>[],
          coordinate: (lat: 0.0, lon: 0.0),
          holiday: holiday,
          breakInfo: (onBreak: false, startFrom: ''),
          overWork: overWork,
          config: config,
          task: (started: <String>[], finished: <String>[]),
          exception: (list: <String>[]),
          csh: (allowed: false),
          reminder: (lastLat: 0.0, lastLon: 0.0),
          presence: presence,
          offlineEntries: <Map<String, dynamic>>[],
          serverTimeInfo: (serverTime: null, upTime: null),
          violation: (list:violations.toList()),
        ));

        Navigator.pushReplacementNamed(context, '/');
      } 
      else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Email or Password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }  
    finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final auth = ref.read(globalStateProvider).auth;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png', // Ganti dengan path logo-mu
                        height: 120,
                      ),
                    ],
                  ),
                  const Text(
                    'Online Attendance Application',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login using your company employee account',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Input Email
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Input Password
                  TextField(
                    controller: passwordController,
                    obscureText: visibility ? false : true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          visibility ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setVisible(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot Password?'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tombol Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => login(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: loading
                          ? CircularProgressIndicator()
                          : Text('Login'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Belum punya akun
                  TextButton(
                    onPressed: () {},
                    child: const Text("Don't have employee account yet?"),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final url = Uri.parse("https://lerynsoftware.com/privacy");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: const Text(
                      "Privacy Policy",
                      style: TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
