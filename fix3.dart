import 'dart:io';

void main() {
  final file = File('lib/providers/global_state.dart');
  String content = file.readAsStringSync();

  // Find all `state = (` assignments and insert `serverTimeInfo: state.serverTimeInfo` before `);`
  // except inside setServerTime where it is already handled.
  
  // A safer way is to replace `offlineEntries: something\n    );` with `offlineEntries: something,\n      serverTimeInfo: state.serverTimeInfo\n    );`
  
  final regExp = RegExp(r'(offlineEntries:\s*[^,)\n]+?),?\s*\n(\s*\);)');
  
  content = content.replaceAllMapped(regExp, (match) {
    String inner = match.group(0)!;
    if (inner.contains('serverTimeInfo: (serverTime: serverTime, upTime: upTime)')) {
      return match.group(0)!;
    }
    return '${match.group(1)},\n      serverTimeInfo: state.serverTimeInfo\n${match.group(2)}';
  });
  
  // also handle the initial globalStateProvider assignment
  content = content.replaceFirst(
    'offlineEntries: [],\n      serverTimeInfo: state.serverTimeInfo\n      ));',
    'offlineEntries: [],\n        serverTimeInfo: (serverTime: null, upTime: null)\n      ));'
  );

  // fix fromJson return
  content = content.replaceFirst(
    'offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),\n      serverTimeInfo: state.serverTimeInfo\n    );',
    "offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),\n      serverTimeInfo: (\n        serverTime: serverTimeInfoJson['serverTime'] as String?,\n        upTime: serverTimeInfoJson['upTime'] as int?,\n      ),\n    );"
  );

  file.writeAsStringSync(content);
}
