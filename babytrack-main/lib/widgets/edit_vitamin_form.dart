import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cyclic_hour_minute_picker.dart';

class EditVitaminForm extends StatefulWidget {
  final DocumentSnapshot vitaminDoc;
  final String selectedBebe;
  const EditVitaminForm({required this.vitaminDoc, required this.selectedBebe, super.key});

  @override
  State<EditVitaminForm> createState() => _EditVitaminFormState();
}

class _EditVitaminFormState extends State<EditVitaminForm> {
  late int _selectedHour;
  late int _selectedMinute;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final dataMap = widget.vitaminDoc.data() as Map<String, dynamic>?;
    final rawAt = dataMap != null ? dataMap['at'] : null;
    DateTime atDate;
    if (rawAt is Timestamp) {
      atDate = rawAt.toDate();
    } else if (rawAt is DateTime) {
      atDate = rawAt;
    } else {
      atDate = DateTime.now();
    }
    _selectedDate = DateTime(atDate.year, atDate.month, atDate.day);
    _selectedHour = atDate.hour;
    _selectedMinute = atDate.minute;
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

  void _submit() async {
    try {
      final atValue = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );
      final sourceValue = (widget.vitaminDoc.data() as Map<String, dynamic>?)?['source'] ?? 'manual';

      // Get old date for history adjustment
      final prev = await widget.vitaminDoc.reference.get();
      DateTime? oldAt;
      if (prev.exists) {
        final pdata = prev.data() as Map<String, dynamic>?;
        final raw = pdata != null ? pdata['at'] : null;
        if (raw is Timestamp) oldAt = raw.toDate();
        else if (raw is DateTime) oldAt = raw;
      }

      // Update document
      await widget.vitaminDoc.reference.update({
        'at': atValue,
        'source': sourceValue,
      });

      // Adjust HistoryLogs
      final historyColl = FirebaseFirestore.instance
          .collection('Babies')
          .doc(widget.selectedBebe)
          .collection('HistoryLogs');
      
      final newKey = '${atValue.year.toString().padLeft(4, '0')}-'
          '${atValue.month.toString().padLeft(2, '0')}-'
          '${atValue.day.toString().padLeft(2, '0')}';

      if (oldAt != null) {
        final oldKey = '${oldAt.year.toString().padLeft(4, '0')}-'
            '${oldAt.month.toString().padLeft(2, '0')}-'
            '${oldAt.day.toString().padLeft(2, '0')}';
        if (oldKey != newKey) {
          await historyColl.doc(oldKey).set(
            {'vitaminsCount': FieldValue.increment(-1)},
            SetOptions(merge: true),
          );
          await historyColl.doc(newKey).set(
            {'vitaminsCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  Future<void> _delete() async {
    try {
      // Adjust history before deletion
      final prev = await widget.vitaminDoc.reference.get();
      if (prev.exists) {
        final pdata = prev.data() as Map<String, dynamic>?;
        DateTime? at;
        if (pdata != null) {
          final raw = pdata['at'];
          if (raw is Timestamp) at = raw.toDate();
          else if (raw is DateTime) at = raw;
        }
        if (at != null) {
          final key = '${at.year.toString().padLeft(4, '0')}-'
              '${at.month.toString().padLeft(2, '0')}-'
              '${at.day.toString().padLeft(2, '0')}';
          await FirebaseFirestore.instance
              .collection('Babies')
              .doc(widget.selectedBebe)
              .collection('HistoryLogs')
              .doc(key)
              .set({'vitaminsCount': FieldValue.increment(-1)}, SetOptions(merge: true));
        }
      }

      await widget.vitaminDoc.reference.delete();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
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
              Text(
                'Edit vitamin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              
              // Date selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Date: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.calendar_today, color: Colors.green),
                    label: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
                      style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              Text('Select time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
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
                label: Text(
                  'Delete',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _delete,
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
