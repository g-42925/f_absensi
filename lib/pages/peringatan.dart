import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:absensi/providers/global_state.dart';

class PeringatanPage extends ConsumerStatefulWidget {
  const PeringatanPage({super.key});

  @override
  ConsumerState<PeringatanPage> createState() => _PeringatanPageState();
}

class _PeringatanPageState extends ConsumerState<PeringatanPage> {
  @override
  Widget build(BuildContext context) {
    final globalState = ref.watch(globalStateProvider);
    final violations = globalState.violation.list;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surat Peringatan'),
      ),
      body: violations.isEmpty
          ? const Center(child: Text('Tidak ada peringatan.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: violations.length,
              itemBuilder: (context, index) {
                final v = violations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v['sp_number']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                v['level']?.toString() ?? '-',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          v['title']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Pelanggaran: ${v['violation']?.toString() ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('Tanggal: ${v['date']?.toString() ?? '-'}'),
                        const SizedBox(height: 8),
                        Text(
                          'Sanksi: ${v['penalty']?.toString() ?? '-'}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
