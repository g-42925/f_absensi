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
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied forever');
  }

  if (permission == LocationPermission.denied) {
    throw Exception('Permission denied');
  }

  int retry = 0;

  while (retry < 5) {
    try {
      final pst = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
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
      await Future.delayed(const Duration(seconds: 2));
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