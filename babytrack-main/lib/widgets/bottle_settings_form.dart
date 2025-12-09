import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class BottleSettingsForm extends StatefulWidget {
  const BottleSettingsForm({super.key});

  @override
  State<BottleSettingsForm> createState() => _BottleSettingsFormState();
}

class _BottleSettingsFormState extends State<BottleSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
  int _min = 10;
  int _max = 210;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final min = prefs.getInt('bottleMin') ?? 10;
    final max = prefs.getInt('bottleMax') ?? 210;
    setState(() {
      _min = min;
      _max = max;
      _minController.text = _min.toString();
      _maxController.text = _max.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minValue = int.tryParse(_minController.text) ?? _min;
    final maxValue = int.tryParse(_maxController.text) ?? _max;
    if (minValue >= maxValue) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The minimum value need to be lower than the max value.'),
      ));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bottleMin', minValue);
    await prefs.setInt('bottleMax', maxValue);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Settings saved.'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16.0)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Min value (ml)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final parsed = int.tryParse(v ?? '');
                        if (parsed == null) return 'Number required';
                        if (parsed <= 0) return 'Need to be > 0';
                        if (parsed % 10 != 0) return 'Need to be a multiple of 10';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Max value (ml)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final parsed = int.tryParse(v ?? '');
                        if (parsed == null) return 'Number required';
                        if (parsed <= 0) return 'Need to be > 0';
                        if (parsed % 10 != 0) return 'Need to be a multiple of 10';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
