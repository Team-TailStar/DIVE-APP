import 'package:flutter/material.dart';

enum WeatherTab { today, week  }

class WeatherTabs extends StatelessWidget {
  final WeatherTab current;
  final void Function(WeatherTab) onChanged;
  const WeatherTabs({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, WeatherTab t) {
      final selected = current == t;
      return GestureDetector(
        onTap: () => onChanged(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black87 : Colors.white,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('오늘', WeatherTab.today),
        chip('이번 주', WeatherTab.week),
      ],
    );
  }
}
