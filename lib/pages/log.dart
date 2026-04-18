import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/global_state.dart';
import '../env/env.dart';

class  LogPage extends ConsumerStatefulWidget{
  const LogPage({super.key});

  @override
  ConsumerState<LogPage> createState() => _LogPageState();
}

class _LogPageState extends ConsumerState<LogPage>{
  late Future<http.Response>? log;
  
  Future<http.Response> getLog() async {
    final globalState = ref.read(globalStateProvider);
    final other = globalState.other;
    Uri url = Uri.parse("${Env.api}/api/mobile/log/${other.pegawaiId}");

    try {
      return await http.get(url).timeout(const Duration(seconds: 30));
    } 
    on TimeoutException catch(err) {
      throw Error();
    }
    catch (err) {
      throw Error();
    }
  }

  Future<void> fetch() async {
    setState(() {
      log = null;
    });
    setState(() {
      log = getLog();
    });
  }

  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override Widget build(BuildContext ctx){
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: fetch,
        child: const Icon(Icons.refresh),
      ),
      body:SafeArea(
				child:SingleChildScrollView(
					child:Padding(
						padding: EdgeInsets.all(16.0),
						child:FutureBuilder(
							future:log,
							builder:(context,snapshot){
								if(snapshot.connectionState == ConnectionState.waiting) {
									return Center(child: CircularProgressIndicator());
								} 
								if (snapshot.hasError) {
									WidgetsBinding.instance.addPostFrameCallback((_) {
										showModalBottomSheet(
											context: context,
											backgroundColor: Colors.transparent,
											builder: (_) => Container(
												margin: EdgeInsets.all(16),
												padding: EdgeInsets.all(16),
												decoration: BoxDecoration(
													color: Colors.red,
													borderRadius: BorderRadius.circular(12),
												),
												child: Row(
													children: [
														Icon(Icons.error, color: Colors.white),
														SizedBox(width: 10),
														Expanded(
															child: Text(
																"Request timeout or something went wrong",
																style: TextStyle(color: Colors.white),
															),
														),
													],
												),
											),
										);
									});

									return SizedBox();
								}
								else{
									final response = snapshot.data!;
									final data = jsonDecode(response.body);
									final List list = data['r'];
									final filter = DateFormat('yyyy-MM-dd').format(DateTime.now());
									final filtered = list.where((item) {
										return item['tanggal_absen'] == filter;
									}).toList();

									return Column(
										children:[
											Table(
												border: TableBorder.all(),
												children: [
													TableRow(
														children: [
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Tanggal'),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Jam masuk'),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Jam pulang'),
															)
														]
													),
													...filtered.map((d){
														return TableRow(children: [
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['tanggal_absen']),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['jam_masuk']),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['jam_keluar']),
															),
														]);
													}).toList(),
												],
											),
										  SizedBox(height:10),
											Table(
												border: TableBorder.all(),
												children: [
													TableRow(
														children: [
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Tanggal'),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Jam masuk'),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text('Jam pulang'),
															)
														]
													),
													...data['r'].map((d){
														return TableRow(children: [
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['tanggal_absen']),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['jam_masuk']),
															),
															Padding(
																padding: EdgeInsets.all(8),
																child: Text(d['jam_keluar']),
															),
														]);
													}).toList(),
												],
											)
										]
									);
								}          
							}
						)
				  )
				)
			)
    );
  }
}