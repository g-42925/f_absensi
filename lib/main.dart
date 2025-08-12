import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './models/info.dart';
import './pages/login.dart';
import './pages/signin.dart';


void main() async {
  Map<String,double> coordinate = {
    'lat':0,
    'lon':0
  };

  await Supabase.initialize(
    url: 'https://vgbkdwivxidacojvcnbr.supabase.co',
    anonKey: 'sb_publishable_25TewwFEWm3n3W-L0Mzm-g_CQLq68Dm',
  );

  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();

  final camera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front);

  bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();

  LocationPermission locationPermission = await Geolocator.checkPermission();


  if(isLocationServiceEnabled){
    if(locationPermission == LocationPermission.whileInUse){
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      coordinate = {
        'lat':position.latitude,
        'lon':position.longitude
      };
    }
    else{
      locationPermission = await Geolocator.requestPermission();
      if(locationPermission == LocationPermission.whileInUse){
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        coordinate = {
          'lat':position.latitude,
          'lon':position.longitude
        };
      }
    }
  }

  runApp(
    MultiProvider(
      providers:[ChangeNotifierProvider(create:(_) => Info())],
      child: MyApp(coordinate:coordinate,camera:camera)
    )
  );
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  final Map<String,double> coordinate;
  
  MyApp({
    super.key,
    required this.camera,
    required this.coordinate
  });

  Map<String,WidgetBuilder> createRoute(){
    return {
      '/': (_) => LoginPage(),
      '/signin': (_) => SignInPage(
        camera:camera,
        coord:coordinate
      ),
      '/feature' : (_) => MyHomePage(
        title:'Flutter',
        titleX:"XXX"
      ),
    };
  }

  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      routes:createRoute(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key, 
    required this.title,
    required this.titleX
  });

  final String title;
  final String titleX;

  @override State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> { 
  void initState(){
    super.initState();
  }
  

  @override Widget build(BuildContext context) {
    final bool signedIn = context.read<Info>().signedIn;
    final Company company = context.read<Info>().detail.company;
    final Schedule schedule = context.read<Info>().detail.schedule;
    final String message = "maka sesungguhnya bersama kesulitan itu ada kemudahan";
    final String scheduleStartTtime = schedule.start;
    final String scheduleFinishTime = schedule.finish;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png', // Ganti dengan path image kamu
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'workly',
              style: TextStyle(color: Colors.black),
            ),
          ]
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
                child:Column(
                  children:[
                    Row(
                      children:[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16.0), // ubah angka untuk radius berbeda
                           child: Image.network(
                            'http://172.24.113.245/lss_absensi/assets/uploaded/components/${company.logo}',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          )
                        ),
                        SizedBox(
                          width:15
                        ),
                        Container(
                          width:250,
                          child:Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:[
                              Text(company.name,style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),
                              Text(message,overflow:TextOverflow.visible,style:TextStyle(color:Colors.white))
                            ]
                          )
                        )
                      ]
                    ),
                    SizedBox(
                      height:16
                    ),
                    Container(
                      padding:const EdgeInsets.all(16),
                      decoration:BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color:Colors.white
                      ),
                      width:double.infinity,
                      child:Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children:[
                          Text("Jadwal Anda Hari Ini"),
                          SizedBox(height:6),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child:Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.login),
                                    SizedBox(width: 4),
                                    Text(scheduleStartTtime),
                                  ],
                                ),
                                Text('...'),
                                Row(
                                  children: [
                                    Icon(Icons.logout),
                                    SizedBox(width: 4),
                                    Text(scheduleFinishTime),
                                  ],
                                ),
                              ],
                            )
                          )
                        ]
                      )
                    )
                  ]
                )
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  IconLabel(icon: Icons.local_cafe, label: 'Istirahat'),
                  IconLabel(icon: Icons.access_time, label: 'Lembur'),
                  IconLabel(icon: Icons.event_busy, label: 'Cuti'),
                  IconLabel(icon: Icons.door_front_door, label: 'Izin'),
                  IconLabel(icon: Icons.work, label: 'Pekerjaan'),
                  IconLabel(icon: Icons.business_center, label: 'Kunjungan'),
                  IconLabel(icon: Icons.calendar_today, label: 'Kalender'),
                  IconLabel(icon: Icons.group, label: 'Karyawan'),
                  IconLabel(icon: Icons.account_balance_wallet, label: 'Gaji'),
                  IconLabel(icon: Icons.assignment_turned_in, label: 'Klaim'),
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
                    )
                  ]
                )
              ),
              SizedBox(height:16),
              Container(
                width:double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context, 
                      '/signin'
                    );
                  },
                  icon: const Icon(
                    Icons.login,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Presensi Masuk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688), // hijau tosca
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // oval
                    ),
                    elevation: 0, // tanpa shadow
                  ),
                )
              )
            ]
          )
        )
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.black54,
        currentIndex: 0,
        type: BottomNavigationBarType.fixed, // <== Tambahkan ini
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Jadwal'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Aktivitas'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifikasi'),
        ],
      )
    );
  }
}


class IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const IconLabel({required this.icon, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(icon, color: Colors.teal),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))
      ],
    );
  }
}
