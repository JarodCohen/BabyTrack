import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Bottom sheet to show and claim pending RFID tags
class PendingRfidSheet extends StatefulWidget {
  final List<String> babyIds;
  final Map<String, String> babyNames;
  final VoidCallback? onRfidClaimed;

  const PendingRfidSheet({
    required this.babyIds,
    required this.babyNames,
    this.onRfidClaimed,
    super.key,
  });

  @override
  State<PendingRfidSheet> createState() => _PendingRfidSheetState();
}

class _PendingRfidSheetState extends State<PendingRfidSheet> {
  // Track selected baby for each RFID
  final Map<String, String?> _selectedBabyForRfid = {};
  
  // Track expanded state for config section
  final Map<String, bool> _expandedConfig = {};
  
  // Config values per RFID
  final Map<String, double> _idealTempMin = {};
  final Map<String, double> _idealTempMax = {};
  final Map<String, int> _ldrThreshold = {};

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  void _initConfigForRfid(String rfidUuid) {
    _idealTempMin[rfidUuid] ??= 35.0;
    _idealTempMax[rfidUuid] ??= 40.0;
    _ldrThreshold[rfidUuid] ??= 500;
  }

  Future<void> _claimRfid(String rfidUuid, String babyId) async {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }

    // Validate temperature range
    final tempMin = _idealTempMin[rfidUuid] ?? 35.0;
    final tempMax = _idealTempMax[rfidUuid] ?? 40.0;
    if (tempMin >= tempMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Min temperature must be less than max')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('RfidMappings')
          .doc(rfidUuid)
          .update({
        'babyId': babyId,
        'status': 'mapped',
        'mappedAt': FieldValue.serverTimestamp(),
        'mappedByUserId': userId,
        // Config fields
        'idealTempMin': tempMin,
        'idealTempMax': tempMax,
        'ldrThreshold': _ldrThreshold[rfidUuid] ?? 500,
        'needsCalibration': true,  // ESP will calibrate bottle on first scan
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RFID linked to ${widget.babyNames[babyId] ?? babyId}. Place empty bottle on scale to calibrate.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      widget.onRfidClaimed?.call();
    } catch (e) {
      debugPrint('Error claiming RFID: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error linking RFID: $e')),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _truncateUuid(String uuid) {
    if (uuid.length <= 12) return uuid;
    return '${uuid.substring(0, 6)}...${uuid.substring(uuid.length - 4)}';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nfc, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Pending RFID Tags',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Link scanned RFID tags to your babies',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Stream of pending RFIDs
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('RfidMappings')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('scannedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade400, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'No pending RFID tags',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan a new RFID tag to see it here',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final rfidUuid = doc.id;
                      final scannedAt = data['scannedAt'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // RFID UUID
                              Row(
                                children: [
                                  Icon(Icons.nfc, color: Colors.blue.shade400, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _truncateUuid(rfidUuid),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Pending',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Scanned at
                              Text(
                                'Scanned: ${_formatTimestamp(scannedAt)}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              
                              // Baby selector
                              if (widget.babyIds.isEmpty)
                                Text(
                                  'No babies available to link',
                                  style: TextStyle(color: Colors.red.shade400),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedBabyForRfid[rfidUuid],
                                            decoration: const InputDecoration(
                                              labelText: 'Link to baby',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            items: widget.babyIds.map((id) {
                                              return DropdownMenuItem<String>(
                                                value: id,
                                                child: Text(widget.babyNames[id] ?? id),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedBabyForRfid[rfidUuid] = value;
                                                if (value != null) {
                                                  _initConfigForRfid(rfidUuid);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Show config options when baby is selected
                                    if (_selectedBabyForRfid[rfidUuid] != null) ...[
                                      const SizedBox(height: 12),
                                      
                                      // Expandable config section
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _expandedConfig[rfidUuid] = !(_expandedConfig[rfidUuid] ?? false);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.tune, size: 18, color: Colors.grey.shade600),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Configuration',
                                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                _expandedConfig[rfidUuid] == true
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      if (_expandedConfig[rfidUuid] == true) ...[
                                        const SizedBox(height: 12),
                                        
                                        // Temperature config
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.thermostat, size: 16, color: Colors.orange.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Ideal Temperature',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Colors.orange.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          'Min: ${(_idealTempMin[rfidUuid] ?? 35.0).toStringAsFixed(0)}°C',
                                                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                                        ),
                                                        Slider(
                                                          value: _idealTempMin[rfidUuid] ?? 35.0,
                                                          min: 20,
                                                          max: 45,
                                                          divisions: 25,
                                                          activeColor: Colors.blue,
                                                          onChanged: (v) => setState(() => _idealTempMin[rfidUuid] = v),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          'Max: ${(_idealTempMax[rfidUuid] ?? 40.0).toStringAsFixed(0)}°C',
                                                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                                                        ),
                                                        Slider(
                                                          value: _idealTempMax[rfidUuid] ?? 40.0,
                                                          min: 25,
                                                          max: 50,
                                                          divisions: 25,
                                                          activeColor: Colors.red,
                                                          onChanged: (v) => setState(() => _idealTempMax[rfidUuid] = v),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // LDR config
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.nightlight, size: 16, color: Colors.purple.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Night Light: ${_ldrThreshold[rfidUuid] ?? 500}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Colors.purple.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                value: (_ldrThreshold[rfidUuid] ?? 500).toDouble(),
                                                min: 100,
                                                max: 1000,
                                                divisions: 18,
                                                activeColor: Colors.purple,
                                                onChanged: (v) => setState(() => _ldrThreshold[rfidUuid] = v.toInt()),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Link button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _claimRfid(rfidUuid, _selectedBabyForRfid[rfidUuid]!),
                                          icon: const Icon(Icons.link, size: 18),
                                          label: const Text('Link RFID'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
