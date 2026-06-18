import 'package:absensi/providers/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OfflineEntryPage extends ConsumerStatefulWidget {
  const OfflineEntryPage({super.key});

  @override
  ConsumerState<OfflineEntryPage> createState() => _OfflineEntryPageState();
}

class _OfflineEntryPageState extends ConsumerState<OfflineEntryPage> {
  String selectedType = 'Sign In';
  final types = ['Sign In', 'Sign Out'];

  void addEntry() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.read(globalStateProvider.notifier).addOfflineEntry(selectedType, date);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry berhasil ditambahkan.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text("Input Absen Offline")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Buat Entry Offline Baru',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipe Entry',
                        border: OutlineInputBorder(),
                      ),
                      items: types.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: today,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                      ),
                      onPressed: addEntry,
                      child: const Text('Simpan Entry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
