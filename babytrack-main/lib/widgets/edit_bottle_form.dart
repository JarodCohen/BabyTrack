import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cyclic_hour_minute_picker.dart';

class EditBottleForm extends StatefulWidget {
  final String bottleId;
  final int initialQuantity;
  final int initialHour;
  final int initialMinute;
  final String selectedBebe; // 'bébé 1' ou 'bébé 2'

  const EditBottleForm({
    super.key,
    required this.bottleId,
    required this.initialQuantity,
    required this.initialHour,
    required this.initialMinute,
    required this.selectedBebe,
  });

  @override
  State<EditBottleForm> createState() => _EditBottleFormState();
}

class _EditBottleFormState extends State<EditBottleForm> {
  late double _amount;
  late int _selectedHour;
  late int _selectedMinute;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialQuantity.toDouble();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
    _selectedDate = DateTime.now(); // Par défaut aujourd'hui
    // Tenter de récupérer la date exacte du document pour préremplir la date si possible
    _loadInitialDate();
  }

  Future<void> _loadInitialDate() async {
    try {
      final doc = await _bottlesRef.doc(widget.bottleId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final raw = data['startedAt'] ?? data['date'] ?? data['at'];
          if (raw != null) {
            DateTime dt;
            if (raw is Timestamp) dt = raw.toDate();
            else if (raw is DateTime) dt = raw;
            else dt = DateTime.now();
            setState(() {
              _selectedDate = DateTime(dt.year, dt.month, dt.day);
              _selectedHour = dt.hour;
              _selectedMinute = dt.minute;
            });
          }
        }
      }
    } catch (_) {
      // ignore errors and keep defaults
    }
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

  // Référence vers la sous-collection Bottles du bébé
  CollectionReference get _bottlesRef => FirebaseFirestore.instance.collection('Babies').doc(widget.selectedBebe).collection('Bottles');

  void _submit() async {
    try {
      // Récupérer l'état précédent du document pour ajuster l'historique
      final prevDoc = await _bottlesRef.doc(widget.bottleId).get();
      Map<String, dynamic>? prevData = prevDoc.exists ? (prevDoc.data() as Map<String, dynamic>?) : null;
      DateTime? oldStartedAt;
      int oldQuantity = 0;
      if (prevData != null) {
        final raw = prevData['startedAt'] ?? prevData['date'] ?? prevData['at'];
        if (raw is Timestamp) oldStartedAt = raw.toDate();
        else if (raw is DateTime) oldStartedAt = raw;
        if (prevData['quantity'] is int) oldQuantity = prevData['quantity'] as int;
      }
      final startedAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedHour, _selectedMinute);
      await _bottlesRef.doc(widget.bottleId).update({
        'quantity': _amount.toInt(),
        'startedAt': startedAt,
      });

      // Mettre à jour HistoryLogs : calculer les clés de date (YYYY-MM-DD)
      final newDateKey = '${startedAt.year.toString().padLeft(4, '0')}-'
          '${startedAt.month.toString().padLeft(2, '0')}-'
          '${startedAt.day.toString().padLeft(2, '0')}';
      final historyCollection = FirebaseFirestore.instance.collection('Babies').doc(widget.selectedBebe).collection('HistoryLogs');

      if (oldStartedAt != null) {
        final oldDateKey = '${oldStartedAt.year.toString().padLeft(4, '0')}-'
            '${oldStartedAt.month.toString().padLeft(2, '0')}-'
            '${oldStartedAt.day.toString().padLeft(2, '0')}';

        if (oldDateKey == newDateKey) {
          // même jour : ajuster uniquement la quantité totale
          final delta = _amount.toInt() - oldQuantity;
          if (delta != 0) {
            await historyCollection.doc(newDateKey).set({'bottlesTotalQuantity': FieldValue.increment(delta)}, SetOptions(merge: true));
          }
        } else {
          // jour changé : décrémenter l'ancien jour, incrémenter le nouveau
          await historyCollection.doc(oldDateKey).set({
            'bottlesCount': FieldValue.increment(-1),
            'bottlesTotalQuantity': FieldValue.increment(-oldQuantity),
          }, SetOptions(merge: true));
          await historyCollection.doc(newDateKey).set({
            'bottlesCount': FieldValue.increment(1),
            'bottlesTotalQuantity': FieldValue.increment(_amount.toInt()),
          }, SetOptions(merge: true));
        }
      } else {
        // pas d'ancienne date : incrémenter le nouveau jour
        await historyCollection.doc(newDateKey).set({
          'bottlesCount': FieldValue.increment(1),
          'bottlesTotalQuantity': FieldValue.increment(_amount.toInt()),
        }, SetOptions(merge: true));
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
              Text('Edit amount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              // Afficher la date en premier
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Date: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.calendar_today, color: Colors.blue),
                    label: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
                      style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Puis l'heure
              Text('Edit time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              CyclicHourMinutePicker(
                initialHour: _selectedHour,
                initialMinute: _selectedMinute,
                onHourChanged: _onHourChanged,
                onMinuteChanged: (minute) {
                  setState(() {
                    _selectedMinute = minute;
                  });
                },
              ),
              SizedBox(height: 16),
              // Puis la quantité
              Text('${_amount.toInt()} ml', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
              Slider(
                value: _amount,
                min: 10,
                max: 300,
                divisions: 29,
                label: '${_amount.toInt()} ml',
                onChanged: (value) {
                  setState(() {
                    _amount = (value / 10).round() * 10;
                  });
                },
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.blue,
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
                    // Avant suppression, récupérer le document pour ajuster l'historique
                    final prev = await _bottlesRef.doc(widget.bottleId).get();
                    if (prev.exists) {
                      final pdata = prev.data() as Map<String, dynamic>?;
                      DateTime? at;
                      int qty = 0;
                      if (pdata != null) {
                        final raw = pdata['startedAt'] ?? pdata['date'] ?? pdata['at'];
                        if (raw is Timestamp) at = raw.toDate();
                        else if (raw is DateTime) at = raw;
                        if (pdata['quantity'] is int) qty = pdata['quantity'] as int;
                      }
                      if (at != null) {
                        final dateKey = '${at.year.toString().padLeft(4, '0')}-'
                            '${at.month.toString().padLeft(2, '0')}-'
                            '${at.day.toString().padLeft(2, '0')}';
                        final historyRef = FirebaseFirestore.instance.collection('Babies').doc(widget.selectedBebe).collection('HistoryLogs').doc(dateKey);
                        await historyRef.set({
                          'bottlesCount': FieldValue.increment(-1),
                          'bottlesTotalQuantity': FieldValue.increment(-qty),
                        }, SetOptions(merge: true));
                      }
                    }
                    await _bottlesRef.doc(widget.bottleId).delete();
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
