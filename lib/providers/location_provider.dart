import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

final locationProvider = FutureProvider<Position>((ref) async {
  // 1. cek GPS
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    loc.Location location = loc.Location();
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      throw Exception('GPS is not enabled');
    }
  }

  // 2. cek permission
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission(); 

  if (permission == LocationPermission.deniedForever) throw Exception('Location permission denied forever');

  if (permission == LocationPermission.denied) throw Exception('Permission denied');
  
  // 3. retry
  int retry = 0;

  while (retry < 5) {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
    } 
    catch (e) {
      retry++;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // 4. fallback
  final last = await Geolocator.getLastKnownPosition();

  if (last != null) {
    return last;
  }

  throw Exception('failed to get current location');
});