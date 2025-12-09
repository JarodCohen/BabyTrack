import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cyclic_hour_minute_picker.dart';

class EditPoopForm extends StatefulWidget {
  final DocumentSnapshot poopDoc;
  final String selectedBebe;
  const EditPoopForm({required this.poopDoc, required this.selectedBebe, super.key});

  @override
  State<EditPoopForm> createState() => _EditPoopFormState();
}

class _EditPoopFormState extends State<EditPoopForm> {
  late int _selectedHour;
  late int _selectedMinute;
  late DateTime _selectedDate;
  String? _notes;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    // Lire le timestamp 'at' (peut être Timestamp ou DateTime)
    final rawAt = widget.poopDoc.get('at');
    final atDate = rawAt is Timestamp ? rawAt.toDate() : (rawAt as DateTime);
    _selectedDate = DateTime(atDate.year, atDate.month, atDate.day);
    _selectedHour = atDate.hour;
    _selectedMinute = atDate.minute;
    _notes = widget.poopDoc.get('notes') as String?;
    _notesController = TextEditingController(text: _notes ?? '');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onHourChanged(int newHour) {
    if (_selectedHour == 23 && newHour == 0) {
      setState(() {
        _selectedHour = newHour;
        _selectedDate = _selectedDate.add(Duration(days: 1));
      });
    } else if (_selectedHour == 0 && newHour == 23) {
      setState(() {
        _selectedHour = newHour;
        _selectedDate = _selectedDate.subtract(Duration(days: 1));
      });
    } else {
      setState(() {
        _selectedHour = newHour;
      });
    }
  }

  // Retourne la référence vers la sous-collection Poops du bébé sélectionné
  CollectionReference get _poopCollectionRef => FirebaseFirestore.instance
      .collection('Babies')
      .doc(widget.selectedBebe)
      .collection('Poops');

  void _submit() async {
    try {
      final atValue = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedHour, _selectedMinute);
      // Prendre la valeur précédente pour ajuster l'historique
      final prevDoc = await _poopCollectionRef.doc(widget.poopDoc.id).get();
      DateTime? oldAt;
      if (prevDoc.exists) {
        final pdata = prevDoc.data() as Map<String, dynamic>?;
        final raw = pdata != null ? pdata['at'] ?? pdata['date'] : null;
        if (raw is Timestamp) oldAt = raw.toDate();
        else if (raw is DateTime) oldAt = raw;
      }

      // Prendre la valeur source existante si présente, sinon 'manual'
      final existing = widget.poopDoc.data() as Map<String, dynamic>?;
      final sourceValue = existing != null && existing['source'] != null ? existing['source'] as String : 'manual';

      await _poopCollectionRef.doc(widget.poopDoc.id).update({
        'at': atValue,
        'notes': _notesController.text,
        'source': sourceValue,
      });

      final historyColl = FirebaseFirestore.instance.collection('Babies').doc(widget.selectedBebe).collection('HistoryLogs');
      final newKey = '${atValue.year.toString().padLeft(4, '0')}-'
          '${atValue.month.toString().padLeft(2, '0')}-'
          '${atValue.day.toString().padLeft(2, '0')}';
      if (oldAt != null) {
        final oldKey = '${oldAt.year.toString().padLeft(4, '0')}-'
            '${oldAt.month.toString().padLeft(2, '0')}-'
            '${oldAt.day.toString().padLeft(2, '0')}';
        if (oldKey == newKey) {
          // même jour => rien à faire
        } else {
          await historyColl.doc(oldKey).set({'poopsCount': FieldValue.increment(-1)}, SetOptions(merge: true));
          await historyColl.doc(newKey).set({'poopsCount': FieldValue.increment(1)}, SetOptions(merge: true));
        }
      } else {
        // pas d'ancienne date, incrémenter
        await historyColl.doc(newKey).set({'poopsCount': FieldValue.increment(1)}, SetOptions(merge: true));
      }
       if (!mounted) return;
       Navigator.of(context).pop(true);
     } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
     }
   }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Text('Edit poop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Date: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.calendar_today, color: Colors.brown),
                    label: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
                      style: TextStyle(fontSize: 18, color: Colors.brown, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text('Select time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              CyclicHourMinutePicker(
                initialHour: _selectedHour,
                initialMinute: _selectedMinute,
                onHourChanged: (hour) {
                  _onHourChanged(hour);
                },
                onMinuteChanged: (minute) {
                  setState(() {
                    _selectedMinute = minute;
                  });
                },
              ),
              SizedBox(height: 24),
              SizedBox(
                height: 40,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Add notes...',
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  style: TextStyle(fontSize: 14),
                  maxLines: 1,
                  controller: _notesController,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 16),
              TextButton.icon(
                icon: Icon(Icons.delete, color: Colors.white),
                label: Text('Delete', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  try {
                    // Avant suppression, ajuster l'historique
                    final prev = await _poopCollectionRef.doc(widget.poopDoc.id).get();
                    if (prev.exists) {
                      final pdata = prev.data() as Map<String, dynamic>?;
                      DateTime? at;
                      if (pdata != null) {
                        final raw = pdata['at'] ?? pdata['date'];
                        if (raw is Timestamp) at = raw.toDate();
                        else if (raw is DateTime) at = raw;
                      }
                      if (at != null) {
                        final key = '${at.year.toString().padLeft(4, '0')}-'
                            '${at.month.toString().padLeft(2, '0')}-'
                            '${at.day.toString().padLeft(2, '0')}';
                        await FirebaseFirestore.instance.collection('Babies').doc(widget.selectedBebe).collection('HistoryLogs').doc(key).set({'poopsCount': FieldValue.increment(-1)}, SetOptions(merge: true));
                      }
                    }
                    await _poopCollectionRef.doc(widget.poopDoc.id).delete();
                     if (!mounted) return;
                     Navigator.of(context).pop(true);
                   } catch (e) {
                     if (!mounted) return;
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
                   }
                 },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
