import 'dart:io';

void main() {
  final file = File('lib/providers/global_state.dart');
  String content = file.readAsStringSync();

  if (!content.contains('typedef ServerTimeInfo')) {
    content = content.replaceFirst(
      'typedef Csh = ({bool allowed});\n',
      'typedef Csh = ({bool allowed});\ntypedef ServerTimeInfo = ({String? serverTime, int? upTime});\n'
    );
  }

  content = content.replaceFirst(
    'XPresence presence,\n  List<Map<String, dynamic>> offlineEntries,\n});',
    'XPresence presence,\n  List<Map<String, dynamic>> offlineEntries,\n  ServerTimeInfo serverTimeInfo,\n});'
  );

  content = content.replaceFirst(
    'presence:(ci:"00:00",co:"00:00"),\n        offlineEntries: []\n      ));',
    'presence:(ci:"00:00",co:"00:00"),\n        offlineEntries: [],\n        serverTimeInfo: (serverTime: null, upTime: null)\n      ));'
  );

  // Replace all instances of closing the state = ( ... ) EXCEPT the one we just did.
  // We can look for `offlineEntries: (something)` followed by `\n    );`
  final regExp = RegExp(r'(offlineEntries: [^\n]*)(\n\s*\);)');
  content = content.replaceAllMapped(regExp, (match) {
    return '${match.group(1)},\n      serverTimeInfo: state.serverTimeInfo${match.group(2)}';
  });

  content = content.replaceFirst(
    "final offlineEntriesJson = json['offlineEntries'] as List? ?? [];\n",
    "final offlineEntriesJson = json['offlineEntries'] as List? ?? [];\n    final serverTimeInfoJson = json['serverTimeInfo'] ?? {};\n"
  );

  content = content.replaceFirst(
    'offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),\n    );',
    "offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),\n      serverTimeInfo: (\n        serverTime: serverTimeInfoJson['serverTime'] as String?,\n        upTime: serverTimeInfoJson['upTime'] as int?,\n      ),\n    );"
  );

  content = content.replaceFirst(
    "'offlineEntries': state.offlineEntries,\n    };",
    "'offlineEntries': state.offlineEntries,\n      'serverTimeInfo': {\n        'serverTime': state.serverTimeInfo.serverTime,\n        'upTime': state.serverTimeInfo.upTime,\n      },\n    };"
  );
  
  final setter = '''
  setServerTime(String? serverTime, int? upTime) {
    state = (
      auth: state.auth,
      status: state.status,
      company: state.company,
      schedule: state.schedule,
      location: state.location,
      position: state.position,
      other: state.other,
      history: state.history,
      permission: state.permission,
      coordinate: state.coordinate,
      holiday: state.holiday,
      breakInfo: state.breakInfo,
      overWork: state.overWork,
      config: state.config,
      task: state.task,
      exception: state.exception,
      csh: state.csh,
      reminder: state.reminder,
      presence: state.presence,
      offlineEntries: state.offlineEntries,
      serverTimeInfo: (serverTime: serverTime, upTime: upTime),
    );
  }

  @override
  GlobalState? fromJson''';

  content = content.replaceFirst('  @override\n  GlobalState? fromJson', setter);

  file.writeAsStringSync(content);
  print('Done modifying global_state.dart');
}
