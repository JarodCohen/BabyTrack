import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/size_config.dart';
import 'add_poop_form.dart';
import 'edit_poop_form.dart';

class PoopCard extends StatefulWidget {
  final double cardFontSize;
  final double cardIconSize;
  final String selectedBebe;
  const PoopCard({
    required this.cardFontSize,
    required this.cardIconSize,
    required this.selectedBebe,
    super.key,
  });

  @override
  State<PoopCard> createState() => _PoopCardState();
}

class _PoopCardState extends State<PoopCard> {
  @override
  Widget build(BuildContext context) {
    // Si aucun bébé sélectionné, afficher une carte informative (bouton d'ajout désactivé)
    if (widget.selectedBebe.isEmpty) {
      return Card(
        color: Colors.brown.shade50,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.brown.shade200,
                child: Text('💩', style: TextStyle(fontSize: widget.cardIconSize * 0.9)),
              ),
              SizedBox(width: SizeConfig.text(context, 0.03)),
              Expanded(
                child: Text(
                  'No baby selected',
                  style: TextStyle(fontSize: widget.cardFontSize),
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.brown.withAlpha(128),
                child: Icon(Icons.add, color: Colors.white, size: widget.cardIconSize * 0.9),
              ),
            ],
          ),
        ),
      );
    }

    // Stream sur la sous-collection 'Poops' du document selectedBebe dans 'Babies'
    // On récupère directement le dernier document côté Firestore pour éviter de ramener tous les docs
    final stream = FirebaseFirestore.instance
        .collection('Babies')
        .doc(widget.selectedBebe)
        .collection('Poops')
        .orderBy('at', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String poopDate = 'None';
        String poopTime = '';
        DocumentSnapshot? poopDoc;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          poopDoc = doc;
          final data = doc.data() as Map<String, dynamic>;
          if (data['at'] != null) {
            final date = data['at'] is DateTime ? data['at'] : (data['at'] as dynamic).toDate();
            poopDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            poopTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          }
        }

        return Card(
          color: Colors.brown.shade50,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.brown.shade200,
                  child: Text('💩', style: TextStyle(fontSize: widget.cardIconSize * 0.9)),
                ),
                SizedBox(width: SizeConfig.text(context, 0.03)),
                Expanded(
                  child: InkWell(
                    onTap: poopDoc != null
                        ? () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) => EditPoopForm(poopDoc: poopDoc!, selectedBebe: widget.selectedBebe),
                            );
                          }
                        : null,
                    child: Text(
                      'Last poop on $poopDate at $poopTime',
                      style: TextStyle(fontSize: widget.cardFontSize),
                    ),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.brown,
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: widget.cardIconSize * 0.9),
                    tooltip: 'Add poop',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => AddPoopForm(selectedBebe: widget.selectedBebe),
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
