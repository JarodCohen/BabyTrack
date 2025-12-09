import 'package:flutter/cupertino.dart';

class CyclicHourMinutePicker extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final double pickerWidth;
  final double pickerHeight;
  final TextStyle? textStyle;

  const CyclicHourMinutePicker({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    this.pickerWidth = 80,
    this.pickerHeight = 120,
    this.textStyle,
  });

  @override
  State<CyclicHourMinutePicker> createState() => _CyclicHourMinutePickerState();
}

class _CyclicHourMinutePickerState extends State<CyclicHourMinutePicker> {
  static const int hourItemCount = 1000;
  static const int minuteItemCount = 1000;
  static const int hourModulo = 24;
  static const int minuteModulo = 12; // 0, 5, ..., 55

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  int _selectedHour = 0;
  int _selectedMinute = 0;
  int _prevMinuteIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = (widget.initialMinute ~/ 5) * 5;
    _hourController = FixedExtentScrollController(initialItem: (hourItemCount ~/ 2) + 4 + _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: (minuteItemCount ~/ 2) + 4 + (_selectedMinute ~/ 5));
    _prevMinuteIndex = (minuteItemCount ~/ 2) + (_selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ?? const TextStyle(fontSize: 24);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.pickerWidth,
          height: widget.pickerHeight,
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: _hourController,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedHour = index % hourModulo;
              });
              widget.onHourChanged(_selectedHour);
            },
            children: List.generate(hourItemCount, (index) => Center(child: Text((index % hourModulo).toString().padLeft(2, '0'), style: style))),
          ),
        ),
        Text(':', style: TextStyle(fontSize: 28)),
        SizedBox(
          width: widget.pickerWidth,
          height: widget.pickerHeight,
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: _minuteController,
            onSelectedItemChanged: (index) {
              int minuteStep = index % minuteModulo;
              int minute = minuteStep * 5;
              int prevMinuteStep = _prevMinuteIndex % minuteModulo;
              int prevMinute = prevMinuteStep * 5;
              int hourIndex = _hourController.selectedItem;
              // Passage de 55 à 0 (scroll vers le haut)
              if (prevMinute == 55 && minute == 0) {
                setState(() {
                  _selectedHour = (_selectedHour + 1) % hourModulo;
                  _hourController.jumpToItem((hourIndex + 1) % hourItemCount);
                });
                widget.onHourChanged(_selectedHour);
              }
              // Passage de 0 à 55 (scroll vers le bas)
              else if (prevMinute == 0 && minute == 55) {
                setState(() {
                  _selectedHour = (_selectedHour - 1 + hourModulo) % hourModulo;
                  _hourController.jumpToItem((hourIndex - 1 + hourItemCount) % hourItemCount);
                });
                widget.onHourChanged(_selectedHour);
              }
              setState(() {
                _selectedMinute = minute;
                _prevMinuteIndex = index;
              });
              widget.onMinuteChanged(_selectedMinute);
            },
            children: List.generate(minuteItemCount, (index) => Center(child: Text(((index % minuteModulo) * 5).toString().padLeft(2, '0'), style: style))),
          ),
        ),
      ],
    );
  }
}

