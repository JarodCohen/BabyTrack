import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_baby_page.dart';

class StatisticsPage extends StatelessWidget {
  final String selectedBaby;
  final ValueChanged<String>? onBabyAdded;

  const StatisticsPage({super.key, this.selectedBaby = '', this.onBabyAdded});

  // Gets HistoryLogs stats for the last 7 days for the selected baby
  Future<Map<String, dynamic>> _getHistoryLast7Days() async {
    if (selectedBaby.isEmpty) {
      return {
        'days': <Map<String, dynamic>>[],
        'totalQuantity': 0,
        'totalCount': 0,
        'averagePerBottle': 0.0,
      };
    }

    final now = DateTime.now();
    int totalQuantity = 0;
    int totalCount = 0;
    final List<Map<String, dynamic>> days = [];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dateKey = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('Babies')
            .doc(selectedBaby)
            .collection('HistoryLogs')
            .doc(dateKey)
            .get();

        final data = doc.data();
        final int dayTotalMl = (data != null && data['bottlesTotalQuantity'] != null) ? (data['bottlesTotalQuantity'] as num).toInt() : 0;
        final int dayCount = (data != null && data['bottlesCount'] != null) ? (data['bottlesCount'] as num).toInt() : 0;
        final int poops = (data != null && data['poopsCount'] != null) ? (data['poopsCount'] as num).toInt() : 0;
        final int vitaminsCount = (data != null && data['vitaminsCount'] != null) ? (data['vitaminsCount'] as num).toInt() : 0;

        totalQuantity += dayTotalMl;
        totalCount += dayCount;

        days.add({
          'date': day,
          'totalMl': dayTotalMl,
          'bottlesCount': dayCount,
          'poopsCount': poops,
          'vitamins': vitaminsCount > 0,
        });
      } catch (e) {
        // On error, consider the day as empty
        days.add({
          'date': day,
          'totalMl': 0,
          'bottlesCount': 0,
          'poopsCount': 0,
          'vitamins': false,
        });
      }
    }

    final averagePerBottle = totalCount > 0 ? totalQuantity / totalCount : 0.0;

    return {
      'days': days,
      'totalQuantity': totalQuantity,
      'totalCount': totalCount,
      'averagePerBottle': averagePerBottle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double cardFontSize = 18;
    if (selectedBaby.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No baby selected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Select or create a baby to view statistics.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: () async {
                final newId = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const AddBabyPage()));
                if (newId != null && newId.isNotEmpty) onBabyAdded?.call(newId);
              }, icon: const Icon(Icons.add), label: const Text('Add a baby'))
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getHistoryLast7Days(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No data for the last 7 days.'));
                }

                final data = snapshot.data!;
                final double avgPerBottle = (data['averagePerBottle'] as double);
                final int totalQty = (data['totalQuantity'] as int);
                final int totalCount = (data['totalCount'] as int);
                final List<Map<String, dynamic>> days = List<Map<String, dynamic>>.from(data['days'] as List);

                return Column(
                  children: [
                    // Summary card (single line)
                    Card(
                      color: Colors.green.shade50,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.bar_chart, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Avg per bottle (7d): ',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: '${avgPerBottle.toStringAsFixed(1)} ml',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                    ),
                                    TextSpan(
                                      text: '  —  Total: $totalQty ml • $totalCount bottles',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 7 days history card
                    Card(
                      color: Colors.blue.shade50,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('History - 7 days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: cardFontSize)),
                            const SizedBox(height: 12),
                            Column(
                              children: List.generate(days.length, (i) {
                                final day = days[i]['date'] as DateTime;
                                final formattedDate = DateFormat('MM/dd').format(day);
                                final int totalMl = days[i]['totalMl'] as int;
                                final int bottlesCount = days[i]['bottlesCount'] as int;
                                final int poopsCount = days[i]['poopsCount'] as int;
                                final bool vitamins = days[i]['vitamins'] as bool;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Line 1: date • ml • bottle count
                                      Row(
                                        children: [
                                          Text(formattedDate, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                          const Spacer(),
                                          Text('$totalMl ml', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 8),
                                          Text('$bottlesCount bottles', style: TextStyle(fontSize: 24, color: Colors.grey.shade800)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      // Line 2: poop count + vitamin check
                                      Row(
                                        children: [
                                          Text('Poops: $poopsCount', style: TextStyle(fontSize: 20, color: Colors.brown.shade700, fontWeight: FontWeight.w600)),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              const Text('Vitamin: ', style: TextStyle(fontSize: 20)),
                                              Icon(vitamins ? Icons.check_circle : Icons.cancel, size: 20, color: vitamins ? Colors.green : Colors.grey),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
