import 'dart:io';

void main() {
  File file = File('lib/main.dart');
  String content = file.readAsStringSync();

  if (!content.contains("import 'package:absensi/pages/offline.dart';")) {
    content = content.replaceFirst("import 'package:absensi/pages/task_start.dart';", "import 'package:absensi/pages/task_start.dart';\nimport 'package:absensi/pages/offline.dart';");
  }

  if (!content.contains("'/offline': (_) => OfflinePage(),")) {
    content = content.replaceFirst("'/login': (_) => LoginPage(),", "'/login': (_) => LoginPage(),\n      '/offline': (_) => const OfflinePage(),");
  }

  file.writeAsStringSync(content);
}
