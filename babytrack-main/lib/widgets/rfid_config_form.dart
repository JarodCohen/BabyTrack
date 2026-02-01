import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Form to configure RFID settings (temperature thresholds, LDR threshold, bottle tare)
class RfidConfigForm extends StatefulWidget {
  final String rfidUuid;
  final String babyId;
  final String babyName;
  final Map<String, dynamic>? initialConfig;

  const RfidConfigForm({
    required this.rfidUuid,
    required this.babyId,
    required this.babyName,
    this.initialConfig,
    super.key,
  });

  @override
  State<RfidConfigForm> createState() => _RfidConfigFormState();
}

class _RfidConfigFormState extends State<RfidConfigForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Temperature settings
  late double _idealTempMin;
  late double _idealTempMax;
  
  // LDR threshold
  late int _ldrThreshold;
  
  // Bottle tare weight (read-only, set by ESP32)
  double? _bottleTareWeight;
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = widget.initialConfig;
    _idealTempMin = (config?['idealTempMin'] as num?)?.toDouble() ?? 35.0;
    _idealTempMax = (config?['idealTempMax'] as num?)?.toDouble() ?? 40.0;
    _ldrThreshold = (config?['ldrThreshold'] as num?)?.toInt() ?? 500;
    _bottleTareWeight = (config?['bottleTareWeight'] as num?)?.toDouble();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_idealTempMin >= _idealTempMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Min temperature must be less than max')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('RfidMappings')
          .doc(widget.rfidUuid)
          .update({
        'idealTempMin': _idealTempMin,
        'idealTempMax': _idealTempMax,
        'ldrThreshold': _ldrThreshold,
        'configUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving RFID config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestRecalibration() async {
    try {
      await FirebaseFirestore.instance
          .collection('RfidMappings')
          .doc(widget.rfidUuid)
          .update({
        'needsCalibration': true,
        'calibrationRequestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calibration requested. Place empty bottle on scale and scan RFID.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _truncateUuid(String uuid) {
    if (uuid.length <= 16) return uuid;
    return '${uuid.substring(0, 8)}...${uuid.substring(uuid.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RFID Configuration',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.babyName,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'RFID: ${_truncateUuid(widget.rfidUuid)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Temperature Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.thermostat, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Ideal Bottle Temperature',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LED will indicate if bottle is too hot (red) or too cold (blue)',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Min: ${_idealTempMin.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Slider(
                                value: _idealTempMin,
                                min: 20,
                                max: 45,
                                divisions: 50,
                                activeColor: Colors.blue,
                                onChanged: (value) {
                                  setState(() => _idealTempMin = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Max: ${_idealTempMax.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Slider(
                                value: _idealTempMax,
                                min: 20,
                                max: 50,
                                divisions: 60,
                                activeColor: Colors.red,
                                onChanged: (value) {
                                  setState(() => _idealTempMax = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // LDR Threshold Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.nightlight_round, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Night Light Sensitivity',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Higher value = darker room needed to activate night light',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny, size: 20),
                        Expanded(
                          child: Slider(
                            value: _ldrThreshold.toDouble(),
                            min: 100,
                            max: 1000,
                            divisions: 18,
                            activeColor: Colors.purple,
                            onChanged: (value) {
                              setState(() => _ldrThreshold = value.toInt());
                            },
                          ),
                        ),
                        const Icon(Icons.nightlight, size: 20),
                      ],
                    ),
                    Center(
                      child: Text(
                        'Threshold: $_ldrThreshold',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bottle Tare Weight Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.scale, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Bottle Tare Weight',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Empty bottle weight (calibrated by ESP32)',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              _bottleTareWeight != null
                                  ? '${_bottleTareWeight!.toStringAsFixed(1)} g'
                                  : 'Not calibrated',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _bottleTareWeight != null
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _requestRecalibration,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Recalibrate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (_bottleTareWeight == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Place empty bottle on scale and scan RFID to calibrate',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Configuration'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
