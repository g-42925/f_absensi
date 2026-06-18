import 'dart:io';

void main() {
  File file = File('lib/providers/global_state.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll('XPresence presence\n});', 'XPresence presence,\n  List<Map<String, dynamic>> offlineEntries,\n});');
  content = content.replaceAll('presence:(ci:"00:00",co:"00:00")\n      )', 'presence:(ci:"00:00",co:"00:00"),\n        offlineEntries: []\n      )');
  content = content.replaceAll('presence: state.presence\n    )', 'presence: state.presence,\n      offlineEntries: state.offlineEntries\n    )');
  content = content.replaceAll('presence:state.presence\n    )', 'presence: state.presence,\n      offlineEntries: state.offlineEntries\n    )');
  content = content.replaceAll('presence:state.presence,\n    )', 'presence: state.presence,\n      offlineEntries: [],\n    )');
  content = content.replaceAll('presence:(ci:formattedTime,co:state.presence.co)\n    )', 'presence:(ci:formattedTime,co:state.presence.co),\n      offlineEntries: state.offlineEntries\n    )');
  content = content.replaceAll('presence:(ci:state.presence.ci,co:formattedTime)\n\n    )', 'presence:(ci:state.presence.ci,co:formattedTime),\n      offlineEntries: state.offlineEntries\n    )');
  
  // Custom replacements for addException end
  
  content = content.replaceAll("final presenceJson = json['presence'] ?? {};", "final presenceJson = json['presence'] ?? {};\n    final offlineEntriesJson = json['offlineEntries'] as List? ?? [];");
  
  content = content.replaceAll("ci:presenceJson['ci'] as String,\n        co:presenceJson['co'] as String,\n      )\n    );", "ci:presenceJson['ci'] as String,\n        co:presenceJson['co'] as String,\n      ),\n      offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),\n    );");
  
  content = content.replaceAll("'presence':{'ci':state.presence.ci,'co':state.presence.co}\n    };", "'presence':{'ci':state.presence.ci,'co':state.presence.co},\n      'offlineEntries': state.offlineEntries,\n    };");

  file.writeAsStringSync(content);
}
