import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/size_config.dart';
import 'add_bottle_form.dart';
import 'edit_bottle_form.dart';

class BottlesCard extends StatefulWidget {
  final double cardFontSize;
  final double cardIconSize;
  final String selectedBebe;
  const BottlesCard({required this.cardFontSize, required this.cardIconSize, required this.selectedBebe, super.key});

  @override
  State<BottlesCard> createState() => _BottlesCardState();
}

class _BottlesCardState extends State<BottlesCard> {
  Stream<QuerySnapshot> _lastFiveStream() {
    if (widget.selectedBebe.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('Babies')
        .doc(widget.selectedBebe)
        .collection('Bottles')
        .orderBy('startedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Stream<QuerySnapshot> _todayStream() {
    if (widget.selectedBebe.isEmpty) return const Stream.empty();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startNextDay = startOfDay.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('Babies')
        .doc(widget.selectedBebe)
        .collection('Bottles')
        .where('startedAt', isGreaterThanOrEqualTo: startOfDay)
        .where('startedAt', isLessThan: startNextDay)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _lastFiveStream(),
      builder: (context, lastFiveSnapshot) {
        final List<Map<String, dynamic>> lastFiveBottles = lastFiveSnapshot.hasData
            ? lastFiveSnapshot.data!.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList()
            : <Map<String, dynamic>>[];

        return StreamBuilder<QuerySnapshot>(
          stream: _todayStream(),
          builder: (context, todaySnapshot) {
            int totalJournalier = 0;
            if (todaySnapshot.hasData && todaySnapshot.data!.docs.isNotEmpty) {
              totalJournalier = todaySnapshot.data!.docs.fold<int>(0, (acc, doc) {
                final data = doc.data() as Map<String, dynamic>?;
                final q = data != null ? (data['quantity'] ?? 0) as int : 0;
                return acc + q;
              });
            }

            return Card(
              color: Colors.blue.shade50,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade200,
                          child: Text('🍼', style: TextStyle(fontSize: widget.cardIconSize * 0.9)),
                        ),
                        SizedBox(width: SizeConfig.text(context, 0.025)),
                        Text('Last bottles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.cardFontSize)),
                        const Spacer(),
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Center(
                            child: IconButton(
                              icon: Icon(Icons.add, color: Colors.white, size: widget.cardIconSize * 0.9),
                              tooltip: 'Add a bottle',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (ctx) => AddBottleForm(selectedBebe: widget.selectedBebe),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.vertical(context, 0.02)),
                    for (int i = 0; i < lastFiveBottles.length; i++) ...[
                      InkWell(
                        onTap: () {
                          final bottle = lastFiveBottles[i];
                          final date = bottle["startedAt"];
                          DateTime dt = date is DateTime ? date : (date != null && date.runtimeType.toString().contains('Timestamp') ? (date as dynamic).toDate() : DateTime.now());
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => EditBottleForm(
                              bottleId: bottle['id'],
                              initialQuantity: bottle['quantity'],
                              initialHour: dt.hour,
                              initialMinute: dt.minute,
                              selectedBebe: widget.selectedBebe,
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Text(_formatDate(lastFiveBottles[i]["startedAt"]), style: TextStyle(fontSize: widget.cardFontSize)),
                            SizedBox(width: SizeConfig.text(context, 0.04)),
                            Text('${lastFiveBottles[i]["quantity"] ?? 0} ml', style: TextStyle(fontSize: widget.cardFontSize)),
                          ],
                        ),
                      ),
                      if (i != lastFiveBottles.length - 1) const Divider(),
                    ],
                    SizedBox(height: SizeConfig.vertical(context, 0.02)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daily total:', style: TextStyle(fontSize: widget.cardFontSize, fontWeight: FontWeight.bold)),
                        Text('$totalJournalier ml', style: TextStyle(fontSize: widget.cardFontSize, color: Colors.blue)),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    try {
      if (date.runtimeType.toString().contains('Timestamp')) {
        final dt = (date as dynamic).toDate();
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return date.toString();
  }
}
