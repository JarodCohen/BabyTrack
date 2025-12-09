import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/size_config.dart';
import 'add_vitamin_form.dart';
import 'edit_vitamin_form.dart';

/// Simple vitamin card showing the last vitamin given
class VitaminsCard extends StatelessWidget {
  final double cardFontSize;
  final double cardIconSize;
  final String selectedBebe;

  const VitaminsCard({
    required this.cardFontSize,
    required this.cardIconSize,
    required this.selectedBebe,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedBebe.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade200,
                child: Text('💊', style: TextStyle(fontSize: cardIconSize * 0.9)),
              ),
              SizedBox(width: SizeConfig.text(context, 0.03)),
              Expanded(
                child: Text(
                  'Aucun bébé sélectionné',
                  style: TextStyle(fontSize: cardFontSize),
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.green.withAlpha(128),
                child: Icon(Icons.add, color: Colors.white, size: cardIconSize * 0.9),
              ),
            ],
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('Babies')
        .doc(selectedBebe)
        .collection('Vitamins')
        .orderBy('at', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String vitaminDate = 'Aucune';
        String vitaminTime = '';
        DocumentSnapshot? vitaminDoc;
        bool isToday = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          vitaminDoc = doc;
          final data = doc.data() as Map<String, dynamic>;
          if (data['at'] != null) {
            final date = data['at'] is DateTime ? data['at'] : (data['at'] as dynamic).toDate();
            vitaminDate = DateFormat('dd/MM/yyyy').format(date);
            vitaminTime = DateFormat('HH:mm').format(date);
            final now = DateTime.now();
            isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          }
        }

        return Card(
          color: isToday ? Colors.green.shade50 : Colors.red.shade50,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isToday ? Colors.green.shade200 : Colors.red.shade200,
                  child: Text('💊', style: TextStyle(fontSize: cardIconSize * 0.9)),
                ),
                SizedBox(width: SizeConfig.text(context, 0.03)),
                Expanded(
                  child: InkWell(
                    onTap: vitaminDoc != null
                        ? () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) => EditVitaminForm(
                                vitaminDoc: vitaminDoc!,
                                selectedBebe: selectedBebe,
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      vitaminDoc != null
                          ? 'Last vitamin on $vitaminDate at $vitaminTime'
                          : 'No vitamin recorded',
                      style: TextStyle(fontSize: cardFontSize),
                    ),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: cardIconSize * 0.9),
                    tooltip: 'Add vitamin',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => AddVitaminForm(selectedBebe: selectedBebe),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
