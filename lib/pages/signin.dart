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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/info.dart';
import '../env/env.dart';



class SignInPage extends StatefulWidget{
  final CameraDescription camera;
  final Future<Map<String,double>> coord;

  const SignInPage({
    super.key,
    required this.camera,
    required this.coord
  });

  @override State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>{
  double _latitude = 0;
  double _longitude = 0;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  
  String path = '';
  String selectedValue = "0/0";
  String gMapsApiKey = "AIzaSyDeY_0v4-MA7fDR8mf9Ssw6_skjyTFGbE0";
  Uri gMapsApiUrl = Uri.parse("https://maps.googleapis.com/maps/api/geocode/json");
  Uri staticMap = Uri.parse("https://maps.googleapis.com/maps/api/staticmap");
  SupabaseClient supabase = Supabase.instance.client;
  GlobalKey _globalKey = GlobalKey();
  bool preview = false;

  Map<String,String> loc = {
    'subDistrict':'',
    'province':'',
    'country':'',
    'address':''
  };
  

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );

    (() async{
      final l = await widget.coord;
      _latitude = l['lat'] as double;
      _longitude = l['lon'] as double;
    })();

    _initializeControllerFuture = _controller.initialize();
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ByteBuffer> captureScreen() async{
    await Future.delayed(Duration(milliseconds: 1000));
    final boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer as ByteBuffer;
  }

  void captureAndUpload(String? pegawai_id) async{
    final xLocation = await widget.coord;

    await _initializeControllerFuture;
    final currentTime = DateTime.now();
    final coord = selectedValue.split('/');
    
    final uri = gMapsApiUrl.replace(
      queryParameters:{
        'latlng':'${coord[0]},${coord[1]}',
        'key':'$gMapsApiKey'
      }
    );
   
    
    try{
      final sLoc = selectedValue.split('/');
      final img = await _controller.takePicture();
      final requestResponse = await http.get(uri);
      final response = jsonDecode(requestResponse.body);
      final target = response['results'][0];
      final addressComponents = target['address_components'];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final url = Uri.parse("${Env.api}/api/mobile/signin");
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
        "is_status":"hhk",
        "jam_masuk":formattedTime,
        "foto_absen_masuk":publicUrl,
        "point_latitude":xLocation['lat'],
        "point_longitude":xLocation['lon'], 
        "latitude_masuk":sLoc[0],
        "longitude_masuk":sLoc[1],
        "pegawai_id":pegawai_id
      };

      await http.post(
        url,
        headers:headers,
        body:jsonEncode(
          params
        )
      );

      Provider.of<Info>(context, listen: false).signInOrSignOut();
      Provider.of<Info>(context,listen: false).setLocation(
        xLocation['lat'] as double,
        xLocation['lon'] as double
      );
        
      Navigator.pushReplacementNamed(
        context, 
        '/feature'
      );
    }
    catch(err){
      if(selectedValue == "0/0"){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("select location first"),
            duration: Duration(seconds: 2), // durasi munculnya
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // supaya tidak menempel di bawah, melayang
            margin: EdgeInsets.fromLTRB(16,0,16,30), // beri jarak dari pinggir layar
          ),
        );
      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("something went wrong"),
            duration: Duration(seconds: 2), // durasi munculnya
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // supaya tidak menempel di bawah, melayang
            margin: EdgeInsets.fromLTRB(16,0,16,30), // beri jarak dari pinggir layar
          ),
        );
      }
    }
  }

  String getYear(DateTime information){
    return DateFormat('dd/MM/yy').format(information);
  }


  @override Widget build(BuildContext context){
    final Detail detail = context.read<Info>().detail;

    final List<Location> locations = context.read<Info>().detail.locations;

    final coordinate = '${_latitude}/${_longitude}';

    final List<DropdownMenuItem<String>> _locations = locations.map((l){
      return DropdownMenuItem<String>(
        value:'${l.lat}/${l.lon}',
        child:Text(l.locationName),
      );
    })
    .toList();

    _locations.add(DropdownMenuItem<String>(
      value:'0/0',
      child:Text('choose your current location')
    ));

    _locations.add(DropdownMenuItem<String>(
      value:coordinate,
      child:Text("Other location")
    ));

    num toRad(double v){
      return (v * pi) / 180;
    }

    num haversinDistance(Map<String,double> coord){
      final double lat1 = _latitude ?? 0.0;
      final double lon1 = _longitude ?? 0.0;
      final double locationLat = coord['lat'] ?? 0.0;
      final double locationLon = coord['lon'] ?? 0.0;

      num dLat = toRad(locationLat - lat1);
      num dLon = toRad(locationLon - lon1);
      num cosinus1 = cos(toRad(lat1));
      num cosinus2 = cos(toRad(locationLat));
      num cosValue = cosinus1 * cosinus2;
      num sinus1 = pow(sin(dLat / 2), 2);
      num sinus2 = pow(sin(dLon / 2),2);
      num v = sinus1 + (cosValue * sinus2);

      double result = 6371 * (1000 * (2 * asin(sqrt(v))));

      return double.parse(result.toStringAsFixed(2));
    };

    return Scaffold(
      body: FutureBuilder(
        future:_initializeControllerFuture,
        builder:(context,snapshot){
          if (snapshot.connectionState == ConnectionState.done){
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
                                'center':"${selectedValue.split('/')[0]},${selectedValue.split('/')[1]}",
                                'size':'100x200',
                                'zoom':'18',
                                'key':"$gMapsApiKey",
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
                                      selectedValue.split('/')[0],
                                      style:TextStyle(color:Colors.white)
                                    ),
                                    Text(
                                      selectedValue.split('/')[1],
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
            Container(
              child:Column(
                children:[
                  Expanded(
                    child:CameraPreview(_controller),
                  ),
                  Container(
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:selectedValue,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: Colors.white,
                        items: _locations.toList(),
                        onChanged: (value) {
                          final List<String> coords = (value as String).split('/');
                          final Map<String,double> coordinate = {
                            'lat':double.parse(coords[0]),
                            'lon':double.parse(coords[1])
                          };
                          
                          if(haversinDistance(coordinate) > 100){
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, // supaya bisa atur tinggi
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
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
                                  ),
                                );
                              }
                            );
                          }
                          else{
                            setState((){
                              selectedValue = value!;
                            });
                          }
                        }
                      )
                    )
                  ),
                ]
              )
            );
          } 
          else {
            return const Center(child: CircularProgressIndicator());
          }
        }
      ),
      floatingActionButton: preview ? null : Padding(
        padding: const EdgeInsets.only(bottom: 60.0), // geser 30px ke atas
        child: FloatingActionButton(
          onPressed: () =>  captureAndUpload(
            detail.pegawai_id
          ),
          child: const Icon(
            Icons.camera_alt
          ),
        ) 
      )
    );
  }
}