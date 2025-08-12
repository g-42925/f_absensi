import 'dart:convert';
import '../models/info.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


class LoginPage extends StatefulWidget{

  const LoginPage({
    super.key
  });

  @override State<LoginPage> createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage>{
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final url = Uri.parse('http://172.24.113.245/lss_absensi/api/mobile/login');

  bool visibility = false;
  bool loading = false;

  setVisible(){
    setState((){
      visibility = !visibility;
    });
  }

  login() async{
    setState((){
      loading = true;
    });

    Map<String,String> credential = {
      'email':emailController.text,
      'pwd':passwordController.text
    };
    

    Map<String,String> headers = {
      'Content-Type':'application/json'
    };

    try{
      print("sebelum request api");

      final response = await http.post(
        url,
        headers:headers,
        body:jsonEncode(credential)
      );

      if(response.statusCode == 200){
        final responseBody = jsonDecode(
          response.body
        );     
        
        final Company company = Company(
          name:responseBody['result']['company']['name'],
          logo:responseBody['result']['company']['logo']
        );

        final Schedule schedule = Schedule(
          start:responseBody['result']['pattern']['jam_masuk'],
          finish:responseBody['result']['pattern']['jam_pulang']
        );

        final List<Location> locations = (responseBody['result']['locations'] as List)
          .map((l){
            return Location(
              lat:l['garis_lintang'],
              lon:l['garis_bujur'],
              address:l['alamat_lokasi'],
              locationName:l['nama_lokasi']
            );
          })
          .toList();

        final Detail detail = Detail(
          pegawai_id:responseBody['result']['pegawai_id'],
          nama_pegawai:responseBody['result']['nama_pegawai'],
          nomor_pegawai:responseBody['result']['nomor_pegawai'],
          email_pegawai:responseBody['result']['email_pegawai'],
          foto_pegawai:responseBody['result']['foto_pegawai'],
          company:company,
          schedule:schedule,
          locations:locations,
        );
        
        Provider.of<Info>(context, listen: false).login(detail);

        Navigator.pushReplacementNamed(
          context, 
          '/feature'
        );

      }
      else{
        print(response.statusCode);
      }
    }
    catch(e){
      print(e);
    }
    finally{
      setState((){
        loading = false;
      });
      
    }
  }



  @override Widget build(BuildContext context){
     return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment:MainAxisAlignment.center,
                  children:[
                    Image.asset(
                      'assets/logo.png', // Ganti dengan path logo-mu
                      height: 80,
                    ),
                    const Text(
                      'workly',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily:'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ) 
                  ]
                ),
                const SizedBox(height: 10),
                const Text(
                  'Online Attendance Application',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login using your company employee account',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Input Email
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),

                // Input Password
                TextField(
                  controller: passwordController,
                  obscureText: visibility ? false : true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon:Icon(visibility ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setVisible(),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Forgot Password
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 10),

                // Tombol Login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => login(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: loading ? CircularProgressIndicator() : Text('Login')
                  ),
                ),

                const SizedBox(height: 20),

                // Belum punya akun
                TextButton(
                  onPressed: () {},
                  child: const Text("Don't have employee account yet?"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
