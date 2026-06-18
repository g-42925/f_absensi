import re

with open('lib/providers/global_state.dart', 'r') as f:
    content = f.read()

# Make sure offlineEntries exists
if 'offlineEntries' not in content:
    content = content.replace(
        'XPresence presence\n});',
        'XPresence presence,\n  List<Map<String, dynamic>> offlineEntries,\n});'
    )
    content = content.replace(
        'presence:(ci:"00:00",co:"00:00")\n      ));',
        'presence:(ci:"00:00",co:"00:00"),\n        offlineEntries: []\n      ));'
    )
    content = re.sub(
        r'(presence:[^\n]*)(\n\s*\);)',
        r'\1,\n      offlineEntries: state.offlineEntries\2',
        content
    )
    
    content = content.replace(
        "final presenceJson = json['presence'] ?? {};",
        "final presenceJson = json['presence'] ?? {};\n    final offlineEntriesJson = json['offlineEntries'] as List? ?? [];"
    )
    
    content = content.replace(
        "co:presenceJson['co'] as String,\n      )",
        "co:presenceJson['co'] as String,\n      ),\n      offlineEntries: offlineEntriesJson.map((e) => Map<String, dynamic>.from(e)).toList(),"
    )
    
    content = content.replace(
        "'presence':{'ci':state.presence.ci,'co':state.presence.co}\n    };",
        "'presence':{'ci':state.presence.ci,'co':state.presence.co},\n      'offlineEntries': state.offlineEntries,\n    };"
    )

    methods = """
  addOfflineEntry(String type, String date) {
    final newEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'date': date,
    };
    final newEntries = [...state.offlineEntries, newEntry];

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
      offlineEntries: newEntries,
    );
  }

  updateOfflineEntryPhoto(String id, String captureTime) {
    final updatedEntries = state.offlineEntries.map((e) {
      if (e['id'] == id) {
        return {
          ...e,
          'captureTime': captureTime,
        };
      }
      return e;
    }).toList();

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
      offlineEntries: updatedEntries,
    );
  }

  @override
  GlobalState? fromJson"""
  
    content = content.replace('  @override\n  GlobalState? fromJson', methods)

    with open('lib/providers/global_state.dart', 'w') as f:
        f.write(content)

