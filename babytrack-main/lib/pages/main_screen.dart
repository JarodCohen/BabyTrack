import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/size_config.dart';
import 'home_page.dart';
import 'statistics_page.dart';
import '../widgets/bottle_settings_form.dart';
import 'add_baby_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _selectedBaby = '';
  List<String> _babyList = [];  // approved babies
  List<String> _pendingBabyList = [];  // pending babies
  Map<String, String> _babyNames = {};
  bool _loadingBabies = true;
  int _pendingRequestsCount = 0;  // requests awaiting approval on user's babies

  @override
  void initState() {
    super.initState();
    _loadBabyIds();
    _loadPendingRequestsCount();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _loadBabyIds() async {
    setState(() {
      _loadingBabies = true;
    });

    final userId = _currentUserId;
    if (userId == null) {
      setState(() {
        _babyList = [];
        _pendingBabyList = [];
        _babyNames = {};
        _selectedBaby = '';
        _loadingBabies = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        
        // Load approved babies
        final approvedIds = (data?['babyIds'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ?? [];
        
        // Load pending babies
        final pendingIds = (data?['pendingBabyIds'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ?? [];

        // Combine all baby IDs for name lookup
        final allIds = {...approvedIds, ...pendingIds}.toList();
        
        if (allIds.isNotEmpty) {
          final Map<String, String> names = {};
          await Future.wait(allIds.map((id) async {
            try {
              final babyDoc = await FirebaseFirestore.instance.collection('Babies').doc(id).get();
              if (babyDoc.exists) {
                final babyData = babyDoc.data();
                final firstName = (babyData != null && babyData['firstName'] != null) 
                    ? babyData['firstName'].toString() 
                    : id;
                names[id] = firstName;
              } else {
                names[id] = id;
              }
            } catch (e) {
              names[id] = id;
              debugPrint('Error loading Baby doc $id: $e');
            }
          }));

          setState(() {
            _babyList = List<String>.from(approvedIds);
            _pendingBabyList = List<String>.from(pendingIds);
            _babyNames = names;
            // Only select from approved babies
            if (_babyList.isNotEmpty) {
              _selectedBaby = _babyList.first;
            } else {
              _selectedBaby = '';
            }
            _loadingBabies = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading babyIds: $e');
    }

    setState(() {
      _babyList = [];
      _pendingBabyList = [];
      _babyNames = {};
      _selectedBaby = '';
      _loadingBabies = false;
    });
  }

  Future<void> _loadPendingRequestsCount() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // Get all babies where user is a parent
      final babiesSnapshot = await FirebaseFirestore.instance
          .collection('Babies')
          .where('parentIds', arrayContains: userId)
          .get();

      int count = 0;
      for (final babyDoc in babiesSnapshot.docs) {
        final requestsSnapshot = await babyDoc.reference
            .collection('ParentRequests')
            .where('status', isEqualTo: 'pending')
            .get();
        count += requestsSnapshot.docs.length;
      }

      setState(() {
        _pendingRequestsCount = count;
      });
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }
  }

  Future<void> _onAddBabyPressed() async {
    final newId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddBabyPage()),
    );
    if (newId != null && newId.isNotEmpty) {
      await _loadBabyIds();
      await _loadPendingRequestsCount();
      // Only select if it's in approved list
      if (_babyList.contains(newId)) {
        setState(() {
          _selectedBaby = newId;
        });
      }
    }
  }

  void _showPendingRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PendingRequestsSheet(
        userId: _currentUserId!,
        onRequestHandled: () {
          _loadBabyIds();
          _loadPendingRequestsCount();
        },
      ),
    );
  }

  List<Widget> get _pages => [
    HomePage(selectedBaby: _selectedBaby),
    StatisticsPage(selectedBaby: _selectedBaby),
  ];

  // Combine approved and pending babies for dropdown
  List<String> get _allBabies => [..._babyList, ..._pendingBabyList];

  @override
  Widget build(BuildContext context) {
    final double appBarFontSize = SizeConfig.text(context, 0.07);
    final double appBarIconSize = SizeConfig.icon(context, 0.09);
    final double navBarFontSize = SizeConfig.text(context, 0.055);
    final double navBarIconSize = SizeConfig.icon(context, 0.09);
    final double navBarHeight = SizeConfig.vertical(context, 0.06);

    return Scaffold(
      appBar: AppBar(
        title: _loadingBabies
            ? const SizedBox(width: 120, height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : (_allBabies.isNotEmpty
                ? DropdownButton<String>(
                    value: _selectedBaby.isNotEmpty && _babyList.contains(_selectedBaby) ? _selectedBaby : null,
                    isExpanded: true,
                    hint: Text('Select a baby', style: TextStyle(fontSize: appBarFontSize * 0.8)),
                    selectedItemBuilder: (BuildContext context) => _allBabies
                        .map((id) {
                          final isPending = _pendingBabyList.contains(id);
                          return Align(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPending) ...[
                                  Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  _babyNames[id] ?? id,
                                  style: TextStyle(
                                    fontSize: appBarFontSize,
                                    color: isPending ? Colors.orange : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                    items: _allBabies
                        .map((id) {
                          final isPending = _pendingBabyList.contains(id);
                          return DropdownMenuItem<String>(
                            value: id,
                            enabled: !isPending,  // Disable pending babies
                            child: Row(
                              children: [
                                if (isPending) ...[
                                  Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _babyNames[id] ?? id,
                                  style: TextStyle(
                                    fontSize: appBarFontSize,
                                    color: isPending ? Colors.orange : null,
                                  ),
                                ),
                                if (isPending) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(pending)',
                                    style: TextStyle(
                                      fontSize: appBarFontSize * 0.7,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      if (value != null && !_pendingBabyList.contains(value)) {
                        setState(() {
                          _selectedBaby = value;
                        });
                      }
                    },
                  )
                : Text('No baby', style: TextStyle(fontSize: appBarFontSize))),
        centerTitle: true,
        toolbarHeight: navBarHeight,
        leading: Icon(
          _selectedIndex == 0 ? Icons.home : Icons.bar_chart,
          size: appBarIconSize,
        ),
        actions: [
          // Pending requests badge
          if (_pendingRequestsCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Pending requests',
                  onPressed: _showPendingRequests,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_pendingRequestsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a baby',
            onPressed: _onAddBabyPressed,
          ),
          IconButton(
            icon: const Text('⚙️', style: TextStyle(fontSize: 26)),
            tooltip: 'Settings',
            onPressed: () {
              showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const BottleSettingsForm(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedFontSize: navBarFontSize * 0.9,
        unselectedFontSize: navBarFontSize * 0.9,
        iconSize: navBarIconSize * 1.1,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

/// Bottom sheet to show and handle pending parent requests
class _PendingRequestsSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onRequestHandled;

  const _PendingRequestsSheet({
    required this.userId,
    required this.onRequestHandled,
  });

  @override
  State<_PendingRequestsSheet> createState() => _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends State<_PendingRequestsSheet> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);

    try {
      final babiesSnapshot = await FirebaseFirestore.instance
          .collection('Babies')
          .where('parentIds', arrayContains: widget.userId)
          .get();

      final List<Map<String, dynamic>> requests = [];

      for (final babyDoc in babiesSnapshot.docs) {
        final babyData = babyDoc.data();
        final babyName = babyData['firstName'] ?? babyDoc.id;

        final requestsSnapshot = await babyDoc.reference
            .collection('ParentRequests')
            .where('status', isEqualTo: 'pending')
            .get();

        for (final requestDoc in requestsSnapshot.docs) {
          final requestData = requestDoc.data();
          requests.add({
            'babyId': babyDoc.id,
            'babyName': babyName,
            'requestId': requestDoc.id,
            'requesterId': requestData['requesterId'],
            'requesterName': requestData['requesterName'] ?? 'Utilisateur',
            'requesterEmail': requestData['requesterEmail'] ?? '',
            'createdAt': requestData['createdAt'],
          });
        }
      }

      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading requests: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> request, bool approve) async {
    try {
      final babyRef = FirebaseFirestore.instance.collection('Babies').doc(request['babyId']);
      final requesterId = request['requesterId'];

      if (approve) {
        // Add requester to parentIds
        await babyRef.update({
          'parentIds': FieldValue.arrayUnion([requesterId]),
          'pendingParentIds': FieldValue.arrayRemove([requesterId]),
        });

        // Update requester's user document
        final userRef = FirebaseFirestore.instance.collection('Users').doc(requesterId);
        await userRef.update({
          'babyIds': FieldValue.arrayUnion([request['babyId']]),
          'pendingBabyIds': FieldValue.arrayRemove([request['babyId']]),
        });
      } else {
        // Just remove from pending
        await babyRef.update({
          'pendingParentIds': FieldValue.arrayRemove([requesterId]),
        });

        // Remove from requester's pending list
        final userRef = FirebaseFirestore.instance.collection('Users').doc(requesterId);
        await userRef.update({
          'pendingBabyIds': FieldValue.arrayRemove([request['babyId']]),
        });
      }

      // Update request status
      await babyRef.collection('ParentRequests').doc(request['requestId']).update({
        'status': approve ? 'approved' : 'rejected',
        'handledAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request accepted' : 'Request rejected'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }

      widget.onRequestHandled();
      await _loadRequests();

      // Close sheet if no more requests
      if (_requests.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error handling request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_requests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No pending requests'),
                ),
              )
            else
              ...  _requests.map((request) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(Icons.person_add, color: Colors.orange.shade700),
                      ),
                      title: Text(request['requesterName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request['requesterEmail']),
                          Text(
                            'Requests access to ${request['babyName']}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            tooltip: 'Accept',
                            onPressed: () => _handleRequest(request, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () => _handleRequest(request, false),
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
