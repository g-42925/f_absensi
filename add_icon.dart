import 'dart:io';

void main() {
  File file = File('lib/pages/home.dart');
  String content = file.readAsStringSync();

  String target = '''                      },
                    ),
                  ],
                ),
                const SizedBox(height: 0),''';

  if (!content.contains(target)) {
    print("Target string not found!");
  }

  String replacement = '''                      },
                    ),
                    IconLabel(
                      icon: Icons.wifi_off,
                      label: "Mode Offline",
                      onPressed: () {
                        Navigator.pushNamed(context, '/offline');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 0),''';

  content = content.replaceFirst(target, replacement);

  file.writeAsStringSync(content);
}
