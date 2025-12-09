import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddBabyPage extends StatefulWidget {
  const AddBabyPage({super.key});

  @override
  State<AddBabyPage> createState() => _AddBabyPageState();
}

class _AddBabyPageState extends State<AddBabyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  bool _babyExists = false;
  bool _hasOtherParents = false;
  String? _existingBabyName;

  Future<void> _checkBabyExists() async {
    final babyId = _idController.text.trim();
    if (babyId.isEmpty) {
      setState(() {
        _babyExists = false;
        _hasOtherParents = false;
        _existingBabyName = null;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('Babies').doc(babyId).get();
      if (doc.exists) {
        final data = doc.data();
        final parentIds = (data?['parentIds'] as List?)?.cast<String>() ?? [];
        setState(() {
          _babyExists = true;
          _existingBabyName = data?['firstName'] ?? babyId;
          _hasOtherParents = parentIds.isNotEmpty;
        });
      } else {
        setState(() {
          _babyExists = false;
          _hasOtherParents = false;
          _existingBabyName = null;
        });
      }
    } catch (e) {
      debugPrint('Error checking baby: $e');
    }
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  String? get _currentUserName => FirebaseAuth.instance.currentUser?.displayName;
  String? get _currentUserEmail => FirebaseAuth.instance.currentUser?.email;

  Future<void> _saveBaby() async {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in')));
      return;
    }

    final babyId = _idController.text.trim();
    if (babyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID required')));
      return;
    }

    if (!_babyExists && (_nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('First name required for new baby')));
      return;
    }

    setState(() => _saving = true);
    try {
      final babyDoc = await FirebaseFirestore.instance.collection('Babies').doc(babyId).get();
      final babyRef = FirebaseFirestore.instance.collection('Babies').doc(babyId);
      final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
      
      if (!babyDoc.exists) {
        await babyRef.set({
          'firstName': _nameController.text.trim(),
          'parentIds': [userId],
          'pendingParentIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await userRef.set({
          'babyIds': FieldValue.arrayUnion([babyId])
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Baby created successfully'))
        );
        Navigator.of(context).pop(babyId);
      } else {
        final data = babyDoc.data()!;
        final parentIds = (data['parentIds'] as List?)?.cast<String>() ?? [];
        final pendingParentIds = (data['pendingParentIds'] as List?)?.cast<String>() ?? [];

        if (parentIds.contains(userId)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already a parent of this baby'))
          );
          Navigator.of(context).pop(babyId);
          return;
        }

        if (pendingParentIds.contains(userId)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A request is already pending'))
          );
          Navigator.of(context).pop();
          return;
        }

        if (parentIds.isEmpty) {
          await babyRef.update({
            'parentIds': FieldValue.arrayUnion([userId])
          });
          await userRef.set({
            'babyIds': FieldValue.arrayUnion([babyId])
          }, SetOptions(merge: true));

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Baby "$_existingBabyName" added to your account'))
          );
          Navigator.of(context).pop(babyId);
        } else {
          await babyRef.update({
            'pendingParentIds': FieldValue.arrayUnion([userId])
          });

          await userRef.set({
            'pendingBabyIds': FieldValue.arrayUnion([babyId])
          }, SetOptions(merge: true));

          await babyRef.collection('ParentRequests').doc(userId).set({
            'requesterId': userId,
            'requesterName': _currentUserName ?? 'User',
            'requesterEmail': _currentUserEmail ?? '',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request sent to parents of "$_existingBabyName"'),
              backgroundColor: Colors.orange,
            )
          );
          Navigator.of(context).pop(babyId);
        }
      }
    } catch (e) {
      debugPrint('Error creating/adding baby: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding baby'))
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a baby')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(labelText: 'Baby ID'),
                    onChanged: (_) => _checkBabyExists(),
                  ),
                  const SizedBox(height: 12),
                  if (_babyExists)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hasOtherParents ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _hasOtherParents ? Colors.orange.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _hasOtherParents ? Icons.pending : Icons.check_circle,
                                color: _hasOtherParents ? Colors.orange.shade600 : Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Baby found: $_existingBabyName',
                                  style: TextStyle(
                                    color: _hasOtherParents ? Colors.orange.shade800 : Colors.green.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_hasOtherParents) ...[
                            const SizedBox(height: 8),
                            Text(
                              'This baby already has parents. A request will be sent for approval.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Baby first name'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _saveBaby,
              style: ElevatedButton.styleFrom(
                backgroundColor: _babyExists && _hasOtherParents ? Colors.orange : null,
              ),
              child: _saving 
                  ? const CircularProgressIndicator() 
                  : Text(_babyExists 
                      ? (_hasOtherParents ? 'Send request' : 'Add to my account')
                      : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
