import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

final locationProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  
  if (!serviceEnabled) {
    loc.Location location = loc.Location();
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      throw Exception('GPS is not enabled');
    }
  }

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    // Permission is denied. We handle the request with disclosure in the UI.
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied forever');
  }

  if (permission == LocationPermission.denied) {
    throw Exception('Permission denied');
  }

  int retry = 0;

  while (retry < 2) {
    try {
      LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high, // Aktifkan Fused Location
        distanceFilter: 10, // Update posisi jika bergerak minimal 10 meter
        forceLocationManager: false, // Wajib false agar pakai Fused Provider
        intervalDuration: const Duration(seconds: 10), // Interval polling lokasi
        // Fitur khusus Android: Tampilkan notifikasi saat jalan di background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Aplikasi sedang melacak lokasi Anda",
          notificationTitle: "Layanan Lokasi Aktif",
          enableWakeLock: true,
        ),
      ); 

      final pst = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // jangan throw, tapi tandai
      final isSuspicious = pst.isMocked;

      print('suspicious: $isSuspicious');

      // kamu bisa bungkus ke model sendiri nanti
      return {
        'position': pst,
        'isSuspicious': pst.isMocked,
      };

    } 
    catch (_) {
      retry++;
      if (retry < 2) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  final last = await Geolocator.getLastKnownPosition();

  if (last != null && last.timestamp != null && DateTime.now().difference(last.timestamp!) < const Duration(minutes: 2)) {
    return {
      'position': last,
      'isSuspicious': last.isMocked,
    };
  }

  throw Exception('failed to get current location');
});