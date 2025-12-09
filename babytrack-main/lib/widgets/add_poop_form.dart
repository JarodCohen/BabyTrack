import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cyclic_hour_minute_picker.dart';

class AddPoopForm extends StatefulWidget {
  final String selectedBebe;

  const AddPoopForm({super.key, required this.selectedBebe});

  @override
  State<AddPoopForm> createState() => _AddPoopFormState();
}

class _AddPoopFormState extends State<AddPoopForm> {
  int _selectedHour = TimeOfDay.now().hour;
  int _selectedMinute = (TimeOfDay.now().minute ~/ 5) * 5;
  DateTime _selectedDate = DateTime.now();
  String? _notes;

  // Référence vers la sous-collection Poops du bébé sélectionné
  CollectionReference get _poopCollectionRef => FirebaseFirestore.instance
      .collection('Babies')
      .doc(widget.selectedBebe)
      .collection('Poops');

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
    // Logique pour changer de jour automatiquement
    if (_selectedHour == 23 && newHour == 0) {
      // Passage de 23h à 00h -> jour suivant
      setState(() {
        _selectedHour = newHour;
        _selectedDate = _selectedDate.add(Duration(days: 1));
      });
    } else if (_selectedHour == 0 && newHour == 23) {
      // Passage de 00h à 23h -> jour précédent
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

  void _submit() async {
    if (widget.selectedBebe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No baby selected')));
      return;
    }

    try {
      final atValue = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedHour, _selectedMinute);
      await _poopCollectionRef.add({
        'at': atValue,
        'createdAt': Timestamp.now(),
        'notes': _notes,
        'source': 'manual',
      });

      // Mise à jour du résumé quotidien dans HistoryLogs/{YYYY-MM-DD}
      final dateKey = '${atValue.year.toString().padLeft(4, '0')}-'
          '${atValue.month.toString().padLeft(2, '0')}-'
          '${atValue.day.toString().padLeft(2, '0')}';
      final historyRef = FirebaseFirestore.instance
          .collection('Babies')
          .doc(widget.selectedBebe)
          .collection('HistoryLogs')
          .doc(dateKey);

      await historyRef.set({
        'poopsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding: $e')));
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
              Text('Add poop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 24),

              // Sélection de la date
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

              // Sélection de l'heure
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

              // Champ de notes (réduit)
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
                  onChanged: (value) {
                    _notes = value.isEmpty ? null : value;
                  },
                ),
              ),

              SizedBox(height: 24),

              // Bouton de validation
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
            ],
          ),
        ),
      ),
    );
  }
}
