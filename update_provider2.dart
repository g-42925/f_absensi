import 'dart:io';

void main() {
  File file = File('lib/providers/global_state.dart');
  String content = file.readAsStringSync();

  String newMethods = '''
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

''';

  content = content.replaceAll('@override\n  GlobalState? fromJson', newMethods + '  @override\n  GlobalState? fromJson');
  
  file.writeAsStringSync(content);
}
