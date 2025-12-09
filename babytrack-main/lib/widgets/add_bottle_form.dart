import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cyclic_hour_minute_picker.dart';

class AddBottleForm extends StatefulWidget {
  final String selectedBebe;

  const AddBottleForm({super.key, required this.selectedBebe});

  @override
  State<AddBottleForm> createState() => _AddBottleFormState();
}

class _AddBottleFormState extends State<AddBottleForm> {
  double _amount = 150;
  int _selectedHour = TimeOfDay.now().hour;
  int _selectedMinute = (TimeOfDay.now().minute ~/ 5) * 5;
  DateTime _selectedDate = DateTime.now();
  int _minLimit = 10;
  int _maxLimit = 210;

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

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final min = prefs.getInt('bottleMin') ?? 10;
    final max = prefs.getInt('bottleMax') ?? 210;
    // ensure sensible defaults
    final safeMin = min > 0 ? min : 10;
    final safeMax = max > safeMin ? max : (safeMin + 200);
    setState(() {
      _minLimit = safeMin;
      _maxLimit = safeMax;
      // clamp _amount into range
      if (_amount < _minLimit) _amount = _minLimit.toDouble();
      if (_amount > _maxLimit) _amount = _maxLimit.toDouble();
    });
  }

  void _submit() async {
    if (widget.selectedBebe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No baby selected')));
      return;
    }

    try {
      final startedAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedHour, _selectedMinute);
      // Ajout du biberon
      await FirebaseFirestore.instance
          .collection('Babies')
          .doc(widget.selectedBebe)
          .collection('Bottles')
          .add({
        'quantity': _amount.toInt(),
        'startedAt': startedAt,
        'createdAt': Timestamp.now(),
        'source': 'manual',
      });

      // Mise à jour du résumé quotidien dans HistoryLogs/{YYYY-MM-DD}
      final dateKey = '${startedAt.year.toString().padLeft(4, '0')}-'
          '${startedAt.month.toString().padLeft(2, '0')}-'
          '${startedAt.day.toString().padLeft(2, '0')}';
      final historyRef = FirebaseFirestore.instance
          .collection('Babies')
          .doc(widget.selectedBebe)
          .collection('HistoryLogs')
          .doc(dateKey);

      await historyRef.set({
        'bottlesCount': FieldValue.increment(1),
        'bottlesTotalQuantity': FieldValue.increment(_amount.toInt()),
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
              Text('Choose the amount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text(
                '${_amount.toInt()} ml',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              Slider(
                value: _amount,
                min: _minLimit.toDouble(),
                max: _maxLimit.toDouble(),
                divisions: ((_maxLimit - _minLimit) ~/ 10).clamp(1, 1000),
                label: '${_amount.toInt()} ml',
                onChanged: (value) {
                  setState(() {
                    // round to nearest 10
                    final rounded = (value / 10).round() * 10;
                    // clamp between min and max
                    final clamped = rounded.clamp(_minLimit, _maxLimit).toDouble();
                    _amount = clamped;
                  });
                },
              ),
              SizedBox(height: 24),
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
                    onPressed: () async {
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
                    },
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
            ],
          ),
        ),
      ),
    );
  }
}
