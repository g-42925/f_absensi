import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationProvider = FutureProvider<Position>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) throw Exception('GPS is not enabled');

  LocationPermission permission = await Geolocator.checkPermission();

  if (!serviceEnabled) throw Exception('GPS is not enabled');
  
  if (permission == LocationPermission.denied) {
    throw Exception('Permission denied');
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied forever');
  }

  int retry = 0;

  while (retry < 3) {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      retry++;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  final last = await Geolocator.getLastKnownPosition();

  if (last != null) {
    return last;
  }

  throw Exception('failed to get current location');
});
