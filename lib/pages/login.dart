import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        final String workSystem = responseBody['result']['workSystem'];

        final start = workSystem == "shift"
            ? responseBody['result']['clock_in']
            : responseBody['result']['jam_masuk'];
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
          salaryDate: int.parse(responseBody['result']['salary_date']),
        );

        final Schedule schedule = (
          start: start ?? '',
          finish: finish ?? '',
          breakStart: breakStart,
          breakFinish: breakEnd,
          workSystem: workSystem,
          workSystemName: workSystemName,
        );

        final Iterable<Map<String, dynamic>> location =
            (responseBody['result']['locations'] as List).map((l) {
              return {
                'lat': l['garis_lintang'] ?? '',
                'lon': l['garis_bujur'] ?? '',
                'address': l['alamat_lokasi'] ?? '',
                'locationName': l['nama_lokasi'] ?? '',
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
        );

        final Holiday holiday = (
          holiday: responseBody['result']['holiday'] as bool,
          workDay: workDay,
        );

        final Status status = (signedIn: false, signedOut: false);

        final Auth auth = (
          loggedIn: true,
          date: DateTime.now().toIso8601String(),
        );

        final OverWork overWork = (onOverWork: false);

        ref.read(globalStateProvider.notifier).login((
          auth: auth,
          status: status,
          company: company,
          schedule: schedule,
          permission: (id: 0),
          location: (list: location.toList()),
          position: (lat: 0, lon: 0),
          other: other,
          history: [],
          coordinate: (lat: 0, lon: 0),
          holiday: holiday,
          breakInfo: (onBreak: false, startFrom: ''),
          overWork: overWork,
        ));

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (Route<dynamic> route) => false,
        );
      } else {
        print("gagal");
      }
    } catch (e) {
      print("error");
      print(e);
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final auth = ref.read(globalStateProvider).auth;

    Future.delayed(Duration.zero, () {
      // if (auth.loggedIn) {
      //   Navigator.pushNamedAndRemoveUntil(
      //     context,
      //     '/home',
      //     (Route<dynamic> route) => false,
      //   );
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      height: 80,
                    ),
                    const Text(
                      'workly',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
