final locationProvider = FutureProvider<Position>((ref) async {
  // 1. cek GPS
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) throw Exception('GPS is not enabled');
  

  // 2. cek permission
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission(); 

  if (permission == LocationPermission.deniedForever) throw Exception('Location permission denied forever');

  if (permission == LocationPermission.denied) throw Exception('Permission denied');
  
  // 3. retry
  int retry = 0;

  while (retry < 3) {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } 
    catch (e) {
      retry++;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // 4. fallback
  final last = await Geolocator.getLastKnownPosition();

  if (last != null) {
    return last;
  }

  throw Exception('failed to get current location');
});