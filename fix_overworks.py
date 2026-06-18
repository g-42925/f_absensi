import re
import os

files = ["/home/muhammad/f_absensi/lib/pages/overwork_start.dart", "/home/muhammad/f_absensi/lib/pages/overwork_end.dart"]

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    if "package:shared_preferences" not in content:
        content = re.sub(r"(import 'package:geolocator/geolocator.dart';)", 
                         r"\1\nimport 'package:shared_preferences/shared_preferences.dart';", 
                         content)

    if "_cameraDisclosureAccepted" not in content:
        content = re.sub(r"(bool isSuspicious = false;)",
                         r"\1\n  bool _cameraDisclosureAccepted = false;\n  bool _locationDisclosureAccepted = false;",
                         content)

    new_check_permissions = """
  Future<bool> showDisclosureDialog({required String title, required String message, required IconData icon, required VoidCallback onConfirm,required VoidCallback onDenied}) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDenied();
            },
            child: const Text("TUTUP", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("SETUJU & LANJUT"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> checkPermissions() async {
    LocationPermission locPermission = await Geolocator.checkPermission();
    if (locPermission == LocationPermission.denied) {
      await showDisclosureDialog(
        title: "Izin Lokasi",
        message: "Aplikasi ini membutuhkan akses lokasi untuk memverifikasi kehadiran Anda di area kantor.",
        icon: Icons.location_on,
        onConfirm: () async {
          await Geolocator.requestPermission();
          ref.invalidate(locationProvider);
        },
        onDenied: () {
        },
      );
    }

    final prefs = await SharedPreferences.getInstance();
    bool cameraDisclosed = prefs.getBool('camera_disclosed') ?? false;
    if (!cameraDisclosed) {
      await showDisclosureDialog(
        title: "Izin Kamera",
        message: "Aplikasi ini membutuhkan akses kamera untuk fitur verifikasi wajah saat melakukan absensi.",
        icon: Icons.camera_alt,
        onConfirm: () async {
          await prefs.setBool('camera_disclosed', true);
          setState(() {
            _cameraDisclosureAccepted = true;
          });
        },
        onDenied: () {
          setState(() {
            _cameraDisclosureAccepted = true;
          });
        }
      );
    } else {
      setState(() {
        _cameraDisclosureAccepted = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkPermissions();
    });
"""

    if "checkPermissions()" not in content:
        # replace initState
        content = re.sub(r"  @override\n  void initState\(\) \{.*?\n  \}", new_check_permissions, content, flags=re.DOTALL)
        
    # the original initState had controller initialization. We must move it to build!
    with open(filepath, 'w') as f:
        f.write(content)
