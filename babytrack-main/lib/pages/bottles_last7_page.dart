import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Page affichant tous les biberons des 7 derniers jours.
class BottlesLast7Page extends StatelessWidget {
  const BottlesLast7Page({Key? key}) : super(key: key);

  Future<List<QueryDocumentSnapshot>> _fetchLast7() async {
    final now = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)));
    final end = Timestamp.fromDate(DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));

    final qs = await FirebaseFirestore.instance
        .collection('Biberon')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .orderBy('date', descending: true)
        .get();

    return qs.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biberons - 7 derniers jours'),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchLast7(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun biberon trouvé pour les 7 derniers jours.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final ts = data['date'] as Timestamp?;
              final date = ts != null ? ts.toDate() : null;
              final qty = (data['quantity'] ?? 0).toString();
              final note = (data['note'] ?? '').toString();

              return ListTile(
                title: Text('$qty ml', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: date != null ? Text(DateFormat('dd/MM/yyyy HH:mm').format(date)) : null,
                trailing: note.isNotEmpty ? const Icon(Icons.note) : null,
              );
            },
          );
        },
      ),
    );
  }
}

