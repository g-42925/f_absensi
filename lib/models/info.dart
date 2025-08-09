import 'package:flutter/foundation.dart';

class Info with ChangeNotifier {
  bool loggedIn = false;
  late Company company;
  late Schedule schedule;
  late Detail detail;

  Info(){
    company = Company(
      name:'cradle',logo:''
    );
    schedule = Schedule(
      start:'',finish:'',
    );
    detail = Detail(
      company:company,
      schedule:schedule,
      locations:[]
    );
  }
 
  login(Detail newDetail){
    loggedIn = true;
    detail = newDetail;
    notifyListeners();
  }

  logout(){
    loggedIn = false;
  }
}

class Detail{
  String? pegawai_id;
  String? nama_pegawai;
  String? nomor_pegawai;
  String? email_pegawai;
  String? foto_pegawai;
  Company company;
  Schedule schedule;
  List<Location> locations;

  Detail({
    this.pegawai_id,
    this.nama_pegawai,
    this.nomor_pegawai,
    this.email_pegawai,
    this.foto_pegawai,
    required this.company,
    required this.schedule,
    required this.locations
  });
}

class Company{
  String name;
  String logo;

  Company({
    required this.name,
    required this.logo
  });
}

class Schedule{
  String start;
  String finish;

  Schedule({
    required this.start,
    required this.finish
  });
}

class Location{
  String lat;
  String lon;
  String address;
  String locationName;

  Location({
    required this.lat,
    required this.lon,
    required this.address,
    required this.locationName
  });
}