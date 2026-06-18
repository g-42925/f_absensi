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

    content = re.sub(
        r'(XPresence presence,)(\s*List<Map<String, dynamic>> offlineEntries,\n\}\);)',
        r'\1\n  ServerTimeInfo serverTimeInfo,\2',
        content
    )

    content = re.sub(
        r'(presence:\(ci:"00:00",co:"00:00"\),)(\s*offlineEntries: \[\]\n\s*\}\)\);)',
        r'\1\n        serverTimeInfo: (serverTime: null, upTime: null),\2',
        content
    )

    # Add to all `state = (` blocks
    content = re.sub(
        r'(offlineEntries: [^\n]+?)(\n\s*\);)',
        r'\1,\n      serverTimeInfo: state.serverTimeInfo\2',
        content
    )
    
    # fromJson
    content = re.sub(
        r'(final offlineEntriesJson = json\[\'offlineEntries\'\].*?)\n',
        r"\1\n    final serverTimeInfoJson = json['serverTimeInfo'] ?? {};\n",
        content
    )
    
    content = re.sub(
        r'(offlineEntries: offlineEntriesJson.*?)(,)?(\n\s*\);)',
        r"\1,\n      serverTimeInfo: (\n        serverTime: serverTimeInfoJson['serverTime'] as String?,\n        upTime: serverTimeInfoJson['upTime'] as int?,\n      )\3",
        content
    )
    
    # toJson
    content = re.sub(
        r'(\'offlineEntries\': state\.offlineEntries)(,)?(\n\s*\};)',
        r"\1,\n      'serverTimeInfo': {\n        'serverTime': state.serverTimeInfo.serverTime,\n        'upTime': state.serverTimeInfo.upTime,\n      }\3",
        content
    )
    
    # add setter
    setter = """
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
"""
    content = content.replace('  @override\n  GlobalState? fromJson', setter + '\n  @override\n  GlobalState? fromJson')

    with open('lib/providers/global_state.dart', 'w') as f:
        f.write(content)
