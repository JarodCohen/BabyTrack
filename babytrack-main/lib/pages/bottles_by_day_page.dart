import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Page affichant les biberons pour un jour donné.
class BottlesByDayPage extends StatelessWidget {
  final DateTime day;

  const BottlesByDayPage({Key? key, required this.day}) : super(key: key);

  Future<List<QueryDocumentSnapshot>> _fetchForDay() async {
    final start = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
    final end = Timestamp.fromDate(DateTime(day.year, day.month, day.day).add(const Duration(days: 1)));

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
    final title = DateFormat('dd/MM/yyyy').format(day);
    return Scaffold(
      appBar: AppBar(
        title: Text('Biberons - $title'),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchForDay(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun biberon pour ce jour.'));
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
                subtitle: date != null ? Text(DateFormat('HH:mm').format(date)) : null,
                trailing: note.isNotEmpty ? const Icon(Icons.note) : null,
              );
            },
          );
        },
      ),
    );
  }
}

