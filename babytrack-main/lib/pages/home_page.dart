import 'package:flutter/material.dart';
import '../utils/size_config.dart';
import '../widgets/bottles_card.dart';
import '../widgets/poop_card.dart';
import '../widgets/vitamins_card.dart';
import 'add_baby_page.dart';

class HomePage extends StatefulWidget {
  final String selectedBaby;
  final ValueChanged<String>? onBabyAdded; // optional callback to notify parent

  const HomePage({super.key, this.selectedBaby = '', this.onBabyAdded});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Use the selected baby passed from parent if provided, otherwise a default
  late String _selectedBaby;

  @override
  void initState() {
    super.initState();
    _selectedBaby = widget.selectedBaby.isNotEmpty ? widget.selectedBaby : '';
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal state when parent changes selectedBaby
    if (widget.selectedBaby != oldWidget.selectedBaby && widget.selectedBaby.isNotEmpty) {
      setState(() {
        _selectedBaby = widget.selectedBaby;
      });
    }
  }

  Future<void> _openAddBaby() async {
    final newId = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const AddBabyPage()));
    if (newId != null && newId.isNotEmpty) {
      // notify parent if provided
      widget.onBabyAdded?.call(newId);
      setState(() {
        _selectedBaby = newId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cardFontSize = SizeConfig.text(context, 0.055);
    final double cardIconSize = SizeConfig.icon(context, 0.07);
    final double cardSpace = SizeConfig.vertical(context, 0.01);

    if (_selectedBaby.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No baby selected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add a baby to start tracking bottles and care.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _openAddBaby, icon: const Icon(Icons.add), label: const Text('Add a baby'))
            ],
          ),
        ),
      );
    }

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SizedBox.expand(
          child: Column(
            children: [
              Expanded(
                flex: 118,
                child: BottlesCard(
                  cardFontSize: cardFontSize,
                  cardIconSize: cardIconSize,
                  selectedBebe: _selectedBaby,
                ),
              ),
              SizedBox(height: cardSpace),
              Expanded(
                flex: 31,
                child: PoopCard(
                  cardFontSize: cardFontSize,
                  cardIconSize: cardIconSize,
                  selectedBebe: _selectedBaby,
                ),
              ),
              SizedBox(height: cardSpace),
              Expanded(
                flex: 56,
                child: VitaminsCard(
                  cardFontSize: cardFontSize,
                  cardIconSize: cardIconSize,
                  selectedBebe: _selectedBaby,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
