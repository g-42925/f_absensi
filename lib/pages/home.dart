import 'dart:async';

import 'package:f_absensi/pages/login.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/global_state.dart';
import '../env/env.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  bool stillOnTheSameDay = false;
  late Future<bool>? loggedIn;

  Future<void> isLoggedIn(bool loggedIn) async {
    setState(() {
      loggedIn = loggedIn;
    });
  }

  @override
  void initState() {
    super.initState();

    final auth = ref.read(globalStateProvider).auth;

    isLoggedIn(auth.loggedIn);

    if (auth.loggedIn) {
      final authDate = DateTime.parse(auth.date);

      final expired = DateTime(authDate.year, authDate.month, authDate.day + 1);

      if (DateTime.now().isAfter(expired)) {
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    }
  }

  bool iSOTSD(String date) {
    final dateNow = DateTime.now();
    final dateX = DateTime.parse(date);
    final c1 = DateTime(dateX.year, dateX.month, dateX.day);
    final c2 = DateTime(dateNow.year, dateNow.month, dateNow.day);

    return c2.isAfter(c1);
  }

  DateTime makeTime(DateTime param) {
    DateTime now = DateTime.now();

    return DateTime(now.year, now.month, now.day, param.hour, param.minute);
  }

  ElevatedButton? createButton(
    Status status,
    Break breakInfo,
    bool sOTSD,
    Schedule schedule,
    bool onOverWork,
  ) {
    DateTime targetTime = DateFormat("HH:mm").parse(schedule.start);
    DateTime targetTimeX = DateFormat("HH:mm").parse(schedule.finish);

    if (!status.signedIn && !status.signedOut) {
      return ElevatedButton.icon(
        onPressed: () {
          if (DateTime.now().isAfter(makeTime(targetTime))) {
            Navigator.pushNamed(context, '/signin');
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, // supaya bisa atur tinggi
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return FractionallySizedBox(
                  heightFactor: 0.5,
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Belum bisa masuk sekarang.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mohon tunggu sampai waktunya tiba',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
        icon: const Icon(Icons.login, size: 18, color: Colors.white),
        label: const Text(
          'Presensi Masuk',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // hijau tosca
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // tanpa shadow
        ),
      );
    }

    if (status.signedIn && breakInfo.onBreak) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/breakend');
        },
        icon: Icon(
          Icons.local_cafe,
          color: Colors.white, // warna ikon putih
        ),
        label: const Text(
          'Selesai Istirahat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // hijau tosca
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // tanpa shadow
        ),
      );
    }

    if (status.signedIn && !status.signedOut) {
      return ElevatedButton.icon(
        onPressed: () {
          if (DateTime.now().isAfter(makeTime(targetTimeX))) {
            Navigator.pushNamed(context, '/signout');
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, // supaya bisa atur tinggi
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: 0.5, // setengah layar
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Belum bisa pulang sekarang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mohon tunggu sampai waktunya tiba',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
        icon: const Icon(Icons.login, size: 18, color: Colors.white),
        label: const Text(
          'Presensi Pulang',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // hijau tosca
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // tanpa shadow
        ),
      );
    }

    if (status.signedIn && status.signedOut && !onOverWork) {
      return ElevatedButton.icon(
        onPressed: () {},
        label: const Text(
          'Selamat beristirahat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // hijau tosca
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // tanpa shadow
        ),
      );
    }

    if (status.signedIn && status.signedOut && onOverWork) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/overwork_end');
        },
        icon: Icon(
          Icons.access_time,
          color: Colors.white, // warna ikon putih
        ),
        label: const Text(
          'Selesaikan Lembur',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // hijau tosca
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // tanpa shadow
        ),
      );
    }

    return null;
  }

  Widget SplashScreen(loggedIn) {
    Future.delayed(const Duration(seconds: 8), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });

    return Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    final globalState = ref.read(globalStateProvider);
    final holiday = globalState.holiday;
    final company = globalState.company;
    final schedule = globalState.schedule;
    final status = globalState.status;
    final breakInfo = globalState.breakInfo;
    final auth = globalState.auth;
    final breakStartTime = auth.loggedIn ? schedule.breakStart : "00:00";
    final breakStart = DateFormat("HH:mm").parse(breakStartTime);
    final onOverWork = globalState.overWork.onOverWork;

    final String message =
        "maka sesungguhnya bersama kesulitan itu ada kemudahan";

    return auth.loggedIn
        ? Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Image.asset(
                    'assets/logo.png', // Ganti dengan path image kamu
                    height: 30,
                  ),
                  const SizedBox(width: 8),
                  const Text('workly', style: TextStyle(color: Colors.black)),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: const [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text('TR', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF004D40), // hijau toska sangat gelap
                            Color(0xFF00796B), // hijau toska gelap
                            Color(0xFF26A69A), // toska terang
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  16.0,
                                ), // ubah angka untuk radius berbeda
                                child: Image.network(
                                  "${Env.api}/assets/uploaded/components/${company.logo}",
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 15),
                              SizedBox(
                                width: 250,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      message,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: holiday.holiday || !holiday.workDay
                                  ? [Text("Selamat Berlibur")]
                                  : [
                                      Text("Jadwal Anda Hari Ini"),
                                      SizedBox(height: 6),
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.5,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.login),
                                                SizedBox(width: 4),
                                                Text(schedule.start),
                                              ],
                                            ),
                                            Text('...'),
                                            Row(
                                              children: [
                                                Icon(Icons.logout),
                                                SizedBox(width: 4),
                                                Text(schedule.finish),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        IconLabel(
                          icon: Icons.local_cafe,
                          label: 'Istirahat',
                          onPressed: () {
                            if (DateTime.now().isAfter(makeTime(breakStart))) {
                              Navigator.pushNamed(context, '/break');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Belum waktunya istirahat"),
                                  duration: Duration(seconds: 2), // lama tampil
                                  backgroundColor:
                                      Colors.blue, // warna background
                                ),
                              );
                            }
                          },
                        ),
                        IconLabel(
                          icon: Icons.access_time,
                          label: 'Lembur',
                          onPressed: () {
                            if (status.signedOut) {
                              Navigator.pushNamed(context, '/overwork');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Belum bisa akses fitur ini"),
                                  duration: Duration(
                                    seconds: 2,
                                  ), // lama tampilnya
                                ),
                              );
                            }
                          },
                        ),
                        IconLabel(
                          icon: Icons.event_busy,
                          label: 'Cuti',
                          onPressed: () {
                            Navigator.pushNamed(context, '/leave');
                          },
                        ),
                        IconLabel(
                          icon: Icons.door_front_door,
                          label: 'Izin',
                          onPressed: () {
                            Navigator.pushNamed(context, '/permission');
                          },
                        ),
                        IconLabel(icon: Icons.work, label: 'Pekerjaan'),
                        IconLabel(
                          icon: Icons.calendar_today,
                          label: 'Kalender',
                          onPressed: () {
                            Navigator.pushNamed(context, '/calendar');
                          },
                        ),
                        IconLabel(icon: Icons.group, label: 'Karyawan'),
                        IconLabel(
                          onPressed: () {
                            Navigator.pushNamed(context, '/salary');
                          },
                          icon: Icons.account_balance_wallet,
                          label: 'Gaji',
                        ),
                        IconLabel(
                          icon: Icons.assignment_turned_in,
                          label: 'Klaim',
                        ),
                        IconLabel(
                          icon: Icons.note_add,
                          label: 'Pengecualian',
                          onPressed: () {
                            Navigator.pushNamed(context, '/exception');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 0),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FFDC), // Hijau muda
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Ringkasan Kehadiran",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Periksa kinerja rekap Anda bulan ini",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Image.asset(
                            'assets/ilustrasi.png', // ganti dengan path gambar kamu
                            height: 80,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: createButton(
                        status,
                        breakInfo,
                        iSOTSD(auth.date),
                        schedule,
                        onOverWork,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomNavigationBar(
              selectedItemColor: Colors.teal,
              unselectedItemColor: Colors.black54,
              currentIndex: 0,
              type: BottomNavigationBarType.fixed, // <== Tambahkan ini
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Jadwal',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Aktivitas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Notifikasi',
                ),
              ],
            ),
          )
        : Scaffold(body: SplashScreen(auth.loggedIn));
  }
}

class IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const IconLabel({
    required this.icon,
    required this.label,
    this.onPressed, // optional
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal.shade50,
            child: Icon(icon, color: Colors.teal),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
