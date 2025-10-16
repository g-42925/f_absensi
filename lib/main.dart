import 'package:f_absensi/pages/break.dart';
import 'package:f_absensi/pages/break_end.dart';
import 'package:f_absensi/pages/exception.dart';
import 'package:f_absensi/pages/exception_add.dart';
import 'package:f_absensi/pages/leave.dart';
import 'package:f_absensi/pages/leave_apply.dart';
import 'package:f_absensi/pages/overwork.dart';
import 'package:f_absensi/pages/overwork_end.dart';
import 'package:f_absensi/pages/permission_success.dart';
import 'package:f_absensi/pages/salary.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydrated_riverpod/hydrated_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import './env/env.dart';
import './pages/home.dart';
import './pages/login.dart';
import './pages/signin.dart';
import './pages/signout.dart';
import './pages/permission.dart';
import './pages/permission_handle.dart';
import './pages/short_permission.dart';
import './pages/calendar.dart';
import './pages/long_permission.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  //await initializeDateFormatting('az');

  final storageDirectory = await getApplicationDocumentsDirectory();

  final storage = await HydratedStorage.build(
    storageDirectory: storageDirectory,
  );

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);

  final camera = cameras.firstWhere(
    (cam) => cam.lensDirection == CameraLensDirection.front,
  );

  HydratedRiverpod.initialize(storage: storage);

  runApp(ProviderScope(child: MyApp(camera: camera)));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  Future<Map<String, double>> getLocation(BuildContext context) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      return {'lat': position.latitude, 'lon': position.longitude};
    } catch (e) {
      await Geolocator.requestPermission();
      Position position = await Geolocator.getCurrentPosition();
      return {'lat': position.latitude, 'lon': position.longitude};
    }
  }

  const MyApp({super.key, required this.camera});

  Map<String, WidgetBuilder> createRoute(BuildContext context) {
    return {
      '/': (_) => MyHomePage(),
      '/salary': (_) => SalaryPage(),
      '/exception': (_) => ExceptionPage(),
      '/makeexception': (_) => ExceptionAddPage(),
      '/break': (_) => BreakPage(coord: getLocation(context)),
      '/overwork': (_) =>
          OverWorkPage(camera: camera, coord: getLocation(context)),
      '/overwork_end': (_) =>
          OverWorkEndPage(camera: camera, coord: getLocation(context)),
      '/breakend': (_) =>
          BreakEndPage(camera: camera, coord: getLocation(context)),
      '/leave': (_) => LeavePage(),
      '/leaveapply': (_) => LeaveApplyPage(),
      '/login': (_) => LoginPage(),
      '/calendar': (_) => CalendarPage(),
      '/permission': (_) => PermissionPage(),
      '/short_permission': (_) => ShortPermissionPage(),
      '/long_permission': (_) => LongPermissionPage(),
      '/permission_success': (_) => PermissionSuccessPage(),
      '/signin': (_) => SignInPage(camera: camera, coord: getLocation(context)),
      '/signout': (_) =>
          SignOutPage(camera: camera, coord: getLocation(context)),
      '/permission_handle': (_) => PermissionHandlePage(
        createdAt: "",
        duration: 0,
        start: "",
        end: "",
        jamMasuk: "",
        jamKeluar: "",
        catatan: "",
        requestIzinId: "",
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      routes: createRoute(context),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
