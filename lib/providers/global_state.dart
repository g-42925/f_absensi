import 'package:hydrated_riverpod/hydrated_riverpod.dart';
import 'package:intl/intl.dart';

// typedef GlobalState = Map<String, Map<String, dynamic>>;

typedef Break = ({bool onBreak, String startFrom});
typedef Holiday = ({bool holiday, bool workDay});
typedef Auth = ({bool loggedIn, String date});
typedef Status = ({bool signedIn, bool signedOut});
typedef OverWork = ({bool onOverWork});

typedef Company = ({
  String id,
  String name,
  String logo,
  String address,
  int salaryDate,
});

typedef Schedule = ({
  String start,
  String finish,
  String breakStart,
  String breakFinish,
  String workSystem,
  String workSystemName,
});

typedef Location = ({List<Map<String, dynamic>> list});
typedef DEVICEPST = ({double lat, double lon});
typedef Coordinate = ({double lat, double lon});
typedef Permission = ({int id});

typedef Other = ({
  String pegawaiId,
  String namaPegawai,
  String nomorPegawai,
  String emailPegawai,
  String fotoPegawai,
  String position,
  String status,
});

typedef GlobalState = ({
  Auth auth,
  Status status,
  Company company,
  Schedule schedule,
  Location location,
  DEVICEPST position,
  List<String> history,
  Other other,
  Permission permission,
  Coordinate coordinate,
  Holiday holiday,
  Break breakInfo,
  OverWork overWork,
});

final globalStateProvider =
    StateNotifierProvider<GlobalStateProvider, GlobalState>((ref) {
      return GlobalStateProvider((
        history: [],
        permission: (id: 0),
        auth: (loggedIn: false, date: ''),
        status: (signedIn: false, signedOut: false),
        company: (id: '', name: '', logo: '', address: '', salaryDate: 0),
        schedule: (
          start: '',
          finish: '',
          breakStart: '',
          breakFinish: '',
          workSystem: '',
          workSystemName: '',
        ),
        location: (list: []),
        position: (lat: 0, lon: 0),
        coordinate: (lat: 0, lon: 0),
        other: (
          pegawaiId: '',
          namaPegawai: '',
          nomorPegawai: '',
          emailPegawai: '',
          fotoPegawai: '',
          position: '',
          status: '',
        ),
        holiday: (holiday: false, workDay: true),
        breakInfo: (onBreak: false, startFrom: ''),
        overWork: (onOverWork: false),
      ));
    });

class GlobalStateProvider extends HydratedStateNotifier<GlobalState> {
  GlobalStateProvider(super.state);

  login(GlobalState param) {
    state = param;
  }

  addHistory(String id) {
    final newHistory = [...state.history, id];

    state = (
      auth: state.auth,
      status: state.status,
      company: state.company,
      schedule: state.schedule,
      location: state.location,
      position: state.position,
      other: state.other,
      history: newHistory,
      permission: state.permission,
      coordinate: state.coordinate,
      holiday: state.holiday,
      breakInfo: state.breakInfo,
      overWork: state.overWork,
    );
  }

  logout() {
    state = (
      auth: (loggedIn: false, date: ''),
      status: (signedIn: false, signedOut: false),
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
    );
  }

  setPosition(double lat, double lon) {
    state = (
      auth: state.auth,
      status: state.status,
      company: state.company,
      schedule: state.schedule,
      location: state.location,
      position: (lat: lat, lon: lon),
      other: state.other,
      history: state.history,
      permission: state.permission,
      coordinate: state.coordinate,
      holiday: state.holiday,
      breakInfo: state.breakInfo,
      overWork: state.overWork,
    );
  }

  setCoordinate(double lat, double lon) {
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
      coordinate: (lat: lat, lon: lon),
      holiday: state.holiday,
      breakInfo: state.breakInfo,
      overWork: state.overWork,
    );
  }

  signIn() {
    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: false),
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
    );
  }

  signOut() {
    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: true),
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
    );
  }

  breakStart() {
    DateTime now = DateTime.now();
    String from = DateFormat('HH:mm').format(now);

    final Break breakInfo = (onBreak: true, startFrom: from);

    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: false),
      company: state.company,
      schedule: state.schedule,
      location: state.location,
      position: state.position,
      other: state.other,
      history: state.history,
      permission: state.permission,
      coordinate: state.coordinate,
      holiday: state.holiday,
      breakInfo: breakInfo,
      overWork: state.overWork,
    );
  }

  overWorkStart() {
    final OverWork overWork = (onOverWork: true);

    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: true),
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
      overWork: overWork,
    );
  }

  overWorkEnd() {
    final OverWork overWork = (onOverWork: false);

    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: true),
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
      overWork: overWork,
    );
  }

  breakEnd() {
    final from = state.breakInfo.startFrom;
    final Break breakInfo = (onBreak: false, startFrom: from);
    state = (
      auth: state.auth,
      status: (signedIn: true, signedOut: false),
      company: state.company,
      schedule: state.schedule,
      location: state.location,
      position: state.position,
      other: state.other,
      history: state.history,
      permission: state.permission,
      coordinate: state.coordinate,
      holiday: state.holiday,
      breakInfo: breakInfo,
      overWork: state.overWork,
    );
  }

  @override
  GlobalState? fromJson(Map<String, dynamic> json) {
    final authJson = json['auth'] ?? {};
    final statusJson = json['status'] ?? {};
    final companyJson = json['company'] ?? {};
    final scheduleJson = json['schedule'] ?? {};
    final locationJson = json['location'] ?? {};
    final positionJson = json['position'] ?? {};
    final coordinateJson = json['coordinate'] ?? {};
    final otherJson = json['other'] ?? {};
    final permissionJson = json['permission'] ?? {};
    final locationList = locationJson['list'] as List;
    final holidayJson = json['holiday'] ?? {};
    final breakInfoJson = json['breakInfo'] ?? {};
    final overWorkJson = json['overWork'] ?? {};

    return (
      auth: (
        loggedIn: authJson['loggedIn'] as bool,
        date: authJson['date'] as String,
      ),
      status: (
        signedIn: statusJson['signedIn'] as bool,
        signedOut: statusJson['signedOut'] as bool,
      ),
      company: (
        id: companyJson['id'] as String,
        name: companyJson['name'] as String,
        logo: companyJson['logo'] as String,
        address: companyJson['address'] as String,
        salaryDate: companyJson['salaryDate'] as int,
      ),
      schedule: (
        start: scheduleJson['start'] as String,
        finish: scheduleJson['finish'] as String,
        breakStart: scheduleJson['breakStart'] as String,
        breakFinish: scheduleJson['breakFinish'] as String,
        workSystem: scheduleJson['workSystem'] as String,
        workSystemName: scheduleJson['workSystemName'] as String,
      ),
      location: (
        list: locationList.map((e) => Map<String, dynamic>.from(e)).toList(),
      ),
      position: (
        lat: (positionJson['lat'] as num).toDouble(),
        lon: (positionJson['lon'] as num).toDouble(),
      ),
      coordinate: (
        lat: (coordinateJson['lat'] as num).toDouble(),
        lon: (coordinateJson['lon'] as num).toDouble(),
      ),
      other: (
        pegawaiId: otherJson['pegawaiId'] as String,
        namaPegawai: otherJson['namaPegawai'] as String,
        nomorPegawai: otherJson['nomorPegawai'] as String,
        emailPegawai: otherJson['emailPegawai'] as String,
        fotoPegawai: otherJson['fotoPegawai'] as String,
        position: otherJson['position'] as String,
        status: otherJson['status'] as String,
      ),
      permission: (id: permissionJson['id'] as int),
      history: [
        // action history
      ],
      holiday: (
        holiday: holidayJson['holiday'] as bool,
        workDay: holidayJson['workDay'] as bool,
      ),
      breakInfo: (
        onBreak: breakInfoJson['onBreak'] as bool,
        startFrom: breakInfoJson['startFrom'] as String,
      ),
      overWork: (onOverWork: overWorkJson['onOverWork'] as bool),
    );
  }

  @override
  Map<String, dynamic>? toJson(GlobalState state) {
    return {
      'auth': {'loggedIn': state.auth.loggedIn, 'date': state.auth.date},
      'status': {
        'signedIn': state.status.signedIn,
        'signedOut': state.status.signedOut,
      },
      'company': {
        'id': state.company.id,
        'name': state.company.name,
        'logo': state.company.logo,
        'address': state.company.address,
        'salaryDate': state.company.salaryDate,
      },
      'schedule': {
        'start': state.schedule.start,
        'finish': state.schedule.finish,
        'breakStart': state.schedule.breakStart,
        'breakFinish': state.schedule.breakFinish,
        'workSystem': state.schedule.workSystem,
        'workSystemName': state.schedule.workSystemName,
      },
      'location': {'list': state.location.list},
      'position': {'lat': state.position.lat, 'lon': state.position.lon},
      'coordinate': {'lat': state.coordinate.lat, 'lon': state.coordinate.lon},

      'other': {
        'pegawaiId': state.other.pegawaiId,
        'namaPegawai': state.other.namaPegawai,
        'nomorPegawai': state.other.nomorPegawai,
        'emailPegawai': state.other.emailPegawai,
        'fotoPegawai': state.other.fotoPegawai,
        'position': state.other.position,
        'status': state.other.status,
      },
      'permission': {'id': state.permission.id},
      'holiday': {
        'holiday': state.holiday.holiday,
        'workDay': state.holiday.workDay,
      },
      'breakInfo': {
        'onBreak': state.breakInfo.onBreak,
        'startFrom': state.breakInfo.startFrom,
      },
      'overWork': {'onOverWork': state.overWork.onOverWork},
    };
  }
}
