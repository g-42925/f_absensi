import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:absensi/env/env.dart';
import 'package:absensi/providers/global_state.dart';

typedef ServerTimeState = ({
  DateTime? serverTime,
  int? upTime,
});

class ServerTimeNotifier extends StateNotifier<ServerTimeState> {
  Timer? _timer;
  static const _channel = MethodChannel('uptime');
  final Ref ref;
  bool _hasHandledFirstFailure = false;

  ServerTimeNotifier(this.ref) : super((serverTime: null, upTime: null)) {
    _startTimer();
  }

  void _startTimer() {
    _fetchTime();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _fetchTime();
    });
  }

  Future<void> _fetchTime() async {
    try {
      final int ms = await _channel.invokeMethod('getUptime');
      final response = await http.get(Uri.parse("${Env.api}/api/mobile/timenow")).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverTime = DateTime.parse(data['dateTime']);
        state = (serverTime: serverTime, upTime: ms);
        ref.read(globalStateProvider.notifier).setServerTime(serverTime.toIso8601String(), ms);
      } 
      else {
        if(!_hasHandledFirstFailure) {
          _hasHandledFirstFailure = true;
          final int ms = await _channel.invokeMethod('getUptime');
          final serverTime = DateTime.now();
          state = (serverTime: serverTime, upTime: ms);
          ref.read(globalStateProvider.notifier).setServerTime(serverTime.toIso8601String(), ms);
        }
      }
    } 
    catch (e) {
      try {
        if (!_hasHandledFirstFailure) {
          _hasHandledFirstFailure = true;

          final int ms = await _channel.invokeMethod('getUptime');
          final serverTime = DateTime.now();

          state = (serverTime: serverTime, upTime: ms);

          ref.read(globalStateProvider.notifier).setServerTime(serverTime.toIso8601String(), ms);
        }
      }
      catch (e2) {
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final serverTimeProvider = StateNotifierProvider<ServerTimeNotifier, ServerTimeState>((ref) {
  return ServerTimeNotifier(ref);
});
