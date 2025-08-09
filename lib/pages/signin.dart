import '../models/info.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

class SignInPage extends StatefulWidget{
  final CameraDescription camera;
  final List<CameraDescription> cameras;

  const SignInPage({super.key,required this.camera,required this.cameras});

  @override State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>{
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  String? selectedValue = 'Apel';

  final List<String> fruits = ['Apel', 'Jeruk', 'Mangga', 'Pisang'];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      body: FutureBuilder(
        future:_initializeControllerFuture,
        builder:(context,snapshot){
          if (snapshot.connectionState == ConnectionState.done) {
            return Container(
              child:Column(
                children:[
                  Expanded(
                    child:Container(
                    child:Center(
              child: ClipOval(
                child: SizedBox(
                  width: 350, // diameter lingkaran
                  height: 350,
                  child: CameraPreview(_controller),
                )
              )
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
      )
    );
  }
}