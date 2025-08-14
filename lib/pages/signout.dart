
import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import '../models/info.dart';
import '../env/env.dart';


class SignOutPage extends StatefulWidget{
  final CameraDescription camera;
  final Future<Map<String,double>> coord;


  const SignOutPage({
    super.key,
    required this.camera,
    required this.coord
  });

  @override State<SignOutPage> createState() => _SignOutPageState();
}

class _SignOutPageState extends State<SignOutPage>{
  
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  
 

  Uri gMapsApiUrl = Uri.parse("https://maps.googleapis.com/maps/api/geocode/json");
  Uri staticMap = Uri.parse("https://maps.googleapis.com/maps/api/staticmap");
  SupabaseClient supabase = Supabase.instance.client;
  GlobalKey _globalKey = GlobalKey();
  bool preview = false;
  String path = '';
  String selectedValue = "0/0";
  
  Map<String,num> goHomeCoordinate = {
    'lat':0,
    'lon':0
  };

  Future<List<DropdownMenuItem<String>>> getLocationList() async{
    final _loc = await widget.coord;

    return [
      DropdownMenuItem<String>(
        value:'same location',
        child:Text('Same location')
      ),
      DropdownMenuItem<String>(
        value:'0/0',
        child:Text('Choose your current location')
      ),
      DropdownMenuItem<String>(
        value:"${_loc['lat']}/${_loc['lon']}",
        child:Text('Custom location')
      )
    ];
  }

  Map<String,String> loc = {
    'subDistrict':'',
    'province':'',
    'country':'',
    'address':''
  };

  num toRad(double v){
    return (v * pi) / 180;
  }

  String getYear(DateTime information){
    return DateFormat('dd/MM/yy').format(information);
  }


  Future<ByteBuffer> captureScreen() async{
    await Future.delayed(Duration(milliseconds: 1000));
    final boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer as ByteBuffer;
  }
  
  void captureAndUpload(String? pegawai_id) async{
    final _c = goHomeCoordinate;

    await _initializeControllerFuture;
    final currentTime = DateTime.now();
    final coord = selectedValue.split('/');
    
    final uri = gMapsApiUrl.replace(
      queryParameters:{
        'latlng':"${_c['lat']},${_c['lon']}",
        'key':'${Env.gMapKey}'
      }
    );


   
    try{
      final img = await _controller.takePicture();
      final requestResponse = await http.get(uri);
      final response = jsonDecode(requestResponse.body);
      final target = response['results'][0];
      final addressComponents = target['address_components'];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final url = Uri.parse("${Env.api}/api/mobile/signout");
      final formattedTime = DateFormat("HH:mm").format(currentTime);
      final headers = {"Content-type":"application/json"};

      loc['address'] = target['formatted_address'];
      loc['subDistrict'] = addressComponents[3]['short_name'];
      loc['province'] = addressComponents[5]['short_name'];
      loc['country'] = addressComponents[6]['long_name'];

      setState((){
        path = img.path!;
        preview = true!;
      });

      final result = await captureScreen();

      await supabase.storage.from('storage').uploadBinary(
        fileName,result.asUint8List()
      );

      final publicUrl = await supabase.storage.from('storage').getPublicUrl(
        fileName
      );

      final params = {
        "jam_keluar":formattedTime,
        "foto_absen_keluar":publicUrl,
        "latitude_keluar":_c['lat'],
        "longitude_keluar":_c['lon'],
        "pegawai_id":pegawai_id
      };

      await http.post(
        url,
        headers:headers,
        body:jsonEncode(
          params
        )
      );

      print("ok");
     
    }
    catch(err){
      print(err);
    }
  }

  Future<num> haversineDistance(Map<String,double> coord) async{
    final _coordinate = await widget.coord; 

    final double lat1 = _coordinate['lat'] ?? 0.0;
    final double lon1 = _coordinate['lon'] ?? 0.0;
    
    final double locationLat = coord['lat'] ?? 0.0;
    final double locationLon = coord['lon'] ?? 0.0;
    
    num dLat = toRad(locationLat - lat1);
    num dLon = toRad(locationLon - lon1);
    num cosinus1 = cos(toRad(lat1));
    num cosinus2 = cos(toRad(locationLat));
      // final result = await captureScreen();
    num cosValue = cosinus1 * cosinus2;
    num sinus1 = pow(sin(dLat / 2), 2);
    num sinus2 = pow(sin(dLon / 2),2);
    num v = sinus1 + (cosValue * sinus2);

    double result = 6371 * (1000 * (2 * asin(sqrt(v))));

    return double.parse(result.toStringAsFixed(2));
  }
  

  @override void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override Widget build(BuildContext context){
    final Detail detail = context.read<Info>().detail;
    final double lat = context.read<Info>().latitude;
    final double lon = context.read<Info>().longitude;

    return Scaffold(
      body:FutureBuilder(
        future:_initializeControllerFuture,
        builder:(context,snapshot){
          if(snapshot.connectionState == ConnectionState.done){
            return FutureBuilder<List<DropdownMenuItem<String>>>(
              future:getLocationList(),
              builder:(context,_snapshot){
                if(_snapshot.connectionState == ConnectionState.done){
                  return preview
                  ?
                  RepaintBoundary(
                    key:_globalKey,
                    child:Stack(
                      children:[
                        Container(
                          height:MediaQuery.of(context).size.height,
                          child:Image.file(File(path))
                        ),
                        Positioned(
                          width: MediaQuery.of(context).size.width,
                          bottom:60,
                          child:Padding(
                            padding:EdgeInsets.all(16),
                            child:Row(
                              children:[
                                Image.network(
                                  staticMap.replace(
                                    queryParameters:{
                                      'center':"${goHomeCoordinate['lat']},${goHomeCoordinate['lon']}",
                                      'size':'100x200',
                                      'zoom':'18',
                                      'key':"${Env.gMapKey}",
                                    }
                                  )
                                  .toString(),
                                  fit:BoxFit.cover
                                ),
                                SizedBox(
                                  width:10
                                ),
                                Expanded(
                                  child:Container(
                                    child:Padding(
                                      padding:EdgeInsets.all(12),
                                      child:Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children:[
                                          Text(
                                            "${loc['subDistrict']}, ${loc['province']}",
                                            style:TextStyle(color:Colors.white,fontSize:15)
                                          ),
                                          Text(
                                            "${loc['address']}",
                                            style:TextStyle(color:Colors.white)
                                          ),
                                          Text(
                                            "${goHomeCoordinate['lat']}",
                                            style:TextStyle(color:Colors.white)
                                          ),
                                          Text(
                                            "${goHomeCoordinate['lon']}",
                                            style:TextStyle(color:Colors.white)
                                          ),
                                          Text(
                                            getYear(DateTime.now()),
                                            style:TextStyle(color:Colors.white)
                                          )
                                        ]
                                      )
                                    ),
                                    decoration:BoxDecoration(
                                      borderRadius:BorderRadius.circular(15),
                                      color:Colors.black.withOpacity(0.5)
                                    )
                                  )
                                )
                              ]
                            )
                          )
                        )
                      ]
                    )
                  )
                  :
                  Stack(
                    children:[
                      Container(
                        height:MediaQuery.of(context).size.height,
                        child:CameraPreview(_controller)
                      ),
                      Positioned(
                        bottom:0,
                        width:MediaQuery.of(context).size.width,
                        child:Padding(
                          padding:EdgeInsets.all(16),
                          child:ElevatedButton.icon(
                            onPressed: () => captureAndUpload(
                              detail.pegawai_id
                            ),
                            icon: const Icon(
                              Icons.login,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Presensi Keluar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red, // hijau tosca
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                              elevation: 0, // tanpa shadow
                            ),
                          )
                        )
                      ),
                      Positioned(
                        bottom:80,
                        width:MediaQuery.of(context).size.width,
                        child:Padding(
                        padding:EdgeInsets.all(0),
                        child:Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          width:double.infinity,                    
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.blue, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child:DropdownButtonHideUnderline(
                            child: Container(
                              margin: EdgeInsets.only(right: 10),
                              child:DropdownButton<String>(
                                value:selectedValue,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                                dropdownColor: Colors.white,
                                items:_snapshot.data,
                                onChanged:(value) async{
                                  if(value == "same location"){
                                    final Map<String,double> coordinate = {
                                      'lat':lat,
                                      'lon':lon
                                     };

                                    if(await haversineDistance(coordinate)>100){
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true, // supaya bisa atur tinggi
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                        builder: (context) {
                                          return FractionallySizedBox(
                                            heightFactor: 0.5, // setengah layar
                                            child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 60,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  const Text(
                                                    'Kamu tidak berada di lokasi yang kamu pilih',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Pilih lokasi yang sesuai',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 16, color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            )
                                          );
                                        }
                                      );
                                    }
                                    else{
                                      setState((){
                                        selectedValue = "same location"!;
                                        goHomeCoordinate['lat'] = lat!;
                                        goHomeCoordinate['lon'] = lon!;
                                      });
                                    }
                                  }
                                  else{
                                    if(value != "0/0"){
                                      setState(() {
                                        selectedValue = value!;
                                        goHomeCoordinate['lat'] = double.parse(value.split('/')[0])!;
                                        goHomeCoordinate['lon'] = double.parse(value.split('/')[1])!;
                                      });
                                    }
                                  }
                                },
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              )
                            )
                          )
                        )
                      )
                    ]
                  );
                }
                else{
                  return const Center(child: CircularProgressIndicator());
                }
              }
            );
          }
          else {
            return const Center(child: CircularProgressIndicator());
          }
        }
      )
    );
  }
}
