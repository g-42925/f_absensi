// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env') abstract class Env {
  @EnviedField(varName: 'API') static const String api = _Env.api;
  @EnviedField(varName: 'GMAPKEY') static const String gMapKey = _Env.gMapKey;
}