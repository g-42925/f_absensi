import re

with open('lib/providers/global_state.dart', 'r') as f:
    content = f.read()

# Add typedef
if 'typedef ServerTimeInfo' not in content:
    content = re.sub(
        r'(typedef Csh = \(\{bool allowed\}\);)',
        r'\1\ntypedef ServerTimeInfo = ({String? serverTime, int? upTime});',
        content
    )

    # Add to GlobalState
    content = re.sub(
        r'(List<Map<String, dynamic>> offlineEntries,)(\s*\}\);)',
        r'\1\n  ServerTimeInfo serverTimeInfo,\2',
        content
    )

    # Initial value in globalStateProvider
    content = re.sub(
        r'(offlineEntries: \[\])(\s*\}\)\);)',
        r'\1,\n        serverTimeInfo: (serverTime: null, upTime: null)\2',
        content
    )

    # Add serverTimeInfo to all state = (... ) assignments
    content = re.sub(
        r'(offlineEntries: .*?)\n(\s*\);)',
        r'\1,\n      serverTimeInfo: state.serverTimeInfo\n\2',
        content
    )
    
    # Fix the fromJson
    content = re.sub(
        r'(final offlineEntriesJson = json\[\'offlineEntries\'\] as List\? \?\? \[\];)',
        r"\1\n    final serverTimeInfoJson = json['serverTimeInfo'] ?? {};",
        content
    )
    
    content = re.sub(
        r'(offlineEntries: offlineEntriesJson.map\(\(e\) => Map<String, dynamic>.from\(e\)\)\.toList\(\),)(\s*\);)',
        r"\1\n      serverTimeInfo: (\n        serverTime: serverTimeInfoJson['serverTime'] as String?,\n        upTime: serverTimeInfoJson['upTime'] as int?,\n      ),\2",
        content
    )
    
    # Fix toJson
    content = re.sub(
        r'(\'offlineEntries\': state\.offlineEntries,)(\s*\};)',
        r"\1\n      'serverTimeInfo': {\n        'serverTime': state.serverTimeInfo.serverTime,\n        'upTime': state.serverTimeInfo.upTime,\n      },\2",
        content
    )
    
    # Add setServerTime method
    content = re.sub(
        r'(@override\s*GlobalState\? fromJson)',
        r'setServerTime(String? serverTime, int? upTime) {\n    state = (\n      auth: state.auth,\n      status: state.status,\n      company: state.company,\n      schedule: state.schedule,\n      location: state.location,\n      position: state.position,\n      other: state.other,\n      history: state.history,\n      permission: state.permission,\n      coordinate: state.coordinate,\n      holiday: state.holiday,\n      breakInfo: state.breakInfo,\n      overWork: state.overWork,\n      config: state.config,\n      task: state.task,\n      exception: state.exception,\n      csh: state.csh,\n      reminder: state.reminder,\n      presence: state.presence,\n      offlineEntries: state.offlineEntries,\n      serverTimeInfo: (serverTime: serverTime, upTime: upTime),\n    );\n  }\n\n  \1',
        content
    )
    
    with open('lib/providers/global_state.dart', 'w') as f:
        f.write(content)
