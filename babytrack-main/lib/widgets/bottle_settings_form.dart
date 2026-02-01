import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'rfid_config_form.dart';

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
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // RFID Management Section
            const _RfidManagementSection(),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Section to manage RFID mappings
class _RfidManagementSection extends StatelessWidget {
  const _RfidManagementSection();

  String _truncateUuid(String uuid) {
    if (uuid.length <= 16) return uuid;
    return '${uuid.substring(0, 8)}...${uuid.substring(uuid.length - 6)}';
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
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openConfig(BuildContext context, String rfidUuid, String babyId, Map<String, dynamic> data) async {
    // Get baby name
    String babyName = babyId;
    try {
      final babyDoc = await FirebaseFirestore.instance.collection('Babies').doc(babyId).get();
      if (babyDoc.exists) {
        babyName = babyDoc.get('firstName') ?? babyId;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RfidConfigForm(
        rfidUuid: rfidUuid,
        babyId: babyId,
        babyName: babyName,
        initialConfig: data,
      ),
    );
  }

  Future<void> _unlinkRfid(BuildContext context, String rfidUuid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink RFID?'),
        content: const Text('This will remove the link between this RFID tag and the baby. The RFID will become pending again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('RfidMappings')
            .doc(rfidUuid)
            .update({
          'babyId': null,
          'status': 'pending',
          'mappedAt': null,
          'mappedByUserId': null,
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('RFID unlinked'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.nfc, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'RFID Mappings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage linked RFID tags',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        
        // Stream of all RFID mappings
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('RfidMappings')
              .orderBy('status')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No RFID tags registered yet. Scan an RFID tag with the ESP32 to see it here.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final rfidUuid = doc.id;
                final status = data['status'] as String? ?? 'pending';
                final babyId = data['babyId'] as String?;
                final mappedAt = data['mappedAt'];

                final isMapped = status == 'mapped' && babyId != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMapped ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMapped ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.nfc,
                        color: isMapped ? Colors.green.shade600 : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _truncateUuid(rfidUuid),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isMapped)
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('Babies')
                                    .doc(babyId)
                                    .get(),
                                builder: (context, babySnapshot) {
                                  final babyName = babySnapshot.data?.get('firstName') ?? babyId;
                                  return Text(
                                    'Linked to: $babyName',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              )
                            else
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            if (mappedAt != null)
                              Text(
                                'Mapped: ${_formatTimestamp(mappedAt)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isMapped) ...[
                        IconButton(
                          icon: Icon(Icons.settings, color: Colors.blue.shade400, size: 20),
                          tooltip: 'Configure',
                          onPressed: () => _openConfig(context, rfidUuid, babyId, data),
                        ),
                        IconButton(
                          icon: Icon(Icons.link_off, color: Colors.red.shade400, size: 20),
                          tooltip: 'Unlink',
                          onPressed: () => _unlinkRfid(context, rfidUuid),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
